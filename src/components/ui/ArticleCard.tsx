import Image from "next/image";
import Link from "next/link";
import { formatDistanceToNow } from "date-fns";
import { ja } from "date-fns/locale";
import { ExternalLink } from "lucide-react";
import { Article } from "@/types";
import { BookmarkButton } from "./BookmarkButton";
import { createClient } from '@/utils/supabase/server';

interface ArticleCardProps {
    article: Article;
}

export async function ArticleCard({ article }: ArticleCardProps) {
    const timeAgo = formatDistanceToNow(new Date(article.published_at), { addSuffix: true, locale: ja });

    // Check auth and bookmark status
    const supabase = await createClient();
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
        <article className="group flex flex-col bg-card rounded-xl overflow-hidden border border-border/50 hover:border-primary/50 transition-all duration-300 shadow-sm hover:shadow-md">
            <Link href={`/article/${article.id}`} className="relative h-48 w-full overflow-hidden bg-muted block">
                {article.thumbnail_url ? (
                    <Image
                        src={article.thumbnail_url}
                        alt={article.title}
                        fill
                        className="object-cover group-hover:scale-105 transition-transform duration-500"
                    />
                ) : (
                    <div className="absolute inset-0 flex items-center justify-center text-muted-foreground/50 font-medium">
                        No Image
                    </div>
                )}
                <div className="absolute top-3 left-3 flex gap-2">
                    <span className="px-2.5 py-1 text-xs font-semibold bg-background/90 text-foreground backdrop-blur-sm rounded-md shadow-sm">
                        {article.category}
                    </span>
                    {article.manufacturer && (
                        <span className="px-2.5 py-1 text-xs font-semibold bg-primary/90 text-primary-foreground backdrop-blur-sm rounded-md shadow-sm">
                            {article.manufacturer}
                        </span>
                    )}
                </div>
            </Link>

            <div className="flex flex-col flex-1 p-5">
                <div className="flex items-center justify-between mb-3">
                    <span className="text-xs text-muted-foreground font-medium flex items-center gap-1.5">
                        <span className="w-1.5 h-1.5 rounded-full bg-primary/60"></span>
                        {article.source_name}
                    </span>
                    <span className="text-xs text-muted-foreground">{timeAgo}</span>
                </div>

                <Link href={`/article/${article.id}`} className="block group-hover:text-primary transition-colors">
                    <h3 className="text-base font-bold leading-snug line-clamp-2 mb-2">
                        {article.title}
                    </h3>
                    <p className="text-sm text-muted-foreground line-clamp-2 mb-3">
                        {article.summary_text}
                    </p>
                </Link>

                {/* Bullets Summary */}
                <ul className="mb-4 space-y-1">
                    {article.bullet_points.slice(0, 2).map((point, idx) => (
                        <li key={idx} className="flex items-start gap-2 text-xs text-muted-foreground/90">
                            <span className="text-primary mt-1 min-w-[4px] min-h-[4px] rounded-full bg-primary block"></span>
                            <span className="line-clamp-1">{point}</span>
                        </li>
                    ))}
                </ul>

                <div className="mt-auto pt-4 border-t border-border/50 flex items-center justify-between">
                    <BookmarkButton
                        articleId={article.id}
                        initialBookmarked={isBookmarked}
                        isLoggedIn={!!user}
                    />
                    <a
                        href={article.source_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground hover:text-foreground transition-colors p-1.5 -mr-1.5 rounded-md hover:bg-secondary"
                    >
                        元記事を読む
                        <ExternalLink className="w-3.5 h-3.5" />
                    </a>
                </div>
            </div>
        </article>
    );
}
