import Jimp from 'jimp';

async function process() {
    console.log('Reading transparent logo...');
    const logo = await Jimp.read('public/logo-transparent.png');

    // Resize logo if it's too big, let's make it a nice size for a 1200x630 OGP image
    // say 400px height
    logo.resize(Jimp.AUTO, 400);

    console.log('Creating OGP canvas...');
    // 1200x630 is the standard sweet spot for Twitter/FB
    // Background color #0B1120 is the site's body background (hsl(222.2 47.4% 11.2% / 1))
    const canvas = new Jimp(1200, 630, '#0B1120');

    // Calculate center position
    const x = (canvas.bitmap.width / 2) - (logo.bitmap.width / 2);
    const y = (canvas.bitmap.height / 2) - (logo.bitmap.height / 2);

    console.log('Compositing logo onto canvas...');
    canvas.composite(logo, x, y);

    console.log('Writing opengraph-image.png and twitter-image.png...');
    await canvas.writeAsync('src/app/opengraph-image.png');
    await canvas.writeAsync('src/app/twitter-image.png');

    // Let's also do a square version for the icon just in case
    const squareCanvas = new Jimp(512, 512, '#0B1120');
    logo.resize(Jimp.AUTO, 300);
    const sx = (squareCanvas.bitmap.width / 2) - (logo.bitmap.width / 2);
    const sy = (squareCanvas.bitmap.height / 2) - (logo.bitmap.height / 2);
    squareCanvas.composite(logo, sx, sy);
    console.log('Writing icon.png...');
    await squareCanvas.writeAsync('src/app/icon.png');


    console.log('Success!');
}

process().catch(console.error);
