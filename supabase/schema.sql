-- 記事テーブル (Articles)
create table
  public.articles (
    id text not null, -- Supabase生成ではなく既存ID(1,2,3...等)も扱えるようにtextに変更
    title text not null,
    summary_text text not null, -- AIによる100字程度の概要
    bullet_points text[] not null default '{}', -- AIによる3つの箇条書き要点
    thumbnail_url text null,
    source_url text not null, -- 元記事へのリンク
    source_name text null, 
    category text not null, 
    manufacturer text null, 
    tags text[] null, 
    is_automated boolean not null default true, 
    published_at timestamp with time zone not null default now(),
    created_at timestamp with time zone not null default now(),
    updated_at timestamp with time zone not null default now(),
    constraint articles_pkey primary key (id)
  ) tablespace pg_default;

-- ブックマークテーブル (Bookmarks)
create table
  public.bookmarks (
    id uuid not null default gen_random_uuid (),
    user_id uuid not null references auth.users(id) on delete cascade,
    article_id text not null references public.articles(id) on delete cascade,
    created_at timestamp with time zone not null default now(),
    constraint bookmarks_pkey primary key (id),
    constraint unique_bookmark unique (user_id, article_id)
  ) tablespace pg_default;

-- Row Level Security (RLS) の有効化
alter table public.articles enable row level security;
alter table public.bookmarks enable row level security;

-- 記事は誰でも読める
create policy "Articles are viewable by everyone." on public.articles
  for select using (true);

-- ブックマークは本人のみ読み書き可能
create policy "Users can view their own bookmarks." on public.bookmarks
  for select using (auth.uid() = user_id);

create policy "Users can insert their own bookmarks." on public.bookmarks
  for insert with check (auth.uid() = user_id);

create policy "Users can delete their own bookmarks." on public.bookmarks
  for delete using (auth.uid() = user_id);

-- インデックス作成 (検索パフォーマンス向上)
create index articles_category_idx on public.articles (category);
create index articles_manufacturer_idx on public.articles (manufacturer);
create index articles_published_at_idx on public.articles (published_at desc);

-- RLS (Row Level Security) 設定 (今回は読み取り専用の公開アクセスを許可し、書き込みはService Roleキーのみとする想定)
alter table public.articles enable row level security;

create policy "Enable read access for all users" on public.articles
  as permissive
  for select
  to public
  using (true);
