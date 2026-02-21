'use client';

import { useState, useEffect } from 'react';
import { Search, X, Loader2 } from 'lucide-react';
import Link from 'next/link';
import { formatDistanceToNow } from 'date-fns';
import { ja } from 'date-fns/locale';
import { Article } from '@/types';
import { createClient } from '@/utils/supabase/client';
// Image import is removed as thumbnails are no longer displayed in search results

const CATEGORY_NAMES: Record<string, string> = {
    'news': '最新ニュース',
    'rumors': '噂・リーク',
    'lens': 'レンズ',
    'body': 'カメラボディ',
    'tips': 'チュートリアル'
};

interface SearchResult {
    id: string;
    title: string;
    category: string;
    published_at: string;
}

export function SearchModal() {
    const [isOpen, setIsOpen] = useState(false);
    const [searchQuery, setSearchQuery] = useState("");
    const [results, setResults] = useState<SearchResult[]>([]);
    const [isSearching, setIsSearching] = useState(false);
    const supabase = createClient();

    // Toggle modal on Cmd+K
    useEffect(() => {
        const handleKeyDown = (e: KeyboardEvent) => {
            if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
                e.preventDefault();
                setIsOpen(true);
            }
            if (e.key === 'Escape') {
                setIsOpen(false);
            }
        };

        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, []);

    // Reset search state when modal closes
    useEffect(() => {
        if (!isOpen) {
            setSearchQuery("");
            setResults([]);
            setIsSearching(false);
        }
    }, [isOpen]);

    // Handle real-time search with basic debounce
    useEffect(() => {
        if (!searchQuery.trim()) {
            setResults([]);
            return;
        }

        const fetchResults = async () => {
            setIsSearching(true);
            const { data } = await supabase
                .from('articles')
                .select('id, title, category, published_at')
                .or(`title.ilike.%${searchQuery}%,summary_text.ilike.%${searchQuery}%`)
                .order('published_at', { ascending: false })
                .limit(5);

            setResults(data || []);
            setIsSearching(false);
        };

        const timeoutId = setTimeout(fetchResults, 300);
        return () => clearTimeout(timeoutId);
    }, [searchQuery, supabase]);

    if (!isOpen) {
        return (
            <button
                onClick={() => setIsOpen(true)}
                aria-label="Search"
                className="text-muted-foreground hover:text-foreground transition-colors hidden sm:flex items-center gap-2 bg-secondary/50 px-3 py-1.5 rounded-lg border border-border/50 hover:border-border/80"
            >
                <Search className="w-4 h-4" />
                <span className="text-xs font-medium">Search</span>
                <kbd className="hidden md:inline-flex items-center gap-1 rounded bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground opacity-100"><span className="text-xs">⌘</span>K</kbd>
            </button>
        );
    }

    return (
        <div className="fixed inset-0 z-[100] flex items-start justify-center pt-16 sm:pt-24 px-4 bg-background/80 backdrop-blur-sm animate-in fade-in duration-200">
            {/* Overlay click to close */}
            <div className="absolute inset-0" onClick={() => setIsOpen(false)} />

            {/* Modal Content */}
            <div className="relative w-full max-w-2xl bg-card border border-border/50 rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[70vh] animate-in zoom-in-95 duration-200">
                {/* Search Header */}
                <div className="flex items-center px-4 py-3 border-b border-border/50">
                    <Search className="w-5 h-5 text-muted-foreground mr-3" />
                    <input
                        type="text"
                        placeholder="記事を検索..."
                        className="flex-1 bg-transparent border-none outline-none text-foreground placeholder:text-muted-foreground h-10"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                    />
                    <button
                        onClick={() => setIsOpen(false)}
                        className="p-1.5 rounded-md hover:bg-secondary text-muted-foreground transition-colors"
                    >
                        <X className="w-5 h-5" />
                    </button>
                </div>

                {/* Search Results */}
                <div className="flex-1 overflow-y-auto p-2">
                    {isSearching ? (
                        <div className="p-8 text-center text-muted-foreground flex flex-col items-center">
                            <Loader2 className="w-6 h-6 animate-spin mb-2" />
                            <p>検索中...</p>
                        </div>
                    ) : results.length > 0 ? (
                        <div className="space-y-1">
                            {results.map((result) => (
                                <Link
                                    key={result.id}
                                    href={`/article/${result.id}`}
                                    onClick={() => setIsOpen(false)}
                                    className="block p-3 hover:bg-secondary rounded-lg transition-colors group"
                                >
                                    <div className="flex items-center justify-between">
                                        <span className="font-medium group-hover:text-primary transition-colors line-clamp-1">{result.title}</span>
                                    </div>
                                    <span className="text-xs font-semibold px-2 py-0.5 bg-primary/20 text-primary rounded">
                                        {CATEGORY_NAMES[result.category] || result.category}
                                    </span>
                                </Link>
                            ))}
                        </div>
                    ) : searchQuery ? (
                        <div className="p-8 text-center text-muted-foreground">
                            <p>「{searchQuery}」に一致する記事は見つかりませんでした。</p>
                        </div>
                    ) : (
                        <div className="py-8 px-4 text-center">
                            <p className="text-sm text-muted-foreground">
                                最新のニュースやチュートリアルなどを検索できます。
                            </p>
                            <div className="flex flex-wrap justify-center gap-2 mt-4">
                                <span className="text-xs px-2 py-1 bg-secondary rounded-md cursor-pointer hover:bg-secondary/80" onClick={() => setSearchQuery('Sony')}>Sony</span>
                                <span className="text-xs px-2 py-1 bg-secondary rounded-md cursor-pointer hover:bg-secondary/80" onClick={() => setSearchQuery('Canon')}>Canon</span>
                                <span className="text-xs px-2 py-1 bg-secondary rounded-md cursor-pointer hover:bg-secondary/80" onClick={() => setSearchQuery('DaVinci')}>DaVinci Resolve</span>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}
