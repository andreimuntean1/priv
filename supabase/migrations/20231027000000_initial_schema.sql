-- Supabase Database Schema for Private Messaging App

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable RLS (Row Level Security)
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

-- Users table (extends auth.users)
CREATE TABLE public.users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(255) NOT NULL,
  avatar_url TEXT,
  is_online BOOLEAN DEFAULT FALSE,
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Messages table
CREATE TABLE public.messages (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  content TEXT NOT NULL,
  sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
  message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'file', 'audio')),
  is_edited BOOLEAN DEFAULT FALSE,
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- File attachments table
CREATE TABLE public.file_attachments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE,
  file_name VARCHAR(255) NOT NULL,
  file_url TEXT NOT NULL,
  file_type VARCHAR(100) NOT NULL,
  file_size BIGINT NOT NULL,
  uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Message delivery status table
CREATE TABLE public.message_status (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  message_id UUID REFERENCES public.messages(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  status VARCHAR(20) DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'read')),
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(message_id, user_id)
);

-- Indexes for performance
CREATE INDEX idx_messages_sender_id ON public.messages(sender_id);
CREATE INDEX idx_messages_created_at ON public.messages(created_at);
CREATE INDEX idx_messages_reply_to_id ON public.messages(reply_to_id);
CREATE INDEX idx_file_attachments_message_id ON public.file_attachments(message_id);
CREATE INDEX idx_message_status_message_id ON public.message_status(message_id);
CREATE INDEX idx_message_status_user_id ON public.message_status(user_id);

-- Full text search index for messages
CREATE INDEX idx_messages_content_fts ON public.messages USING gin(to_tsvector('english', content));

-- Row Level Security Policies

-- Users table policies
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all users" ON public.users
  FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- Messages table policies
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all messages" ON public.messages
  FOR SELECT USING (true);

CREATE POLICY "Users can insert own messages" ON public.messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update own messages" ON public.messages
  FOR UPDATE USING (auth.uid() = sender_id);

-- File attachments table policies
ALTER TABLE public.file_attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all file attachments" ON public.file_attachments
  FOR SELECT USING (true);

CREATE POLICY "Users can insert file attachments" ON public.file_attachments
  FOR INSERT WITH CHECK (true);

-- Message status table policies
ALTER TABLE public.message_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view message status" ON public.message_status
  FOR SELECT USING (true);

CREATE POLICY "Users can insert message status" ON public.message_status
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own message status" ON public.message_status
  FOR UPDATE USING (auth.uid() = user_id);

-- Functions and Triggers

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER handle_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_messages_updated_at
  BEFORE UPDATE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Function to handle user creation
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

-- Trigger for new user creation
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Storage buckets
INSERT INTO storage.buckets (id, name, public) VALUES 
  ('message-attachments', 'message-attachments', true),
  ('profile-avatars', 'profile-avatars', true);

-- Storage policies
CREATE POLICY "Users can upload message attachments" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'message-attachments' AND auth.role() = 'authenticated');

CREATE POLICY "Users can view message attachments" ON storage.objects
  FOR SELECT USING (bucket_id = 'message-attachments');

CREATE POLICY "Users can upload profile avatars" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'profile-avatars' AND auth.role() = 'authenticated');

CREATE POLICY "Users can view profile avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'profile-avatars');

-- Real-time subscriptions (enable for all tables)
ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.file_attachments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.message_status;