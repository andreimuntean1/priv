-- Migration: Add email field to users table
-- Run this migration on existing databases to add email support

-- Add email column to users table
ALTER TABLE public.users ADD COLUMN email VARCHAR(255);

-- Update existing users with their email from auth.users
UPDATE public.users 
SET email = auth.users.email 
FROM auth.users 
WHERE public.users.id = auth.users.id;

-- Make email column NOT NULL after populating existing data
ALTER TABLE public.users ALTER COLUMN email SET NOT NULL;

-- Update the handle_new_user function to include email
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, username, email, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', 'User ' || substr(NEW.id::text, 1, 8)),
    NEW.email,
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;