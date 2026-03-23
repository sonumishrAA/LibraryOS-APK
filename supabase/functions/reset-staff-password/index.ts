import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

const createSupabaseClient = (req: Request) => createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_ANON_KEY')!,
  { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
)

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { staff_user_id, new_password, library_id } = await req.json()

    if (!staff_user_id || !new_password || !library_id) {
      throw new Error('Missing fields')
    }

    if (new_password.length < 8) {
      throw new Error('Password must be at least 8 characters')
    }

    const supabase = createSupabaseClient(req)
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) throw new Error('Unauthorized')

    const { data: owner } = await supabaseAdmin
      .from('staff')
      .select('id')
      .eq('user_id', user.id)
      .eq('role', 'owner')
      .contains('library_ids', [library_id])
      .single()

    if (!owner) throw new Error('Forbidden: Not the owner')

    const { data: staffMember } = await supabaseAdmin
      .from('staff')
      .select('id')
      .eq('user_id', staff_user_id)
      .eq('role', 'staff')
      .contains('library_ids', [library_id])
      .single()

    if (!staffMember) throw new Error('Staff not found in this library')

    const { error: updateError } = await supabaseAdmin
      .auth.admin.updateUserById(staff_user_id, {
        password: new_password
      })

    if (updateError) throw updateError

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    console.error('Reset staff password error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
