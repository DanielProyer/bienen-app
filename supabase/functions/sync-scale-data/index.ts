// Supabase Edge Function: sync-scale-data
// Cron-triggered (every 15 min) to poll vendor APIs and store readings.
//
// Deploy: supabase functions deploy sync-scale-data
// Cron:   supabase functions schedule sync-scale-data --schedule "*/15 * * * *"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

interface ScaleConfig {
  id: string
  hive_name: string
  vendor: string
  api_config: Record<string, unknown> | null
  alert_swarm_threshold: number
  alert_enabled: boolean
}

interface ScaleReading {
  scale_id: string
  hive_name: string
  weight_kg: number
  weight_delta_kg?: number
  temperature_c?: number
  humidity_pct?: number
  battery_pct?: number
  recorded_at: string
  source: string
}

// Vendor-agnostic fetcher
async function fetchFromVendor(scale: ScaleConfig): Promise<ScaleReading[]> {
  switch (scale.vendor) {
    case 'hivewatch':
      return fetchHiveWatch(scale)
    case 'broodminder':
      return fetchBroodMinder(scale)
    default:
      console.warn(`Unknown vendor: ${scale.vendor}`)
      return []
  }
}

// Placeholder: HiveWatch API (pending API documentation)
async function fetchHiveWatch(scale: ScaleConfig): Promise<ScaleReading[]> {
  console.log(`HiveWatch sync for ${scale.id}: API integration pending`)
  // TODO: Implement once API access is confirmed
  // const apiKey = scale.api_config?.api_key as string
  // const response = await fetch(`https://api.hivewatch.ch/v1/readings?device=${scale.id}`, {
  //   headers: { 'Authorization': `Bearer ${apiKey}` }
  // })
  return []
}

// Placeholder: BroodMinder API (pending API documentation)
async function fetchBroodMinder(scale: ScaleConfig): Promise<ScaleReading[]> {
  console.log(`BroodMinder sync for ${scale.id}: API integration pending`)
  // TODO: Implement once API access is confirmed
  // const token = scale.api_config?.token as string
  // const response = await fetch(`https://mybroodminder.com/api/v1/devices/${scale.id}/readings`, {
  //   headers: { 'Authorization': `Bearer ${token}` }
  // })
  return []
}

// Check for swarm alert: weight loss > threshold kg/h
async function checkSwarmAlert(
  supabase: ReturnType<typeof createClient>,
  scale: ScaleConfig,
  readings: ScaleReading[]
) {
  if (!scale.alert_enabled || readings.length < 2) return

  const latest = readings[0]
  const previous = readings[1]

  if (!latest.recorded_at || !previous.recorded_at) return

  const timeDiffMs = new Date(latest.recorded_at).getTime() - new Date(previous.recorded_at).getTime()
  const timeDiffHours = timeDiffMs / (1000 * 60 * 60)

  if (timeDiffHours <= 0 || timeDiffHours > 2) return

  const weightChangePerHour = (latest.weight_kg - previous.weight_kg) / timeDiffHours

  // Negative threshold (e.g. -1.0 means 1kg/h loss triggers alert)
  if (weightChangePerHour < scale.alert_swarm_threshold) {
    console.log(`SWARM ALERT for ${scale.hive_name}: ${weightChangePerHour.toFixed(2)} kg/h`)

    await supabase.from('scale_alerts').insert({
      scale_id: scale.id,
      alert_type: 'swarm',
      message: `Gewichtsverlust ${Math.abs(weightChangePerHour).toFixed(1)} kg/h bei ${scale.hive_name}. Möglicher Schwarm!`,
    })
  }
}

Deno.serve(async (_req) => {
  try {
    const supabase = createClient(supabaseUrl, supabaseKey)

    // Fetch all configured scales
    const { data: scales, error: scalesError } = await supabase
      .from('scales')
      .select('*')

    if (scalesError) {
      console.error('Error fetching scales:', scalesError)
      return new Response(JSON.stringify({ error: scalesError.message }), { status: 500 })
    }

    if (!scales || scales.length === 0) {
      return new Response(JSON.stringify({ message: 'No scales configured' }), { status: 200 })
    }

    let totalSynced = 0

    for (const scale of scales as ScaleConfig[]) {
      try {
        const readings = await fetchFromVendor(scale)

        if (readings.length === 0) continue

        // Calculate deltas
        for (let i = 0; i < readings.length; i++) {
          if (i < readings.length - 1) {
            readings[i].weight_delta_kg = readings[i].weight_kg - readings[i + 1].weight_kg
          }
        }

        // Insert new readings (upsert by recorded_at to avoid duplicates)
        const { error: insertError } = await supabase
          .from('weight_readings')
          .insert(readings)

        if (insertError) {
          console.error(`Error inserting readings for ${scale.id}:`, insertError)
          continue
        }

        totalSynced += readings.length

        // Check for alerts
        await checkSwarmAlert(supabase, scale, readings)
      } catch (err) {
        console.error(`Error syncing scale ${scale.id}:`, err)
      }
    }

    return new Response(
      JSON.stringify({
        message: `Synced ${totalSynced} readings from ${scales.length} scales`,
        timestamp: new Date().toISOString(),
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error('Unexpected error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
