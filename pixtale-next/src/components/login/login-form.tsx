"use client"

import { useEffect, useState, type FormEvent } from "react"
import { LoaderCircle } from "lucide-react"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import {
  Field,
  FieldLabel,
  FieldGroup,
} from "@/components/ui/field"
import { Input } from "@/components/ui/input"
import { type LoginBo } from "@/server/entity/bo/login"
import { useTranslations } from "next-intl"

interface LoginFormProps extends React.ComponentProps<"div"> {
  title: string
  loading?: boolean
  onLogin: (params: LoginBo) => void
}

// 渲染居中标题的登录卡片，并提交账号密码。
export function LoginForm({
  className,
  title,
  loading = false,
  onLogin,
  ...props
}: LoginFormProps) {
  const t = useTranslations("login")
  // hasChineseTitle 用于根据站点名称的字符类型切换标题样式。
  const hasChineseTitle = /[\u3400-\u9fff]/u.test(title)
  // form 保存登录表单的用户名和密码。
  const [form, setForm] = useState<LoginBo>({
    username: "",
    password: "",
  })

  // 若配置了演示账号，则预填到登录表单。
  useEffect(() => {
    const username = process.env.NEXT_PUBLIC_DEMO_USERNAME
    const password = process.env.NEXT_PUBLIC_DEMO_PASSWORD

    if (!username && !password) {
      return
    }

    setForm((prev) => ({
      username: username || prev.username,
      password: password || prev.password,
    }))
  }, [])

  // 更新登录表单字段。
  function updateField(field: keyof LoginBo, value: string) {
    setForm((prev) => ({
      ...prev,
      [field]: value,
    }))
  }

  // 提交登录表单，把用户名和密码传给登录页面。
  function submitLogin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()

    onLogin({
      username: form.username.trim(),
      password: form.password,
    })
  }


  return (
    <div className={cn("flex flex-col gap-6", className)} {...props}>
      <Card className="px-1 pb-4 pt-5 shadow-lg">
        <CardHeader className="flex flex-col items-center gap-2 text-center">
          <div className="flex size-11 items-center justify-center rounded-md">
            <img
              src="/assets/logo.png"
              alt=""
              className="!size-11 object-contain"
              aria-hidden="true"
            />
          </div>
        <CardTitle className={`w-full break-words ${hasChineseTitle ? "text-lg font-bold" : "font-bahamas text-2xl"}`}>
            {title}
          </CardTitle>
        </CardHeader>
        <CardContent className="mt-2">
          <form name="login" onSubmit={submitLogin} autoComplete="on">
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="username" className="font-medium" >{t("username")}</FieldLabel>
                <Input
                  id="username"
                  name="username"
                  type="text"
                  autoComplete="username"
                  value={form.username}
                  onChange={(event) => updateField("username", event.target.value)}
                  required
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="password">{t("password")}</FieldLabel>
                <Input
                  id="password"
                  name="password"
                  type="password"
                  autoComplete="current-password"
                  value={form.password}
                  onChange={(event) => updateField("password", event.target.value)}
                  required
                />
              </Field>
              <Field className="mb-2 mt-1">
                <Button className="w-full" type="submit" disabled={loading}>
                  {loading && <LoaderCircle className="animate-spin" />}
                  {t("signIn")}
                </Button>
              </Field>
            </FieldGroup>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
