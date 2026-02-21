import { login, signup } from './actions'

export default async function LoginPage({
    searchParams,
}: {
    searchParams: Promise<{ message: string }>
}) {
    const { message } = await searchParams;

    return (
        <div className="flex-1 flex flex-col w-full px-8 sm:max-w-md justify-center gap-2 mx-auto h-[calc(100vh-140px)]">
            <div className="bg-card border border-border/50 rounded-2xl p-8 shadow-lg">
                <h1 className="text-2xl font-bold mb-6 text-center">GearDrop ログイン</h1>

                <form className="animate-in flex-1 flex flex-col w-full justify-center gap-2 text-foreground">
                    <label className="text-sm text-muted-foreground font-medium mb-1" htmlFor="email">
                        メールアドレス
                    </label>
                    <input
                        className="rounded-lg px-4 py-2 bg-background border border-border/50 mb-4 text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-transparent transition-all"
                        name="email"
                        placeholder="you@example.com"
                        required
                        autoComplete="email"
                    />
                    <label className="text-sm text-muted-foreground font-medium mb-1" htmlFor="password">
                        パスワード
                    </label>
                    <input
                        className="rounded-lg px-4 py-2 bg-background border border-border/50 mb-6 text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-transparent transition-all"
                        type="password"
                        name="password"
                        placeholder="••••••••"
                        required
                        autoComplete="current-password"
                    />

                    <button
                        formAction={login}
                        className="w-full bg-primary hover:bg-primary/90 text-primary-foreground font-semibold rounded-lg px-4 py-3 mb-3 transition-colors shadow-sm"
                    >
                        ログイン
                    </button>

                    <div className="relative my-4">
                        <div className="absolute inset-0 flex items-center">
                            <span className="w-full border-t border-border/50"></span>
                        </div>
                        <div className="relative flex justify-center text-xs uppercase">
                            <span className="bg-card px-2 text-muted-foreground">または</span>
                        </div>
                    </div>

                    <button
                        formAction={signup}
                        className="w-full border border-border hover:border-primary/50 bg-background text-foreground font-medium rounded-lg px-4 py-3 mb-2 transition-colors shadow-sm"
                    >
                        新規会員登録
                    </button>

                    {message && (
                        <p className="mt-4 p-4 bg-muted text-foreground text-center text-sm rounded-lg border border-border/50 font-medium whitespace-pre-wrap">
                            {message.replace(/\+/g, ' ')}
                        </p>
                    )}
                </form>
            </div>
        </div>
    )
}
