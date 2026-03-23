import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { supabaseAdmin } from '../_shared/supabase.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { form_data, plan } = await req.json()

    // 1. Get Razorpay keys from environment
    const RAZORPAY_KEY_ID = Deno.env.get('RAZORPAY_KEY_ID')
    const RAZORPAY_KEY_SECRET = Deno.env.get('RAZORPAY_KEY_SECRET')

    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
      throw new Error('Razorpay keys not configured')
    }

    // 2. Fetch pricing if amount not provided or to verify
    const { data: pricing } = await supabaseAdmin
      .from('pricing_config')
      .select('amount')
      .eq('plan', plan)
      .single()
    
    const amount = pricing?.amount || form_data.amount
    if (!amount) throw new Error('Invalid plan or amount')

    // 3. Create Razorpay order using direct fetch
    const auth = btoa(`${RAZORPAY_KEY_ID}:${RAZORPAY_KEY_SECRET}`)
    const rzpRes = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Basic ${auth}`,
      },
      body: JSON.stringify({
        amount: amount * 100, // in paise
        currency: 'INR',
        receipt: `receipt_${Date.now()}`,
      }),
    })

    const order = await rzpRes.json()
    if (!rzpRes.ok) throw new Error(order.error?.description || 'Razorpay order creation failed')

    // 4. Store temp registration data
    const type = form_data?.owner?.isExisting ? 'add_library' : 'registration'
    const { error: tempError } = await supabaseAdmin
      .from('temp_registrations')
      .insert({
        razorpay_order_id: order.id,
        form_data: form_data,
      })

    if (tempError) throw tempError

    // 5. Insert pending subscription_payment row
    await supabaseAdmin.from('subscription_payments').insert({
      razorpay_order_id: order.id,
      amount: amount,
      plan: plan,
      status: 'pending',
      processed: false,
      type: type,
    })

    return new Response(
      JSON.stringify({ 
        order_id: order.id, 
        amount: amount 
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )

  } catch (error: any) {
    console.error(`create-payment-order error (${req.method}):`, error)
    
    let status = 400
    if (error.message?.includes('Database') || error.code) {
      status = 500
    }

    return new Response(JSON.stringify({ 
      error: error.message,
      method: req.method 
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: status,
    })
  }
})
