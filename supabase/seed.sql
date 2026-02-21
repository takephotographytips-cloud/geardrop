-- Disable RLS for seeding
ALTER TABLE public.articles DISABLE ROW LEVEL SECURITY;

INSERT INTO public.articles (id, title, summary_text, bullet_points, thumbnail_url, source_url, source_name, category, manufacturer)
VALUES 
('1', '【リーク】Sony Ooooo VIIIのスペックが一部判明!? 8K動画に対応か', '2024年秋に発表が噂されているSonyの次期フラッグシップモデルの一部スペックがリークされました。長年期待されていた機能が遂に搭載されるかもしれません。', ARRAY['新開発のグローバルシャッターセンサー搭載', '8K 60fpsの内部収録に対応', '新設計のAI AFシステムによる被写体認識の劇的な向上'], 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?q=80&w=2000&auto=format&fit=crop', 'https://example.com/sony-rumors', 'Sony Alpha Rumors', 'body', 'Sony'),
('2', 'Canon RF123-456mm F2.8 L IS USM 発表：脅威の解像力と軽量化を両立', 'Canonが新たな大口径ズームレンズを発表。プロの現場で求められる光学性能を維持しながら、従来モデルから約20%の軽量化を実現。', ARRAY['世界初の大口径超望遠ズーム', '前モデル比で約20%の軽量化', '手ブレ補正効果は最大8.0段分'], 'https://images.unsplash.com/photo-1516961642265-531546e84af2?q=80&w=2000&auto=format&fit=crop', 'https://example.com/canon-watch', 'Canon Watch', 'lens', 'Canon'),
('3', 'DaVinci Resolve 19 最新チュートリアル: 新搭載のAIカラーグレーディングツールを使いこなす', '最新アップデートで追加されたAI連携機能を使った、劇的に作業効率が上がるカラーグレーディング手法を解説します。', ARRAY['ColorSliceツールの基本操作', 'AIによる顔の自動トラッキングとスキントーン補正', '新しいフィルムルッククリエイターの実践'], 'https://images.unsplash.com/photo-1574717024653-61fd2cf4d44d?q=80&w=2000&auto=format&fit=crop', 'https://example.com/davinci-tips', 'CreatorNews Pickup', 'tips', NULL)
ON CONFLICT (id) DO NOTHING;

-- Re-enable RLS
ALTER TABLE public.articles ENABLE ROW LEVEL SECURITY;
