-- Test data for in-app update system
-- This creates a test version entry to verify the update system works

-- Insert a test version that's higher than current app version
-- Update these values based on your current app version in pubspec.yaml
INSERT INTO app_versions (
    version_name,
    version_code,
    platform,
    download_url,
    changelog,
    is_mandatory,
    is_active,
    created_at
) VALUES (
    '1.0.1',                    -- Version name (should be higher than current)
    2,                          -- Version code (should be higher than current build number)
    'android',                  -- Platform
    'https://example.com/test-update.aab',  -- Placeholder URL for testing
    '• Implementat sistemul de actualizare in-app
• Îmbunătățiri de interfață
• Corecții de erori',          -- Romanian changelog
    false,                      -- Not mandatory for testing
    true,                       -- Active
    NOW()                       -- Current timestamp
);

-- Query to check current app versions
SELECT 
    version_name,
    version_code,
    platform,
    download_url,
    changelog,
    is_mandatory,
    is_active,
    created_at
FROM app_versions 
WHERE platform = 'android' 
    AND is_active = true 
ORDER BY version_code DESC 
LIMIT 5;