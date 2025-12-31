-- DATA SAFETY CHECK:
-- The following operations DROP tables and columns. 
-- Ensure you have verified these are unused or that data loss is acceptable.
-- 1. 'message_status' table contained read/delivered receipts. Dropping this removes "Read" status functionality.
-- 2. 'is_online' and 'last_seen' columns tracked user presence. Dropping this removes "Active Status" functionality.

-- 1. Drop redundant tables related to "Read Messages" (Read Receipts)
DROP TABLE IF EXISTS public.message_status;

-- 2. Drop redundant columns related to "Active Status" feature
ALTER TABLE public.users DROP COLUMN IF EXISTS is_online;
ALTER TABLE public.users DROP COLUMN IF EXISTS last_seen;

-- Remaining Active Tables (Do NOT Drop):
-- - users (Core user data)
-- - messages (Chat history)
-- - file_attachments (Images/Files)
-- - fcm_tokens (Push notifications)
-- - app_versions (Update system)
