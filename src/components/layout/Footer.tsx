import Link from "next/link";
import { Camera } from "lucide-react";

export function Footer() {
    return (
        <footer className="border-t border-border/50 bg-background py-12">
            <div className="container mx-auto px-4 flex flex-col md:flex-row justify-between items-center gap-6">
                <div className="flex items-center gap-2 opacity-80 cursor-default">
                    {/* The Camera icon was removed in the instruction's code edit. */}
                    <span className="font-semibold text-muted-foreground">GearDrop</span>
                </div>

                <div className="flex flex-wrap justify-center gap-x-6 gap-y-2 text-sm text-muted-foreground">
                    <Link href="/about" className="hover:text-foreground transition-colors">About</Link>
                    <Link href="/contact" className="hover:text-foreground transition-colors">Contact</Link>
                    <Link href="/privacy" className="hover:text-foreground transition-colors">Privacy Policy</Link>
                </div>

                {/* The original copyright paragraph was replaced by a new div structure in the instruction's code edit. */}
                <p className="text-sm text-muted-foreground/60">
                    © {new Date().getFullYear()} GearDrop. All rights reserved.
                </p>
            </div>
        </footer>
    );
}
