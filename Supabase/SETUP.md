# Supabase Setup Guide for Moment

## 1. Create Supabase Project

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard)
2. Click "New Project"
3. Enter project details:
   - **Name:** `moment-app`
   - **Database Password:** (save this securely)
   - **Region:** Choose closest to your users
4. Wait for project to be created (~2 minutes)

## 2. Run Database Schema

1. In your Supabase dashboard, go to **SQL Editor**
2. Click "New Query"
3. Copy the entire contents of `schema.sql` and paste it
4. Click "Run" (or Cmd+Enter)
5. You should see "Success. No rows returned"

## 3. Get API Credentials

1. Go to **Settings** → **API**
2. Copy these values:
   - **Project URL:** `https://xxxxx.supabase.co`
   - **anon/public key:** `eyJhbGc...`

3. Update `SupabaseService.swift`:

```swift
enum SupabaseConfig {
    static let url = URL(string: "https://YOUR_PROJECT_ID.supabase.co")!
    static let anonKey = "YOUR_ANON_KEY"
}
```

## 4. Enable Authentication

### Email Auth (default)
Already enabled. No action needed.

### Apple Sign-In (recommended)

1. Go to **Authentication** → **Providers**
2. Enable **Apple**
3. Follow the [Apple Sign-In setup guide](https://supabase.com/docs/guides/auth/social-login/auth-apple)

## 5. Deploy Edge Functions

### Install Supabase CLI

```bash
# macOS
brew install supabase/tap/supabase

# Or via npm
npm install -g supabase
```

### Login and Link Project

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_ID
```

### Deploy Functions

```bash
cd /path/to/Moment/Supabase

# Deploy LH positive notification function
supabase functions deploy send-lh-positive-notification

# Deploy daily notifications function  
supabase functions deploy send-daily-notifications
```

### Set Function Secrets

For push notifications to work, set your APNs credentials:

```bash
supabase secrets set APNS_URL=https://your-push-service.com
supabase secrets set APNS_KEY=your-apns-key
```

## 6. Schedule Daily Notifications

Use pg_cron to run daily notifications at 8:00 AM:

1. Go to **SQL Editor**
2. Run this query:

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule daily notifications at 8:00 AM UTC
-- Adjust timezone as needed
SELECT cron.schedule(
  'daily-fertility-notifications',
  '0 8 * * *',  -- Every day at 8:00 AM
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_ID.supabase.co/functions/v1/send-daily-notifications',
    headers := '{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb
  );
  $$
);
```

## 7. Add Supabase Swift Package to Xcode

1. Open `Moment.xcodeproj` in Xcode
2. Go to **File** → **Add Package Dependencies**
3. Enter URL: `https://github.com/supabase/supabase-swift`
4. Click **Add Package**
5. Select these products:
   - `Supabase`
   - `Auth`
   - `Realtime`
   - `Functions`
6. Click **Add Package**

## 8. Configure Push Notifications

### In Apple Developer Portal

1. Go to [developer.apple.com](https://developer.apple.com)
2. Create an APNs Key:
   - **Certificates, Identifiers & Profiles** → **Keys**
   - Click **+** to create new key
   - Enable **Apple Push Notifications service (APNs)**
   - Download the `.p8` file (save it securely!)
   - Note the **Key ID**

3. Note your **Team ID** (Account → Membership)

### In Xcode

1. Select your project target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **Push Notifications**
5. Add **Background Modes** and enable:
   - Remote notifications

### Connect to Push Service

For production, you'll need a push notification service:
- **Option A:** Use Firebase Cloud Messaging (easier)
- **Option B:** Direct APNs integration (more control)

## 9. Test Your Setup

### Test Database Connection

```swift
// In your app or playground
Task {
    do {
        let profile = try await SupabaseService.shared.signUp(
            email: "test@example.com",
            password: "testpassword123",
            name: "Test User",
            role: .woman
        )
        print("✅ Profile created:", profile)
    } catch {
        print("❌ Error:", error)
    }
}
```

### Test Invite Code Flow

```swift
// User 1 (Woman) - Get invite code
let couple = try await SupabaseService.shared.getCouple()
print("Invite code:", couple?.inviteCode ?? "none")

// User 2 (Partner) - Join with code
let result = try await SupabaseService.shared.joinCouple(inviteCode: "ABC123")
print("Join result:", result)
```

## Environment Variables Summary

| Variable | Where to Set | Description |
|----------|--------------|-------------|
| `SUPABASE_URL` | SupabaseService.swift | Your project URL |
| `SUPABASE_ANON_KEY` | SupabaseService.swift | Public anon key |
| `APNS_URL` | Supabase Secrets | Push notification endpoint |
| `APNS_KEY` | Supabase Secrets | APNs authentication key |

## Troubleshooting

### "Invalid API key"
- Make sure you're using the **anon** key, not the service role key
- Check for extra whitespace in the key

### "Permission denied" on queries
- Row Level Security (RLS) is enabled
- Make sure user is authenticated before making queries
- Check RLS policies in the SQL schema

### Real-time not working
- Ensure tables are added to `supabase_realtime` publication
- Check that RLS policies allow SELECT for the user

### Push notifications not sending
- Verify APNs credentials are correct
- Check Edge Function logs in Supabase dashboard
- Ensure device has granted notification permissions

## Next Steps

1. ✅ Set up Supabase project
2. ✅ Run database schema
3. ✅ Configure authentication
4. ✅ Deploy Edge Functions
5. ✅ Add Swift package
6. ⬜ Set up push notification service
7. ⬜ Test with two real devices
8. ⬜ Submit to TestFlight
