import Jimp from 'jimp';

async function process() {
    console.log('Reading image...');
    const image = await Jimp.read('public/logo.png');

    // Create a new blank canvas? No, modifying the existing is fine.
    image.scan(0, 0, image.bitmap.width, image.bitmap.height, function (x, y, idx) {
        const r = this.bitmap.data[idx + 0];
        const g = this.bitmap.data[idx + 1];
        const b = this.bitmap.data[idx + 2];

        // white border (R>200, G>200, B>200) -> Transparent
        if (r > 200 && g > 200 && b > 200) {
            this.bitmap.data[idx + 3] = 0;
            return;
        }

        // dark navy background -> Transparent
        // We base the alpha purely on luminance to keep the glow smooth exactly as seen against black
        const lum = Math.max(r, g, b);

        // If it's very dark, alpha = 0
        if (lum < 25) {
            this.bitmap.data[idx + 3] = 0;
        } else if (lum < 80) {
            // Fade out the edge for a smooth antialiased glow
            // Lum 80 -> Alpha 255 (mostly opaque)
            // Lum 25 -> Alpha 0
            const newAlpha = Math.min(255, Math.floor(((lum - 25) / (80 - 25)) * 255));
            this.bitmap.data[idx + 3] = newAlpha;
        }
    });

    console.log('Autocropping...');
    image.autocrop();

    console.log('Writing transparent logo...');
    await image.writeAsync('public/logo-transparent.png');
    console.log('Success!');
}

process().catch(console.error);
