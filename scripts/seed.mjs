import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    console.error('Missing Supabase env vars');
    process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const MOCK_ARTICLES = [
    {
        id: "1",
        title: "【リーク】Sony Ooooo VIIIのスペックが一部判明!? 8K動画に対応か",
        summary_text: "2024年秋に発表が噂されているSonyの次期フラッグシップモデルの一部スペックがリークされました。長年期待されていた機能が遂に搭載されるかもしれません。",
        bullet_points: [
            "新開発のグローバルシャッターセンサー搭載",
            "8K 60fpsの内部収録に対応",
            "新設計のAI AFシステムによる被写体認識の劇的な向上"
        ],
        source_url: "https://example.com/sony-rumors",
        source_name: "Sony Alpha Rumors",
        category: "body",
        manufacturer: "Sony",
        thumbnail_url: "https://images.unsplash.com/photo-1516035069371-29a1b244cc32?q=80&w=2000&auto=format&fit=crop",
    },
    {
        id: "2",
        title: "Canon RF123-456mm F2.8 L IS USM 発表：脅威の解像力と軽量化を両立",
        summary_text: "Canonが新たな大口径ズームレンズを発表。プロの現場で求められる光学性能を維持しながら、従来モデルから約20%の軽量化を実現。",
        bullet_points: [
            "世界初の大口径超望遠ズーム",
            "前モデル比で約20%の軽量化",
            "手ブレ補正効果は最大8.0段分"
        ],
        source_url: "https://example.com/canon-watch",
        source_name: "Canon Watch",
        category: "lens",
        manufacturer: "Canon",
        thumbnail_url: "https://images.unsplash.com/photo-1516961642265-531546e84af2?q=80&w=2000&auto=format&fit=crop",
    },
    {
        id: "3",
        title: "DaVinci Resolve 19 最新チュートリアル: 新搭載のAIカラーグレーディングツールを使いこなす",
        summary_text: "最新アップデートで追加されたAI連携機能を使った、劇的に作業効率が上がるカラーグレーディング手法を解説します。",
        bullet_points: [
            "ColorSliceツールの基本操作",
            "AIによる顔の自動トラッキングとスキントーン補正",
            "新しいフィルムルッククリエイターの実践"
        ],
        source_url: "https://example.com/davinci-tips",
        source_name: "CreatorNews Pickup",
        category: "tips",
        thumbnail_url: "https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?q=80&w=2000&auto=format&fit=crop",
    }
];

async function seed() {
    console.log('Seeding articles...');
    for (const article of MOCK_ARTICLES) {
        const { error } = await supabase.from('articles').upsert(article);
        if (error) {
            console.error('Failed to insert article:', article.id, error);
        } else {
            console.log('Inserted article:', article.id);
        }
    }
    console.log('Done.');
}

seed();
