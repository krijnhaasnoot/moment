// Supabase Edge Function: Send Daily Fertility Notifications
// Scheduled via pg_cron to run daily at 8:00 AM
// Sends personalized notifications to all users

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationContent {
  title: string
  body: string
}

// Get notification content for woman
function getWomanNotification(fertilityLevel: string): NotificationContent {
  switch (fertilityLevel) {
    case 'peak':
      return {
        title: 'Moment',
        body: 'Peak fertility today — your most fertile time'
      }
    case 'high':
      return {
        title: 'Moment',
        body: 'High fertility window — good timing ahead'
      }
    default:
      return {
        title: 'Moment',
        body: 'Low fertility — rest and prepare'
      }
  }
}

// Get notification content for partner
function getPartnerNotification(fertilityLevel: string, tone: string): NotificationContent | null {
  // Partners only get notifications for high/peak fertility
  if (fertilityLevel === 'low') {
    return null
  }

  const isExplicit = tone === 'explicit'

  if (fertilityLevel === 'peak') {
    return {
      title: 'Moment',
      body: isExplicit 
        ? 'Peak fertility today — great timing'
        : 'Check-in time — connect with your partner'
    }
  }

  // High fertility
  return {
    title: 'Moment',
    body: isExplicit 
      ? 'High fertility window — consider connecting today'
      : 'Good time to connect'
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const today = new Date().toISOString().split('T')[0]
    let notificationsSent = 0

    // Get all active cycles with today's data
    const { data: cycles, error: cyclesError } = await supabase
      .from('cycles')
      .select(`
        id,
        user_id,
        couple_id,
        cycle_days!inner(fertility_level),
        profiles!cycles_user_id_fkey(
          id,
          name,
          notification_tone,
          notifications_enabled,
          push_token
        ),
        couples(
          partner_id,
          is_linked
        )
      `)
      .eq('is_active', true)
      .eq('cycle_days.date', today)

    if (cyclesError) {
      throw cyclesError
    }

    for (const cycle of cycles || []) {
      const fertilityLevel = cycle.cycle_days[0]?.fertility_level || 'low'
      const woman = cycle.profiles
      const couple = cycle.couples

      // Send notification to woman
      if (woman?.notifications_enabled && woman?.push_token) {
        const notification = getWomanNotification(fertilityLevel)
        
        await sendPushNotification(woman.push_token, notification)
        
        await supabase
          .from('notification_log')
          .insert({
            user_id: woman.id,
            type: 'daily_fertility',
            content: notification.body
          })
        
        notificationsSent++
      }

      // Send notification to partner (if linked and high/peak)
      if (couple?.is_linked && couple?.partner_id) {
        const { data: partner } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', couple.partner_id)
          .single()

        if (partner?.notifications_enabled && partner?.push_token) {
          const notification = getPartnerNotification(fertilityLevel, woman?.notification_tone || 'discreet')
          
          if (notification) {
            await sendPushNotification(partner.push_token, notification)
            
            await supabase
              .from('notification_log')
              .insert({
                user_id: partner.id,
                type: 'daily_fertility',
                content: notification.body
              })
            
            notificationsSent++
          }
        }
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Sent ${notificationsSent} notifications` 
      }),
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

async function sendPushNotification(token: string, notification: NotificationContent) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

  if (!supabaseUrl || !serviceKey) {
    console.log('Push notification (mock):', { token: token.substring(0, 10) + '...', notification })
    return
  }

  try {
    const response = await fetch(`${supabaseUrl}/functions/v1/send-push`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${serviceKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        token,
        title: notification.title,
        body: notification.body,
        data: { type: 'daily_fertility' }
      })
    })
    
    if (!response.ok) {
      console.error('Failed to send push:', await response.text())
    }
  } catch (error) {
    console.error('Failed to send push:', error)
  }
}
