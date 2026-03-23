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
    const { name, email, password, library_id } = await req.json()

    if (!name || !email || !password || !library_id) {
      throw new Error('Missing fields')
    }

    if (password.length < 8) {
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

    const { count } = await supabaseAdmin
      .from('staff')
      .select('id', { count: 'exact', head: true })
      .eq('role', 'staff')
      .contains('library_ids', [library_id])

    if ((count ?? 0) >= 2) {
      throw new Error('Maximum 2 staff allowed')
    }

    const { data: newUser, error: createError } = await supabaseAdmin
      .auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { name, role: 'staff' }
      })

    if (createError) throw createError

    const { error: insertError } = await supabaseAdmin
      .from('staff')
      .insert({
        user_id: newUser.user.id,
        name,
        email,
        role: 'staff',
        staff_type: 'specific',
        library_ids: [library_id],
        is_active: true,
        force_password_change: false,
      })

    if (insertError) throw insertError

    return new Response(
      JSON.stringify({
        success: true,
        staff: {
          user_id: newUser.user.id,
          name,
          email,
          role: 'staff',
          library_ids: [library_id],
          is_active: true,
        }
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    console.error('Add staff error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
