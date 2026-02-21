import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'images.unsplash.com',
      },
      {
        protocol: 'https',
        hostname: 'static.addtoany.com',
      },
      {
        protocol: 'https',
        hostname: 'www.sonyalpharumors.com',
      },
      {
        protocol: 'https',
        hostname: 'www.fujirumors.com',
      },
      {
        protocol: 'https',
        hostname: 'www.canonrumors.com',
      },
      {
        protocol: 'https',
        hostname: 'canonrumors.com',
      },
      {
        protocol: 'https',
        hostname: 'nikonrumors.com',
      },
      {
        protocol: 'https',
        hostname: 'www.diyphotography.net',
      },
      {
        protocol: 'https',
        hostname: '**.placeholder.com',
      },
    ],
  },
};

export default nextConfig;

