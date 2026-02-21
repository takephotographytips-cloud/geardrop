import fetch from 'node-fetch';
import * as cheerio from 'cheerio';

async function test() {
    const res = await fetch('https://www.sonyalpharumors.com/first-image-of-the-new-7artisans-135mm-f-1-8-af-e-mount-lens/');
    const html = await res.text();
    const $ = cheerio.load(html);

    let firstImg = null;
    $('article img, .entry-content img, .post-content img, figure img').each((i, el) => {
        const src = $(el).attr('src');
        if (src && !src.includes('gravatar') && !src.includes('pixel') && !src.includes('addtoany') && !src.includes('logo')) {
            firstImg = src;
            return false;
        }
    });
    console.log('Result:', firstImg);
}
test();
