-- App Version Management Table
CREATE TABLE public.app_versions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  version_code INTEGER NOT NULL UNIQUE,
  version_name VARCHAR(20) NOT NULL,
  download_url TEXT NOT NULL,
  changelog TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX idx_app_versions_version_code ON public.app_versions(version_code);
CREATE INDEX idx_app_versions_active ON public.app_versions(is_active);

-- RLS Policies
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read version info
CREATE POLICY "Authenticated users can read app versions" ON public.app_versions
  FOR SELECT USING (auth.role() = 'authenticated');

-- Only service role can insert/update versions (for admin use)
CREATE POLICY "Service role can manage app versions" ON public.app_versions
  FOR ALL USING (auth.role() = 'service_role');

-- Function to get latest active version
CREATE OR REPLACE FUNCTION get_latest_app_version()
RETURNS TABLE (
  version_code INTEGER,
  version_name VARCHAR(20),
  download_url TEXT,
  changelog TEXT,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    av.version_code,
    av.version_name,
    av.download_url,
    av.changelog,
    av.updated_at
  FROM public.app_versions av
  WHERE av.is_active = TRUE
  ORDER BY av.version_code DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_latest_app_version() TO authenticated;

-- Sample data (optional)
INSERT INTO public.app_versions (version_code, version_name, download_url, changelog)
VALUES (
  1,
  '1.0.0',
  'https://your-supabase-project.supabase.co/storage/v1/object/public/app-updates/mesagerie-privata-v1.0.0.aab',
  'Initial release of Mesagerie Privată'
);