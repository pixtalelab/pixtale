"use client"

import { useLayoutEffect, useState } from "react"
import { useRouter } from "next/navigation"
import { ArrowLeft } from "lucide-react"
import { useTranslations } from "next-intl"
import { Button } from "@/components/ui/button"
import { LoginForm } from "@/components/login/login-form"
import { login } from "@/request/login"
import { type LoginBo } from "@/server/entity/bo/login"
import { useAuthContext } from "../provider"

// 登录页：提交登录后跳转主体页面。
export default function AuthPage() {
  const { title, publicAlbumEnabled } = useAuthContext()
  const t = useTranslations("login")
  // loading 标记登录请求是否正在提交。
  const [loading, setLoading] = useState(false)
  const router = useRouter()

  // rewrite 不会改地址栏，进入登录页后强制同步为 /auth。
  useLayoutEffect(() => {
    if (window.location.pathname !== "/auth") {
      window.history.replaceState(null, "", "/auth")
    }
  }, [])

  // 请求登录接口，成功后跳转照片页面，由主体 layout 注入用户与业务数据。
  function handleLogin(params: LoginBo) {
    setLoading(true)

    login(params)
      .then(() => {
        router.replace("/photos")
      })
      .catch(() => {
        setLoading(false)
      })
  }

  return (
    <div className="relative isolate flex min-h-screen w-full flex-col items-center justify-center gap-6 overflow-hidden p-6 md:p-10">
      {publicAlbumEnabled && (
        <Button
          type="button"
          variant="outline"
          size="icon"
          className="absolute left-4 top-4 z-20"
          aria-label={t("back")}
          title={t("back")}
          onClick={() => router.back()}
        >
          <ArrowLeft />
        </Button>
      )}
      <div className="relative z-10 flex w-full max-w-sm flex-col gap-6">
        <LoginForm title={title} loading={loading} onLogin={handleLogin} />
      </div>
    </div>
  )
}
