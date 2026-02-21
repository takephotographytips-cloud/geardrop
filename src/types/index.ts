// This is a placeholder type until we hook up Supabase
export interface Article {
    id: string;
    title: string;
    summary_text: string;
    bullet_points: string[];
    thumbnail_url?: string;
    source_url: string;
    source_name: string;
    category: string;
    manufacturer?: string;
    published_at: string;
}
