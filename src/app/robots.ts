import { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
    const baseUrl = 'https://geardrop.com'; // Replace with actual domain later

    return {
        rules: {
            userAgent: '*',
            allow: '/',
            disallow: ['/api/'], // Disallow API endpoints from being crawled
        },
        sitemap: `${baseUrl}/sitemap.xml`,
    };
}
