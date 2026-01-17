// Supabase Edge Function: Send Push Notification via APNs
// Generic function to send push notifications to iOS devices

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface PushPayload {
  token: string
  title: string
  body: string
  data?: Record<string, string>
  badge?: number
  sound?: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { token, title, body, data, badge, sound } = await req.json() as PushPayload

    if (!token || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: token, title, body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // APNs configuration from environment
    const teamId = Deno.env.get('APNS_TEAM_ID')
    const keyId = Deno.env.get('APNS_KEY_ID')
    const privateKey = Deno.env.get('APNS_PRIVATE_KEY')
    const bundleId = Deno.env.get('APNS_BUNDLE_ID') || 'com.kinder.Moment'
    const isProduction = Deno.env.get('APNS_PRODUCTION') === 'true'

    if (!teamId || !keyId || !privateKey) {
      console.error('APNs credentials not configured')
      return new Response(
        JSON.stringify({ error: 'Push notifications not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Generate JWT for APNs authentication
    const jwt = await generateAPNsJWT(teamId, keyId, privateKey)

    // APNs endpoint
    const apnsHost = isProduction 
      ? 'api.push.apple.com' 
      : 'api.sandbox.push.apple.com'

    // Build APNs payload
    const apnsPayload = {
      aps: {
        alert: {
          title,
          body,
        },
        sound: sound || 'default',
        badge: badge,
        'mutable-content': 1,
      },
      ...data, // Custom data
    }

    // Send to APNs
    const response = await fetch(
      `https://${apnsHost}/3/device/${token}`,
      {
        method: 'POST',
        headers: {
          'Authorization': `bearer ${jwt}`,
          'apns-topic': bundleId,
          'apns-push-type': 'alert',
          'apns-priority': '10',
          'apns-expiration': '0',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(apnsPayload),
      }
    )

    if (response.ok) {
      const apnsId = response.headers.get('apns-id')
      return new Response(
        JSON.stringify({ success: true, apnsId }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    } else {
      const errorBody = await response.text()
      console.error('APNs error:', response.status, errorBody)
      return new Response(
        JSON.stringify({ error: 'APNs delivery failed', status: response.status, details: errorBody }),
        { status: response.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Generate JWT for APNs authentication
async function generateAPNsJWT(teamId: string, keyId: string, privateKey: string): Promise<string> {
  // Parse the private key (P8 format)
  const key = await jose.importPKCS8(privateKey, 'ES256')

  const jwt = await new jose.SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(key)

  return jwt
}
