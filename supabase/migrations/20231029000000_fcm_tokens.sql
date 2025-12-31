-- Create FCM Tokens table
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  token TEXT NOT NULL,
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, token)
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON public.fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_token ON public.fcm_tokens(token);

-- Row Level Security
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Users can view their own tokens
CREATE POLICY "Users can view own fcm tokens" ON public.fcm_tokens
  FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own tokens
CREATE POLICY "Users can insert own fcm tokens" ON public.fcm_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own tokens
CREATE POLICY "Users can update own fcm tokens" ON public.fcm_tokens
  FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own tokens
CREATE POLICY "Users can delete own fcm tokens" ON public.fcm_tokens
  FOR DELETE USING (auth.uid() = user_id);

-- Function to handle token updates
CREATE OR REPLACE FUNCTION public.handle_token_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.last_updated = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER handle_fcm_tokens_updated_at
  BEFORE UPDATE ON public.fcm_tokens
  FOR EACH ROW EXECUTE FUNCTION public.handle_token_updated_at();
