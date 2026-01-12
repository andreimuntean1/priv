-- Migration to add DEV environment tables
-- Created: 2024-01-12

-- 1. Create _dev tables matching the structure of production tables

-- Users Dev
CREATE TABLE IF NOT EXISTS public.users_dev (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(255) NOT NULL,
  avatar_url TEXT,
  is_online BOOLEAN DEFAULT FALSE,
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Messages Dev
CREATE TABLE IF NOT EXISTS public.messages_dev (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  content TEXT NOT NULL,
  sender_id UUID REFERENCES public.users_dev(id) ON DELETE CASCADE NOT NULL,
  reply_to_id UUID REFERENCES public.messages_dev(id) ON DELETE SET NULL,
  message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file', 'audio')),
  is_edited BOOLEAN DEFAULT FALSE,
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- File Attachments Dev
CREATE TABLE IF NOT EXISTS public.file_attachments_dev (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  message_id UUID REFERENCES public.messages_dev(id) ON DELETE CASCADE,
  file_name VARCHAR(255) NOT NULL,
  file_url TEXT NOT NULL,
  file_type VARCHAR(100) NOT NULL,
  file_size BIGINT NOT NULL,
  uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Message Status Dev
CREATE TABLE IF NOT EXISTS public.message_status_dev (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  message_id UUID REFERENCES public.messages_dev(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.users_dev(id) ON DELETE CASCADE NOT NULL,
  status VARCHAR(20) DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read')),
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(message_id, user_id)
);

-- FCM Tokens Dev
CREATE TABLE IF NOT EXISTS public.fcm_tokens_dev (
  user_id UUID REFERENCES public.users_dev(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, token)
);


-- 2. Create Indexes for Dev tables

-- Messages Dev Indexes
CREATE INDEX IF NOT EXISTS idx_messages_dev_sender_id ON public.messages_dev(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_dev_created_at ON public.messages_dev(created_at);
CREATE INDEX IF NOT EXISTS idx_messages_dev_reply_to_id ON public.messages_dev(reply_to_id);
CREATE INDEX IF NOT EXISTS idx_messages_dev_content_fts ON public.messages_dev USING gin(to_tsvector('english', content));

-- File Attachments Dev Indexes
CREATE INDEX IF NOT EXISTS idx_file_attachments_dev_message_id ON public.file_attachments_dev(message_id);

-- Message Status Dev Indexes
CREATE INDEX IF NOT EXISTS idx_message_status_dev_message_id ON public.message_status_dev(message_id);
CREATE INDEX IF NOT EXISTS idx_message_status_dev_user_id ON public.message_status_dev(user_id);


-- 3. Enable RLS and Create Policies for Dev tables

-- Users Dev
ALTER TABLE public.users_dev ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all dev users" ON public.users_dev
  FOR SELECT USING (true);

CREATE POLICY "Users can update own dev profile" ON public.users_dev
  FOR UPDATE USING (auth.uid() = id);

-- Messages Dev
ALTER TABLE public.messages_dev ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all dev messages" ON public.messages_dev
  FOR SELECT USING (true);

CREATE POLICY "Users can insert own dev messages" ON public.messages_dev
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update own dev messages" ON public.messages_dev
  FOR UPDATE USING (auth.uid() = sender_id);

-- File Attachments Dev
ALTER TABLE public.file_attachments_dev ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all dev file attachments" ON public.file_attachments_dev
  FOR SELECT USING (true);

CREATE POLICY "Users can insert dev file attachments" ON public.file_attachments_dev
  FOR INSERT WITH CHECK (true);

-- Message Status Dev
ALTER TABLE public.message_status_dev ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view dev message status" ON public.message_status_dev
  FOR SELECT USING (true);

CREATE POLICY "Users can insert dev message status" ON public.message_status_dev
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own dev message status" ON public.message_status_dev
  FOR UPDATE USING (auth.uid() = user_id);

-- FCM Tokens Dev
ALTER TABLE public.fcm_tokens_dev ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own dev fcm tokens" ON public.fcm_tokens_dev
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own dev fcm tokens" ON public.fcm_tokens_dev
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own dev fcm tokens" ON public.fcm_tokens_dev
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own dev fcm tokens" ON public.fcm_tokens_dev
  FOR DELETE USING (auth.uid() = user_id);


-- 4. Update Triggers and Functions

-- Add updated_at triggers for Dev tables
CREATE TRIGGER handle_users_dev_updated_at
  BEFORE UPDATE ON public.users_dev
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_messages_dev_updated_at
  BEFORE UPDATE ON public.messages_dev
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Update handle_new_user to route based on 'is_dev' metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  IF (NEW.raw_user_meta_data->>'is_dev')::boolean IS TRUE THEN
    INSERT INTO public.users_dev (id, username, email, avatar_url)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'username', 'Dev User ' || substr(NEW.id::text, 1, 8)),
      NEW.email,
      NEW.raw_user_meta_data->>'avatar_url'
    );
  ELSE
    INSERT INTO public.users (id, username, email, avatar_url)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'username', 'User ' || substr(NEW.id::text, 1, 8)),
      NEW.email,
      NEW.raw_user_meta_data->>'avatar_url'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.users_dev;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages_dev;
ALTER PUBLICATION supabase_realtime ADD TABLE public.file_attachments_dev;
ALTER PUBLICATION supabase_realtime ADD TABLE public.message_status_dev;
