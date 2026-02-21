import Link from "next/link";
import { Camera, Bookmark, LogOut } from "lucide-react";
import { createClient } from "@/utils/supabase/server";
import { SearchModal } from "@/components/ui/SearchModal";

export async function Header() {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    return (
        <header className="sticky top-0 z-50 w-full border-b border-border/50 bg-background/80 backdrop-blur-md">
            <div className="container mx-auto px-4 h-16 flex items-center justify-between">
                <Link href="/" className="flex items-center gap-2 group">
                    <div className="bg-primary/10 p-2 rounded-lg group-hover:bg-primary/20 transition-colors">
                        <Camera className="w-5 h-5 text-primary" />
                    </div>
                    <span className="font-bold text-lg tracking-tight">GearDrop</span>
                </Link>


                <div className="flex items-center gap-4">
                    <SearchModal />

                    {user ? (
                        <>
                            <Link href="/bookmarks" aria-label="Bookmarks" className="text-muted-foreground hover:text-foreground transition-colors group relative">
                                <Bookmark className="w-5 h-5" />
                                <span className="sr-only">ブックマーク</span>
                            </Link>
                            <div className="flex items-center gap-3 border-l border-border/50 pl-4 ml-2">
                                <span className="text-xs text-muted-foreground hidden md:block max-w-[120px] truncate">
                                    {user.email}
                                </span>
                                <form action="/auth/signout" method="post">
                                    <button aria-label="Sign Out" className="text-muted-foreground hover:text-foreground transition-colors bg-secondary/50 p-1.5 rounded-full hover:bg-secondary">
                                        <LogOut className="w-4 h-4" />
                                    </button>
                                </form>
                            </div>
                        </>
                    ) : (
                        <div className="flex items-center gap-3 border-l border-border/50 pl-4 ml-2">
                            <Link href="/login" className="text-sm font-medium hover:text-primary transition-colors">
                                ログイン
                            </Link>
                            <Link href="/login" className="text-sm font-medium bg-primary text-primary-foreground px-4 py-2 rounded-lg hover:bg-primary/90 transition-colors shadow-sm hidden sm:block">
                                無料登録
                            </Link>
                        </div>
                    )}
                </div>
            </div>
        </header>
    );
}
