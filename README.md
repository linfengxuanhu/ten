# AI Council

不使用 API Key 的 Android 多 AI 网页聚合器。

包含 ChatGPT、Claude、Gemini、Grok、Kimi、DeepSeek、Qwen、豆包。

## 使用

打开应用后登录各 AI 网站。顶部输入一个问题，点击“全发”，程序会依次尝试向各网页输入并发送。

本项目不绕过验证码、登录限制、风控、速率限制或其他反自动化机制。如果某个网站页面结构发生变化，自动发送失败时可直接切换到该站点手动发送。

## GitHub 打包

上传整个项目到 GitHub 后：

Actions → Build Android APK → Run workflow。

完成后下载 `ai-council-release`。

## 技术

Flutter + webview_flutter + shared_preferences。

当前版本重点是可运行的第一版网页工作区；回答自动抓取和八站点统一答案解析需要针对每个网站分别适配，后续可继续加入。
