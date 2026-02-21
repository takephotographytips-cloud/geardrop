import { ArticleCard } from "@/components/ui/ArticleCard";
import { ArrowRight, Sparkles } from "lucide-react";
import Link from "next/link";
import { createClient } from "@/utils/supabase/server";
import { Article } from "@/types";

export default async function Home() {
  const supabase = await createClient();

  // Fetch latest articles
  const { data: latestArticles, error } = await supabase
    .from('articles')
    .select('*')
    .order('published_at', { ascending: false })
    .limit(6);
  return (
    <div className="container mx-auto px-4 py-12">
      <section className="mb-16">
        <div className="flex flex-col md:flex-row md:items-end justify-between mb-8 pb-4 border-b border-border/50">
          <div>
            <h1 className="text-3xl md:text-4xl font-extrabold tracking-tight mb-2">
              Latest Updates
            </h1>
            <p className="text-muted-foreground">
              写真・映像クリエイターのための最新ニュースとリーク情報
            </p>
          </div>

          <div className="flex gap-2 mt-4 md:mt-0 overflow-x-auto pb-2 md:pb-0 hide-scrollbar scroll-smooth">
            <Link href="/" className="whitespace-nowrap px-4 py-1.5 rounded-full bg-primary text-primary-foreground text-sm font-medium shadow-sm transition-all hover:scale-105">
              すべて
            </Link>
            <Link href="/category/news" className="whitespace-nowrap px-4 py-1.5 rounded-full bg-secondary text-secondary-foreground text-sm font-medium hover:bg-secondary/80 transition-all hover:scale-105">
              最新ニュース
            </Link>
            <Link href="/category/rumors" className="whitespace-nowrap px-4 py-1.5 rounded-full bg-secondary text-secondary-foreground text-sm font-medium hover:bg-secondary/80 transition-all hover:scale-105">
              噂・リーク
            </Link>
            <Link href="/category/lens" className="whitespace-nowrap px-4 py-1.5 rounded-full bg-secondary text-secondary-foreground text-sm font-medium hover:bg-secondary/80 transition-all hover:scale-105">
              レンズ
            </Link>
            <Link href="/category/body" className="whitespace-nowrap px-4 py-1.5 rounded-full bg-secondary text-secondary-foreground text-sm font-medium hover:bg-secondary/80 transition-all hover:scale-105">
              カメラボディ
            </Link>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {error ? (
            <div className="col-span-full p-8 text-center bg-destructive/10 text-destructive rounded-xl">
              記事の読み込みに失敗しました。
            </div>
          ) : !latestArticles || latestArticles.length === 0 ? (
            <div className="col-span-full p-12 text-center border border-border/50 border-dashed rounded-xl text-muted-foreground">
              まだ記事がありません。
            </div>
          ) : (
            latestArticles.map((article: Article) => (
              <ArticleCard key={article.id} article={article} />
            ))
          )}
        </div>
      </section>

      <section className="bg-secondary/30 rounded-2xl p-8 mb-16 border border-border/50 text-center">
        <h2 className="text-2xl font-bold mb-4">GearDrop 編集部ピックアップ</h2>
        <p className="text-muted-foreground mb-6 max-w-2xl mx-auto">
          映像制作や写真撮影において、特に役立つと感じた機材レビューやチュートリアル記事を厳選して紹介しています。
        </p>
        <button className="px-6 py-2.5 rounded-lg bg-background border border-border hover:border-primary/50 text-foreground font-medium transition-colors shadow-sm">
          ピックアップ記事一覧を見る
        </button>
      </section>
    </div>
  );
}
