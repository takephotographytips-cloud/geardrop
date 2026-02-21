'use client';

import { useState, useTransition } from 'react';
import { Bookmark } from 'lucide-react';
import { toggleBookmark } from '@/app/actions/bookmark';
import { useRouter } from 'next/navigation';

interface BookmarkButtonProps {
    articleId: string;
    initialBookmarked: boolean;
    isLoggedIn: boolean;
    className?: string;
    variant?: 'icon' | 'button';
}

export function BookmarkButton({
    articleId,
    initialBookmarked,
    isLoggedIn,
    className = "",
    variant = 'icon'
}: BookmarkButtonProps) {
    const [isBookmarked, setIsBookmarked] = useState(initialBookmarked);
    const [isPending, startTransition] = useTransition();
    const router = useRouter();

    const handleToggle = () => {
        if (!isLoggedIn) {
            router.push('/login');
            return;
        }

        // Optimistic UI update
        setIsBookmarked(!isBookmarked);

        startTransition(async () => {
            const result = await toggleBookmark(articleId);
            if (result.error) {
                // Revert on error
                setIsBookmarked(isBookmarked);
                console.error("Failed to toggle bookmark:", result.error);
                alert("保存に失敗しました: " + result.error);
            }
        });
    };

    if (variant === 'button') {
        return (
            <button
                onClick={handleToggle}
                disabled={isPending}
                className={`flex items-center justify-center gap-2 font-semibold py-3.5 px-6 rounded-xl transition-all shadow-sm disabled:opacity-50 ${isBookmarked
                    ? 'bg-primary/20 text-primary border border-primary/30 hover:bg-primary/30'
                    : 'bg-secondary text-secondary-foreground hover:bg-secondary/80 border border-transparent'
                    } ${className}`}
            >
                <Bookmark className={`w-4 h-4 ${isBookmarked ? 'fill-current' : ''}`} />
                {isBookmarked ? '保存済み' : '保存する'}
            </button>
        );
    }

    return (
        <button
            onClick={handleToggle}
            disabled={isPending}
            title={isBookmarked ? "ブックマーク解除" : "ブックマーク"}
            className={`p-1.5 -ml-1.5 rounded-md transition-colors disabled:opacity-50 ${isBookmarked
                ? 'text-primary hover:text-primary/80 hover:bg-primary/10'
                : 'text-muted-foreground hover:text-foreground hover:bg-secondary'
                } ${className}`}
        >
            <Bookmark className={`w-4 h-4 ${isBookmarked ? 'fill-current' : ''}`} />
        </button>
    );
}
