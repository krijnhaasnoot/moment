// Supabase Edge Function: Send Daily Fertility Notifications
// Scheduled via pg_cron to run daily at 8:00 AM
// Sends personalized notifications ONLY on high/peak fertility days
// Uses varied messages to keep notifications fresh and interesting

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

// Varied messages for women - HIGH fertility
const womanHighMessages = [
  "Je vruchtbare periode is begonnen 🌸",
  "Fertility window open — timing is goed de komende dagen",
  "Hoge vruchtbaarheid vandaag — je lichaam bereidt zich voor",
  "De komende dagen zijn gunstig ✨",
  "Je bent in je vruchtbare venster aangekomen",
  "Goede timing de komende 3-4 dagen",
]

// Varied messages for women - PEAK fertility
const womanPeakMessages = [
  "Piek vruchtbaarheid vandaag — je meest vruchtbare moment 🎯",
  "Dit is het! Je meest vruchtbare dag",
  "Ovulatie komt eraan — ideale timing vandaag",
  "Peak fertility — nu of nooit deze cyclus ⭐",
  "Je lichaam is klaar — vandaag is de dag",
  "Maximale vruchtbaarheid bereikt",
]

// Varied messages for partner - HIGH fertility (explicit)
const partnerHighExplicitMessages = [
  "Vruchtbare periode begonnen — goed moment om te connecten",
  "High fertility — de komende dagen zijn gunstig",
  "Het vruchtbare venster is open 💫",
  "Timing is goed deze week",
]

// Varied messages for partner - HIGH fertility (discreet)
const partnerHighDiscreetMessages = [
  "Goed moment om te connecten met je partner",
  "Quality time deze week ✨",
  "Mooie dagen om samen door te brengen",
  "Check in met je partner vandaag",
]

// Varied messages for partner - PEAK fertility (explicit)
const partnerPeakExplicitMessages = [
  "Peak fertility vandaag — het moment is daar 🎯",
  "Dit is de dag — maximale kans",
  "Ideale timing — vandaag telt het meest",
  "Nu of nooit deze cyclus ⭐",
]

// Varied messages for partner - PEAK fertility (discreet)
const partnerPeakDiscreetMessages = [
  "Belangrijk moment — neem de tijd samen",
  "Vandaag is een bijzondere dag 💫",
  "Check-in tijd — maak er iets moois van",
  "Quality time vandaag ✨",
]

// Fun fertility facts (optional, can be added to some messages)
const fertilityFacts = [
  "Wist je dat: Een eicel maar 12-24 uur leeft na de ovulatie",
  "Wist je dat: Zaadcellen kunnen tot 5 dagen overleven",
  "Wist je dat: Stress je cyclus kan beïnvloeden",
  "Wist je dat: Je lichaamstemperatuur stijgt na de ovulatie",
  "Wist je dat: De kans op zwangerschap per cyclus ~20-25% is",
]

function getRandomMessage(messages: string[]): string {
  return messages[Math.floor(Math.random() * messages.length)]
}

// Get notification content for woman (ONLY high/peak)
function getWomanNotification(fertilityLevel: string): NotificationContent | null {
  // Only notify on HIGH or PEAK days - no more boring "low fertility" messages
  if (fertilityLevel === 'low') {
    return null
  }

  if (fertilityLevel === 'peak') {
    return {
      title: 'Moment',
      body: getRandomMessage(womanPeakMessages)
    }
  }

  // High fertility
  return {
    title: 'Moment',
    body: getRandomMessage(womanHighMessages)
  }
}

// Get notification content for partner (ONLY high/peak)
function getPartnerNotification(fertilityLevel: string, tone: string): NotificationContent | null {
  // Partners only get notifications for high/peak fertility
  if (fertilityLevel === 'low') {
    return null
  }

  const isExplicit = tone === 'explicit'

  if (fertilityLevel === 'peak') {
    return {
      title: 'Moment',
      body: getRandomMessage(isExplicit ? partnerPeakExplicitMessages : partnerPeakDiscreetMessages)
    }
  }

  // High fertility
  return {
    title: 'Moment',
    body: getRandomMessage(isExplicit ? partnerHighExplicitMessages : partnerHighDiscreetMessages)
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
    let skippedLowFertility = 0

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

      // Send notification to woman (only if high/peak)
      if (woman?.notifications_enabled && woman?.push_token) {
        const notification = getWomanNotification(fertilityLevel)
        
        if (notification) {
          await sendPushNotification(woman.push_token, notification)
          
          await supabase
            .from('notification_log')
            .insert({
              user_id: woman.id,
              type: 'daily_fertility',
              content: notification.body
            })
          
          notificationsSent++
        } else {
          skippedLowFertility++
        }
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
        message: `Sent ${notificationsSent} notifications (skipped ${skippedLowFertility} low fertility days)` 
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
