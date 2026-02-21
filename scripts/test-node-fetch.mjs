import fetch from 'node-fetch';
import * as cheerio from 'cheerio';
async function test() {
    const res = await fetch('https://www.sonyalpharumors.com/first-image-of-the-new-7artisans-135mm-f-1-8-af-e-mount-lens/', {
        headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36' }
    });
    const html = await res.text();
    const $ = cheerio.load(html);

    let firstImg = null;
    $('article img, .entry-content img, .post-content img, figure img').each((i, el) => {
        let src = $(el).attr('data-src') || $(el).attr('data-lazy-src') || $(el).attr('src');
        if (src && !src.includes('gravatar') && !src.includes('addtoany') && !src.includes('pixel') && !src.includes('logo')) {
            console.log('Valid SRC found:', src);
            firstImg = src;
            return false;
        }
    });
    console.log('Final Result:', firstImg);
}
test();
