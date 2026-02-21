"use client";

import { Twitter, Link2 } from "lucide-react";

interface ShareButtonsProps {
    articleId: string;
    title: string;
}

export function ShareButtons({ articleId, title }: ShareButtonsProps) {
    const articleUrl = `https://geardrop.com/article/${articleId}`;

    const handleCopyLink = () => {
        navigator.clipboard.writeText(articleUrl);
        alert('記事のリンクをコピーしました！');
    };

    return (
        <>
            <a
                href={`https://twitter.com/intent/tweet?text=${encodeURIComponent(title)}&url=${encodeURIComponent(articleUrl)}`}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-md bg-[#1DA1F2]/10 text-[#1DA1F2] hover:bg-[#1DA1F2]/20 transition-colors"
            >
                <Twitter className="w-4 h-4 fill-current" />
                Xでポスト
            </a>
            <button
                onClick={handleCopyLink}
                className="flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-md bg-secondary text-secondary-foreground hover:bg-secondary/80 transition-colors"
                autoFocus={false}
            >
                <Link2 className="w-4 h-4" />
                リンクをコピー
            </button>
        </>
    );
}
