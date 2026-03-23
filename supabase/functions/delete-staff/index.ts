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
    const { staff_user_id, library_id } = await req.json()

    if (!staff_user_id || !library_id) {
      throw new Error('Missing fields')
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
      .select('library_ids')
      .eq('user_id', staff_user_id)
      .eq('role', 'staff')
      .single()

    if (!staffMember) throw new Error('Staff not found')

    const otherLibs = (staffMember.library_ids || [])
      .filter((id: string) => id !== library_id)

    if (otherLibs.length === 0) {
      const { error: deleteError } = await supabaseAdmin
        .auth.admin.deleteUser(staff_user_id)
      if (deleteError) throw deleteError
    } else {
      const { error: updateError } = await supabaseAdmin
        .from('staff')
        .update({ library_ids: otherLibs })
        .eq('user_id', staff_user_id)
      if (updateError) throw updateError
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    console.error('Delete staff error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
