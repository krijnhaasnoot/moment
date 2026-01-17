# Push Notifications Setup Guide

## Overview
This guide walks you through setting up Apple Push Notifications (APNs) for the Moment app.

---

## Step 1: Create APNs Key in Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles** → **Keys**
3. Click the **+** button to create a new key
4. Enter a name: `Moment Push Notifications`
5. Check **Apple Push Notifications service (APNs)**
6. Click **Continue** → **Register**
7. **Download the key file** (AuthKey_XXXXXXXXXX.p8)
   - ⚠️ You can only download this ONCE!
8. Note your **Key ID** (shown on the key details page)
9. Note your **Team ID** (found in Membership section)

---

## Step 2: Configure Supabase

### Option A: Using Supabase Edge Functions (Recommended)

1. Create the Edge Function:

```bash
cd Supabase
supabase functions new send-push-notification
```

2. Add your APNs credentials as secrets:

```bash
supabase secrets set APNS_KEY_ID=your_key_id
supabase secrets set APNS_TEAM_ID=your_team_id
supabase secrets set APNS_BUNDLE_ID=com.kinder.Moment
supabase secrets set APNS_KEY_BASE64=$(base64 -i AuthKey_XXXXXXXXXX.p8)
```

3. Create the Edge Function code in `supabase/functions/send-push-notification/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jwt from "https://deno.land/x/djwt@v2.8/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { userId, title, body, data } = await req.json();

    // Get user's push token from database
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: profile, error } = await supabase
      .from("profiles")
      .select("push_token")
      .eq("id", userId)
      .single();

    if (error || !profile?.push_token) {
      return new Response(JSON.stringify({ error: "No push token found" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Create APNs JWT token
    const keyId = Deno.env.get("APNS_KEY_ID")!;
    const teamId = Deno.env.get("APNS_TEAM_ID")!;
    const bundleId = Deno.env.get("APNS_BUNDLE_ID")!;
    const privateKeyBase64 = Deno.env.get("APNS_KEY_BASE64")!;

    const privateKey = atob(privateKeyBase64);
    const key = await crypto.subtle.importKey(
      "pkcs8",
      new TextEncoder().encode(privateKey),
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign"]
    );

    const token = await jwt.create(
      { alg: "ES256", kid: keyId },
      { iss: teamId, iat: Math.floor(Date.now() / 1000) },
      key
    );

    // Send to APNs
    const apnsUrl = `https://api.push.apple.com/3/device/${profile.push_token}`;
    
    const response = await fetch(apnsUrl, {
      method: "POST",
      headers: {
        "authorization": `bearer ${token}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
      body: JSON.stringify({
        aps: {
          alert: { title, body },
          sound: "default",
          badge: 1,
        },
        ...data,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`APNs error: ${error}`);
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
```

4. Deploy the function:

```bash
supabase functions deploy send-push-notification
```

---

## Step 3: Update iOS App

The app is already configured to:
1. Request push notification permission
2. Register for remote notifications
3. Save device token to Supabase

Make sure your `Moment.entitlements` file includes:
```xml
<key>aps-environment</key>
<string>development</string>  <!-- Change to "production" for App Store -->
```

---

## Step 4: Test Push Notifications

1. Run the app on a **real device** (simulators don't receive push)
2. Complete onboarding to register the device token
3. Check Supabase dashboard → `profiles` table → `push_token` column
4. Test via Supabase Dashboard → Edge Functions → Invoke:

```json
{
  "userId": "user-uuid-here",
  "title": "Test Notification",
  "body": "This is a test push notification"
}
```

---

## Step 5: Trigger Notifications from App Events

Update `SupabaseService.swift` to call the Edge Function:

```swift
func sendPushNotification(to userId: UUID, title: String, body: String) async throws {
    try await client.functions.invoke(
        "send-push-notification",
        options: .init(
            method: .post,
            body: [
                "userId": userId.uuidString,
                "title": title,
                "body": body
            ]
        )
    )
}
```

---

## Common Issues

### "Device token not found"
- Make sure notifications are enabled in device Settings
- Check that the token was saved to the `profiles` table

### "BadDeviceToken" from APNs
- Token might be from sandbox but sending to production (or vice versa)
- Token might have expired - user needs to re-register

### "InvalidProviderToken"
- Check that APNS_KEY_ID, APNS_TEAM_ID match your Apple Developer account
- Verify the .p8 key file is correctly base64 encoded

---

## Production Checklist

- [ ] Change `aps-environment` to `production` in entitlements
- [ ] Use production APNs endpoint: `api.push.apple.com`
- [ ] Set up database triggers to send notifications on events
- [ ] Add rate limiting to prevent notification spam
- [ ] Log notifications to `notification_log` table
