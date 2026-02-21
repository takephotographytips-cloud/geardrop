import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Header } from "@/components/layout/Header";
import { Footer } from "@/components/layout/Footer";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  metadataBase: new URL('https://geardrop.com'), // Adjust to actual prod domain later
  title: {
    template: "%s | GearDrop",
    default: "GearDrop | クリエイター向け最新機材ニュース＆リーク情報",
  },
  description: "世界のカメラニュースを、毎朝3分で。海外メディアの最新機材情報やリークをAIが瞬時に要約。忙しい写真・映像クリエイターのためのノイズレスな情報収集プラットフォーム。",
  openGraph: {
    type: "website",
    locale: "ja_JP",
    url: "https://geardrop.com",
    title: "GearDrop | 最新カメラ技術で未来を写す",
    description: "世界のカメラニュースを、毎朝3分で。海外メディアの最新機材情報やリークをAIが瞬時に要約。",
    siteName: "GearDrop",
  },
  twitter: {
    card: "summary_large_image",
    title: "GearDrop | 最新カメラ技術で未来を写す",
    description: "世界のカメラニュースを、毎朝3分で。海外メディアの最新機材情報やリークをAIが瞬時に要約。",
  }
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja" className="dark">
      <body className={`${inter.className} min-h-screen flex flex-col antialiased`}>
        <Header />
        <main className="flex-1">
          {children}
        </main>
        <Footer />
      </body>
    </html>
  );
}
