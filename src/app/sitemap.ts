import { MetadataRoute } from 'next';
import { createClient } from '@/utils/supabase/server';

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
    const supabase = await createClient();
    const baseUrl = 'https://geardrop.com'; // Replace with actual domain later

    // Fetch all articles
    const { data: articles } = await supabase
        .from('articles')
        .select('id, updated_at, published_at')
        .order('published_at', { ascending: false });

    const articleUrls = (articles || []).map((article) => ({
        url: `${baseUrl}/article/${article.id}`,
        lastModified: new Date(article.updated_at || article.published_at),
        changeFrequency: 'weekly' as const,
        priority: 0.8,
    }));

    return [
        {
            url: baseUrl,
            lastModified: new Date(),
            changeFrequency: 'hourly',
            priority: 1,
        },
        ...articleUrls,
    ];
}
