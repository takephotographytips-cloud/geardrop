import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ExternalLink, ArrowLeft, Clock } from "lucide-react";
import { formatDistanceToNow } from "date-fns";
import { ja } from "date-fns/locale";
import { Article } from "@/types";
import { BookmarkButton } from "@/components/ui/BookmarkButton";
import { createClient } from '@/utils/supabase/server';



export default async function ArticlePage({ params }: { params: Promise<{ id: string }> }) {
    const { id } = await params;
    const supabase = await createClient();

    // Fetch article from Supabase
    const { data: article } = await supabase
        .from('articles')
        .select('*')
        .eq('id', id)
        .single();

    if (!article) return notFound();

    const timeAgo = formatDistanceToNow(new Date(article.published_at), { addSuffix: true, locale: ja });

    // Check auth
    const { data: { user } } = await supabase.auth.getUser();

    let isBookmarked = false;
    if (user) {
        const { data } = await supabase
            .from('bookmarks')
            .select('id')
            .eq('user_id', user.id)
            .eq('article_id', article.id)
            .single();
        isBookmarked = !!data;
    }

    return (
        <div className="container mx-auto px-4 py-8 lg:py-12 max-w-5xl">
            {/* Back button */}
            <div className="mb-6">
                <Link href="/" className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors group">
                    <ArrowLeft className="w-4 h-4 group-hover:-translate-x-1 transition-transform" />
                    一覧に戻る
                </Link>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-[1fr_400px] gap-8 bg-card rounded-2xl border border-border/50 overflow-hidden shadow-lg">

                {/* Left column: Content */}
                <div className="p-8 flex flex-col">
                    <div className="flex gap-2 mb-4">
                        <span className="px-3 py-1 text-xs font-semibold bg-secondary text-secondary-foreground rounded-md">
                            {article.category}
                        </span>
                        {article.manufacturer && (
                            <span className="px-3 py-1 text-xs font-semibold bg-primary/20 text-primary-foreground rounded-md">
                                {article.manufacturer}
                            </span>
                        )}
                    </div>

                    <h1 className="text-2xl md:text-3xl font-extrabold tracking-tight leading-snug mb-4">
                        {article.title}
                    </h1>

                    <div className="flex items-center gap-4 text-sm text-muted-foreground mb-8 border-b border-border/50 pb-6">
                        <span className="flex items-center gap-1.5 px-3 py-1 rounded-full bg-secondary">
                            <span className="w-2 h-2 rounded-full bg-primary animate-pulse"></span>
                            {article.source_name}
                        </span>
                        <span className="flex items-center gap-1.5">
                            <Clock className="w-4 h-4" />
                            {timeAgo}
                        </span>
                    </div>

                    {/* Essential Info Only (No scroll needed) */}
                    <div className="flex-1 space-y-6">
                        <p className="text-base md:text-lg leading-relaxed text-foreground/90 font-medium">
                            {article.summary_text}
                        </p>

                        <div className="bg-secondary/50 rounded-xl p-5 border border-border/50">
                            <h3 className="text-sm font-bold tracking-wider text-muted-foreground mb-3 flex items-center gap-2">
                                <span className="w-1.5 h-4 bg-primary rounded-full"></span>
                                POINT SUMMARY
                            </h3>
                            <ul className="space-y-3">
                                {article.bullet_points && article.bullet_points.map((point: string, idx: number) => (
                                    <li key={idx} className="flex items-start gap-3">
                                        <span className="flex-shrink-0 w-6 h-6 rounded-full bg-primary/20 text-primary flex items-center justify-center text-xs font-bold mt-0.5">
                                            {idx + 1}
                                        </span>
                                        <span className="text-sm md:text-base leading-snug text-foreground text-balance">
                                            {point}
                                        </span>
                                    </li>
                                ))}
                            </ul>
                        </div>
                    </div>

                    {/* Actions */}
                    <div className="flex flex-col sm:flex-row gap-3 mt-8 pt-6 border-t border-border/50">
                        <a
                            href={article.source_url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="flex-1 flex items-center justify-center gap-2 bg-primary text-primary-foreground hover:bg-primary/90 font-semibold py-3.5 px-6 rounded-xl transition-all hover:scale-[1.02] shadow-sm hover:shadow-primary/25"
                        >
                            詳細を元記事で読む
                            <ExternalLink className="w-4 h-4" />
                        </a>
                        <BookmarkButton
                            articleId={article.id}
                            initialBookmarked={isBookmarked}
                            isLoggedIn={!!user}
                            variant="button"
                            className="flex-1"
                        />
                    </div>
                </div>

                {/* Right column: Image */}
                <div className="hidden md:block relative bg-muted border-l border-border/50">
                    {article.thumbnail_url ? (
                        <Image
                            src={article.thumbnail_url}
                            alt={article.title}
                            fill
                            className="object-cover"
                            priority
                        />
                    ) : (
                        <div className="absolute inset-0 flex items-center justify-center p-8 text-center text-muted-foreground bg-secondary/20">
                            No Image Available
                        </div>
                    )}
                    {/* subtle gradient overlay to blend with dark mode */}
                    <div className="absolute inset-0 bg-gradient-to-r from-card to-transparent w-24"></div>
                </div>

            </div>
        </div>
    );
}
