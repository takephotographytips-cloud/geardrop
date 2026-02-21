import Parser from 'rss-parser';
import { GoogleGenAI, Type } from '@google/genai';
import { createClient } from '@supabase/supabase-js';
import * as cheerio from 'cheerio';
import fetch from 'node-fetch';

// Configuration
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY; // Using anon key for demo, normally use service_role
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY || !GEMINI_API_KEY) {
    console.error('Missing required environment variables');
    process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY });
const parser = new Parser();

// RSS Feeds to monitor (Example sites: Sony Alpha Rumors, Canon Rumors, etc.)
// For this demo we'll use a sample RSS feed
const FEEDS = [
    { url: 'https://www.sonyalpharumors.com/feed/', name: 'Sony Alpha Rumors', category: 'rumors', manufacturer: 'Sony' },
    { url: 'https://www.fujirumors.com/feed/', name: 'Fuji Rumors', category: 'rumors', manufacturer: 'Fujifilm' },
    { url: 'https://canonrumors.com/feed/', name: 'Canon Rumors', category: 'rumors', manufacturer: 'Canon' },
    { url: 'https://nikonrumors.com/feed/', name: 'Nikon Rumors', category: 'rumors', manufacturer: 'Nikon' },
    { url: 'https://www.diyphotography.net/category/tutorials/feed/', name: 'DIY Photography Tutorials', category: 'tips', manufacturer: null },
    { url: 'https://www.diyphotography.net/category/news/feed/', name: 'DIY Photography News', category: 'news', manufacturer: null },
];

async function generateSummary(title, content) {
    const requestPrompt = `
あなたはプロの写真・映像クリエイター向けの情報サイトの優秀な編集者です。
以下のニュース記事（タイトルと内容の一部）を読み、日本のクリエイター向けに分かりやすく要約してください。

【ルール】
1. summary_text は、記事の概要を**3行程度（150文字前後）**の日本語で魅力的にまとめてください。
2. bullet_points は、記事の特に重要なポイントを**3つの箇条書き（各30文字以内）**で抽出してください。

【記事情報】
タイトル: ${title}
本文抽出: ${content ? content.substring(0, 500) : 'なし'}...
`;

    try {
        const response = await ai.models.generateContent({
            model: 'gemini-2.5-flash',
            contents: requestPrompt,
            config: {
                // Ensure structured JSON output
                responseMimeType: "application/json",
                responseSchema: {
                    type: Type.OBJECT,
                    properties: {
                        summary_text: {
                            type: Type.STRING,
                            description: "A 3-line Japanese summary of the article."
                        },
                        bullet_points: {
                            type: Type.ARRAY,
                            items: {
                                type: Type.STRING
                            },
                            description: "Exactly 3 bullet points summarizing the key takeaways in Japanese."
                        }
                    },
                    required: ["summary_text", "bullet_points"],
                }
            }
        });

        const resultJson = JSON.parse(response.text);
        return {
            summary_text: resultJson.summary_text,
            bullet_points: resultJson.bullet_points
        };
    } catch (error) {
        console.error("AI Generation failed:", error);
        return null;
    }
}

async function fetchThumbnailUrl(url, contentHtml = '') {
    // 1. First priority: Parse the RSS contentHtml using cheerio to reliably find the first true image
    if (contentHtml) {
        // Try regex first in case HTML tags are stripped but raw URLs remain in the snippet
        const rawUrlMatch = contentHtml.match(/https?:\/\/[^\s"'<>]+?\.(?:jpg|jpeg|png|webp)/i);
        if (rawUrlMatch && !rawUrlMatch[0].includes('gravatar') && !rawUrlMatch[0].includes('pixel') && !rawUrlMatch[0].includes('addtoany') && !rawUrlMatch[0].includes('share_save')) {
            return rawUrlMatch[0];
        }

        const $content = cheerio.load(contentHtml);
        let firstImg = null;

        $content('img').each((i, el) => {
            // Sites like SAR use data-src for the real image, and put a placeholder in src.
            let src = $content(el).attr('data-src') || $content(el).attr('data-lazy-src') || $content(el).attr('src');
            // Skip common tracking pixels, social share icons, and author avatars
            if (src && !src.includes('gravatar') && !src.includes('pixel') && !src.includes('addtoany') && !src.includes('share_save') && !src.includes('data:image')) {
                firstImg = src;
                return false; // break loop
            }
        });

        if (firstImg) return firstImg;
    }

    // 2. Second priority: Fetch the page HTML and look for meta tags
    try {
        const response = await fetch(url, {
            headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36' }
        });
        const html = await response.text();
        const $ = cheerio.load(html);

        // Try to get Open Graph image
        let imgUrl = $('meta[property="og:image"]').attr('content');

        // Check if the og:image is a known generic fallback (e.g. CP+ event placeholder, addtoany buttons)
        if (imgUrl && (imgUrl.includes('share_save') || imgUrl.includes('CP-plus') || imgUrl.includes('addtoany'))) {
            imgUrl = null;
        }

        // 3. Third priority: Look for the first image INSIDE the actual article content
        // This avoids picking up sidebar, header, or author profile images.
        if (!imgUrl) {
            $('article img, .entry-content img, .post-content img, figure img').each((i, el) => {
                let src = $(el).attr('data-src') || $(el).attr('data-lazy-src') || $(el).attr('src');
                if (src && !src.includes('gravatar') && !src.includes('addtoany') && !src.includes('pixel') && !src.includes('logo') && !src.includes('data:image')) {
                    imgUrl = src;
                    return false; // break out of loop once we find a good image
                }
            });

            if (imgUrl && imgUrl.startsWith('/')) {
                try {
                    const urlObj = new URL(url);
                    imgUrl = `${urlObj.origin}${imgUrl}`;
                } catch (e) { }
            }
        }

        // Fallback to twitter image
        if (!imgUrl) {
            imgUrl = $('meta[name="twitter:image"]').attr('content');
        }

        return imgUrl || null;
    } catch (error) {
        console.log(`Failed to fetch thumbnail for ${url}:`, error.message);
        return null;
    }
}

async function run() {
    console.log("Starting automated news fetch...");

    for (const feedConfig of FEEDS) {
        console.log(`Fetching feed: ${feedConfig.name}`);
        try {
            const feed = await parser.parseURL(feedConfig.url);

            // Only process the 3 most recent items to avoid API limits during demo
            const recentItems = feed.items.slice(0, 3);

            for (const item of recentItems) {
                // Check if we already processed this article
                const { data: existing } = await supabase
                    .from('articles')
                    .select('id')
                    .eq('source_url', item.link)
                    .single();

                if (existing) {
                    console.log(`Skipping existing article: ${item.title}`);
                    continue;
                }

                console.log(`Processing new article: ${item.title}`);

                // Get AI summary
                const aiResult = await generateSummary(item.title, item.content || item.contentSnippet);

                if (!aiResult) {
                    console.log("Skipping due to AI failure.");
                    continue;
                }

                // Try to fetch actual thumbnail from the source article (passing content for priority extraction)
                const realThumbnailUrl = await fetchThumbnailUrl(item.link, item.content || item.contentSnippet || '');

                // Prepare database payload
                // Generate a unique ID (normally uuid, using timestamp for simplicity in this demo script)
                const articleData = {
                    id: `auto-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
                    title: item.title,
                    summary_text: aiResult.summary_text,
                    bullet_points: aiResult.bullet_points,
                    thumbnail_url: realThumbnailUrl || 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?q=80&w=800&auto=format&fit=crop', // Fallback image
                    source_url: item.link,
                    source_name: feedConfig.name,
                    category: feedConfig.category,
                    manufacturer: feedConfig.manufacturer,
                    is_automated: true,
                    published_at: item.isoDate ? new Date(item.isoDate) : new Date()
                };

                // Insert into Supabase
                const { error } = await supabase
                    .from('articles')
                    .insert(articleData);

                if (error) {
                    console.error("Failed to save to database:", error);
                } else {
                    console.log(`Successfully saved: ${item.title}`);
                }

                // Add a small delay so we don't hit Gemini rate limits
                await new Promise(resolve => setTimeout(resolve, 2000));
            }
        } catch (err) {
            console.error(`Failed reading feed ${feedConfig.url}: `, err);
        }
    }

    console.log("Automated news fetch completed.");
}

run();
