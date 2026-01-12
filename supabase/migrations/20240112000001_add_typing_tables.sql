-- Migration to add chat_typing tables (PROD and DEV)
-- Based on TypingEvent model: chat_id (String), user_id (String), is_typing (bool), timestamp (DateTime)

-- 1. Create chat_typing (PROD)
CREATE TABLE IF NOT EXISTS public.chat_typing (
  chat_id TEXT NOT NULL, -- Using TEXT as chatId might not be UUID in all cases, or simplifies things
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  is_typing BOOLEAN DEFAULT FALSE,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (chat_id, user_id)
);

-- Enable RLS for PROD
ALTER TABLE public.chat_typing ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view typing status" ON public.chat_typing
  FOR SELECT USING (true);

CREATE POLICY "Users can insert/update own typing status" ON public.chat_typing
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Realtime for PROD
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_typing;


-- 2. Create chat_typing_dev (DEV)
CREATE TABLE IF NOT EXISTS public.chat_typing_dev (
  chat_id TEXT NOT NULL, 
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  is_typing BOOLEAN DEFAULT FALSE,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (chat_id, user_id)
);

-- Enable RLS for DEV
ALTER TABLE public.chat_typing_dev ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view dev typing status" ON public.chat_typing_dev
  FOR SELECT USING (true);

CREATE POLICY "Users can insert/update own dev typing status" ON public.chat_typing_dev
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Realtime for DEV
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_typing_dev;
