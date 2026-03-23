import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { supabaseAdmin, createSupabaseClient } from '../_shared/supabase.ts'
import { SignJWT } from 'https://deno.land/x/jose@v4.14.4/index.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { library_id, purpose } = await req.json()

    if (!purpose || !['renew', 'add-library'].includes(purpose)) {
      throw new Error('Invalid purpose')
    }

    if (purpose === 'renew' && !library_id) {
      throw new Error('Library ID required for renewal')
    }

    // 1. Get User from Request
    const supabase = createSupabaseClient(req)
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    
    if (authError || !user || !user.email) {
      throw new Error('Unauthorized')
    }

    // 2. Verify Owner Profile (using Admin service role)
    const { data: ownerProfile, error: profileError } = await supabaseAdmin
      .from('staff')
      .select('name, role, library_ids')
      .eq('user_id', user.id)
      .eq('role', 'owner')
      .maybeSingle()

    if (profileError || !ownerProfile) {
      throw new Error('Forbidden: No owner profile found')
    }

    if (purpose === 'renew' && (!ownerProfile.library_ids || !ownerProfile.library_ids.includes(library_id))) {
      throw new Error('Forbidden: You do not own this library')
    }

    // 3. Fetch phone from library
    let ownerPhone = ''
    if (ownerProfile.library_ids && ownerProfile.library_ids.length > 0) {
      const { data: libData } = await supabaseAdmin
        .from('libraries')
        .select('phone')
        .eq('id', ownerProfile.library_ids[0])
        .maybeSingle()
      
      if (libData && libData.phone) {
        ownerPhone = libData.phone
      }
    }

    // 4. Generate Token
    const jwtSecret = Deno.env.get('JWT_SECRET')
    if (!jwtSecret) throw new Error('JWT secret not configured')

    const secret = new TextEncoder().encode(jwtSecret)
    const token = await new SignJWT({
      owner_id: user.id,
      owner_email: user.email,
      owner_name: ownerProfile.name || '',
      owner_phone: ownerPhone,
      library_id: purpose === 'renew' ? library_id : undefined,
      purpose
    })
      .setProtectedHeader({ alg: 'HS256' })
      .setIssuedAt()
      .setExpirationTime('15m')
      .sign(secret)

    return new Response(
      JSON.stringify({ token }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    console.error('Generate-token error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
