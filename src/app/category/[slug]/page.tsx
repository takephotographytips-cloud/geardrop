import { createClient } from '@/utils/supabase/server';
import { ArticleCard } from '@/components/ui/ArticleCard';
import { Article } from '@/types';
import Link from 'next/link';
import { ArrowLeft } from 'lucide-react';

// Maps category slugs to Japanese display names
const CATEGORY_NAMES: Record<string, string> = {
    'news': '最新ニュース',
    'rumors': '噂・リーク',
    'lens': 'レンズ',
    'body': 'カメラボディ',
    'tips': 'チュートリアル'
};

export default async function CategoryPage(props: { params: Promise<{ slug: string }> }) {
    const params = await props.params;
    const { slug } = params;
    const categoryName = CATEGORY_NAMES[slug] || slug;

    // Fetch articles for this category
    const supabase = await createClient();
    const { data: articles, error } = await supabase
        .from('articles')
        .select('*')
        .eq('category', slug)
        .order('published_at', { ascending: false });

    return (
        <div className="container mx-auto px-4 py-8 lg:py-12 max-w-7xl animate-in fade-in duration-500">
            {/* Header section */}
            <div className="mb-8 flex flex-col gap-4">
                <Link href="/" className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors group w-fit">
                    <ArrowLeft className="w-4 h-4 group-hover:-translate-x-1 transition-transform" />
                    トップページに戻る
                </Link>

                <div>
                    <h1 className="text-3xl font-extrabold tracking-tight">
                        {categoryName}
                    </h1>
                    <p className="text-muted-foreground mt-2">
                        「{categoryName}」に関する最新記事一覧
                    </p>
                </div>
            </div>

            {/* Articles Grid */}
            {error ? (
                <div className="p-8 text-center bg-destructive/10 text-destructive rounded-xl">
                    記事の読み込みに失敗しました。
                </div>
            ) : !articles || articles.length === 0 ? (
                <div className="p-24 text-center border border-border/50 border-dashed rounded-2xl">
                    <p className="text-muted-foreground">このカテゴリーにはまだ記事がありません。</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {articles.map((article: Article) => (
                        <ArticleCard key={article.id} article={article} />
                    ))}
                </div>
            )}
        </div>
    );
}
