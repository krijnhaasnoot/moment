// Supabase Edge Function: Send LH Positive Notification
// Triggers when a woman logs a positive LH test
// Sends push notification to her partner

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationPayload {
  title: string
  body: string
  data?: Record<string, string>
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get user from auth header
    const authHeader = req.headers.get('Authorization')!
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Get woman's profile and couple info
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*, couples(*)')
      .eq('id', user.id)
      .single()

    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: 'Profile not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Check if couple is linked
    if (!profile.couples?.is_linked || !profile.couples?.partner_id) {
      return new Response(JSON.stringify({ message: 'No partner linked' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Get partner's profile
    const { data: partner, error: partnerError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', profile.couples.partner_id)
      .single()

    if (partnerError || !partner || !partner.push_token) {
      return new Response(JSON.stringify({ message: 'Partner has no push token' }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Prepare notification based on tone preference
    const isExplicit = profile.notification_tone === 'explicit'
    const notification: NotificationPayload = {
      title: 'Moment',
      body: isExplicit 
        ? 'Peak fertility detected — best timing today'
        : 'Important check-in — connect with your partner',
      data: {
        type: 'lh_positive',
        timestamp: new Date().toISOString()
      }
    }

    // Send push notification via the send-push edge function
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const pushResponse = await fetch(`${supabaseUrl}/functions/v1/send-push`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        token: partner.push_token,
        title: notification.title,
        body: notification.body,
        data: notification.data
      })
    })

    if (!pushResponse.ok) {
      console.error('Failed to send push notification:', await pushResponse.text())
    }

    // Log notification
    await supabase
      .from('notification_log')
      .insert({
        user_id: partner.id,
        type: 'lh_positive',
        content: notification.body
      })

    return new Response(
      JSON.stringify({ success: true, message: 'Notification sent' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
