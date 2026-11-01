-- AquaSync Supabase Password Reset SQL Script
-- Run this script in your Supabase SQL Editor (https://supabase.com/dashboard/project/_/sql)
-- to allow custom OTP password reset to update auth.users encrypted passwords directly.

-- 1. Enable pgcrypto extension for bcrypt password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- 2. Create RPC function reset_password_by_email with SECURITY DEFINER privileges
CREATE OR REPLACE FUNCTION public.reset_password_by_email(
  p_email text,
  p_new_password text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Find target user ID by email (case-insensitive)
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE LOWER(email) = LOWER(TRIM(p_email));

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'User with email ' || p_email || ' was not found.');
  END IF;

  -- Update encrypted password using bcrypt in auth.users table
  UPDATE auth.users
  SET encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf')),
      updated_at = NOW()
  WHERE id = v_user_id;

  RETURN jsonb_build_object('success', true, 'message', 'Password updated successfully.');
END;
$$;

-- 3. Create RPC alias update_user_password
CREATE OR REPLACE FUNCTION public.update_user_password(
  email_input text,
  new_password_input text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
  RETURN public.reset_password_by_email(email_input, new_password_input);
END;
$$;

-- 4. Grant execution permissions to public/anon/authenticated roles
GRANT EXECUTE ON FUNCTION public.reset_password_by_email(text, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_user_password(text, text) TO anon, authenticated, service_role;
