import { createClient } from '@/utils/supabase/server';
import { redirect } from 'next/navigation';
import { ArticleCard } from '@/components/ui/ArticleCard';
import { ArrowLeft, Bookmark } from 'lucide-react';
import Link from 'next/link';



export default async function BookmarksPage() {
    const supabase = await createClient();

    const { data: { user } } = await supabase.auth.getUser();

    if (!user) {
        redirect('/login');
    }

    // Fetch bookmarks
    const { data: bookmarks } = await supabase
        .from('bookmarks')
        .select('article_id')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false });

    const bookmarkedArticleIds = bookmarks?.map(b => b.article_id) || [];

    // Fetch the actual articles related to the bookmarks
    let articles: any[] = [];
    if (bookmarkedArticleIds.length > 0) {
        const { data: fetchedArticles } = await supabase
            .from('articles')
            .select('*')
            .in('id', bookmarkedArticleIds)
            .order('published_at', { ascending: false });

        articles = fetchedArticles || [];
    }

    return (
        <div className="container mx-auto px-4 py-8 max-w-7xl">
            <div className="flex items-center gap-4 mb-8">
                <Link href="/" className="p-2 -ml-2 text-muted-foreground hover:text-foreground transition-colors hover:bg-secondary rounded-lg">
                    <ArrowLeft className="w-5 h-5" />
                </Link>
                <div>
                    <h1 className="text-2xl font-bold flex items-center gap-2">
                        <Bookmark className="w-5 h-5 fill-primary text-primary" />
                        保存した記事
                    </h1>
                    <p className="text-sm text-muted-foreground mt-1">クラウドに保存したお気に入りの記事一覧</p>
                </div>
            </div>

            {articles.length > 0 ? (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {articles.map((article) => (
                        <ArticleCard key={article.id} article={article} />
                    ))}
                </div>
            ) : (
                <div className="bg-card border border-border/50 rounded-2xl p-12 text-center shadow-sm">
                    <div className="w-16 h-16 bg-muted rounded-full flex items-center justify-center mx-auto mb-4">
                        <Bookmark className="w-6 h-6 text-muted-foreground" />
                    </div>
                    <h2 className="text-xl font-bold mb-2">まだ保存された記事はありません</h2>
                    <p className="text-muted-foreground mb-6">
                        気になった記事のブックマークアイコンをクリックすると、ここに保存されていつでも読み返すことができます。
                    </p>
                    <Link href="/" className="inline-flex px-6 py-2.5 bg-primary text-primary-foreground font-medium rounded-lg hover:bg-primary/90 transition-colors shadow-sm">
                        新着記事を見に行く
                    </Link>
                </div>
            )}
        </div>
    );
}
