'use server'

import { createClient } from '@/utils/supabase/server'
import { revalidatePath } from 'next/cache'

export async function toggleBookmark(articleId: string) {
    const supabase = await createClient()

    const {
        data: { user },
    } = await supabase.auth.getUser()

    if (!user) {
        return { error: 'Not authenticated', success: false }
    }

    // Check if already bookmarked
    const { data: existing } = await supabase
        .from('bookmarks')
        .select('id')
        .eq('user_id', user.id)
        .eq('article_id', articleId)
        .single()

    if (existing) {
        // Remove bookmark
        const { error } = await supabase
            .from('bookmarks')
            .delete()
            .eq('id', existing.id)

        if (error) return { error: error.message, success: false }
    } else {
        // Add bookmark
        const { error } = await supabase
            .from('bookmarks')
            .insert({ user_id: user.id, article_id: articleId })

        if (error) return { error: error.message, success: false }
    }

    revalidatePath('/')
    revalidatePath(`/article/${articleId}`)
    revalidatePath('/bookmarks')

    return { success: true, isBookmarked: !existing }
}

export async function checkIsBookmarked(articleId: string) {
    const supabase = await createClient()

    const {
        data: { user },
    } = await supabase.auth.getUser()

    if (!user) return false

    const { data } = await supabase
        .from('bookmarks')
        .select('id')
        .eq('user_id', user.id)
        .eq('article_id', articleId)
        .single()

    return !!data
}
