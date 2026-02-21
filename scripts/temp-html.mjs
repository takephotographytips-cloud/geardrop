import Parser from 'rss-parser';
const parser = new Parser();
async function test() {
    const feed = await parser.parseURL('https://www.sonyalpharumors.com/feed/');
    const item = feed.items.find(i => i.title.includes('7Artisans'));
    console.log('--- Content starts ---');
    console.log(item?.content || item?.contentSnippet || 'No content found');
    console.log('--- Content ends ---');
}
test();
