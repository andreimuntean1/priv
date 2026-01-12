-- Fix script to move dev users from 'users' (prod) to 'users_dev' (dev)
-- Modified to use defaults for fields that might be missing in older schemas

-- 1. Copy users to users_dev
INSERT INTO public.users_dev (id, username, email, avatar_url, created_at, updated_at)
SELECT 
    id, 
    username, 
    email, 
    avatar_url, 
    created_at, 
    updated_at
FROM public.users
WHERE email IN ('priv.test1@andreimuntean.dev', 'priv.test2@andreimuntean.dev')
ON CONFLICT (id) DO NOTHING;

-- 2. Remove them from public.users
DELETE FROM public.users
WHERE email IN ('priv.test1@andreimuntean.dev', 'priv.test2@andreimuntean.dev');
