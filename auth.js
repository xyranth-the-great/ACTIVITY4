import { supabase } from "./supabaseClient.js";

/**
 * Returns { session, profile } for the current signed-in user, or null
 * if nobody is signed in. profile includes the app role (admin/staff/requester)
 * read from the `profiles` table, which is the source of truth used by
 * every RLS policy and RPC function on the database side too.
 */
export async function getCurrentUser() {
  const { data: { session }, error } = await supabase.auth.getSession();
  if (error || !session) return null;

  const { data: profile, error: profErr } = await supabase
    .from("profiles")
    .select("id, full_name, email, role, created_at")
    .eq("id", session.user.id)
    .single();

  if (profErr || !profile) return null;
  return { session, profile };
}

/**
 * Call at the top of every protected page. Redirects to the login page
 * if there is no session, and — if allowedRoles is given — redirects
 * to dashboard.html if the signed-in user's role isn't permitted.
 * This is the *interface-level* half of authorization; the matching
 * database-level checks live in the RLS policies and RPC functions.
 */
export async function requireAuth(allowedRoles = null) {
  const user = await getCurrentUser();
  if (!user) {
    window.location.href = "index.html";
    return null;
  }
  if (allowedRoles && !allowedRoles.includes(user.profile.role)) {
    window.location.href = "dashboard.html?denied=1";
    return null;
  }
  return user;
}

export async function logout() {
  await supabase.auth.signOut();
  window.location.href = "index.html";
}
