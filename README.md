<div align="center">
    <img src="https://img.022335.xyz/logo.png" width="64px" />
    <h1 align="center">Pixtale</h1>
    <p></p>
    <p align="center">一个沉浸式瀑布流相册应用</p>
    <p>
        <a href="https://022335.xyz">在线演示</a> · <a href="https://docs.022335.xyz">部署文档</a> ·
        <a align="center"><a href="README_EN.md">English</a> | 简体中文</a>
    </p>
    <img alt="Next.js" src="https://img.shields.io/badge/next.js-16-white?labelColor=black&logo=nextdotjs&logoColor=white&style=flat-square">
    <img alt="Tauri" src="https://img.shields.io/badge/tauri-2-24C8D8?labelColor=black&logo=tauri&logoColor=white&style=flat-square">
    <img alt="Docker" src="https://img.shields.io/badge/docker-ready-2496ED?labelColor=black&logo=docker&logoColor=white&style=flat-square">
    <img alt="AGPL-3.0" src="https://img.shields.io/badge/license-AGPL--3.0-blue?labelColor=black&style=flat-square">
</div>


## 💡 前言

**Pixtale** 是一个自托管的云端存储照片相册应用，支持 **本地、S3、Telegram** 等方式作为存储空间，配合本项目的桌面同步工具 **pixtale-sync** 可自动化将本地照片同步至云端

## 💻 项目预览

<table>
  <tr>
    <td><img src="https://img.022335.xyz/demo.jpg" /></td>
    <td><img src="https://img.022335.xyz/demo1.jpg" /></td>
  </tr>
  <tr>
    <td><img src="https://img.022335.xyz/demo2.jpg" /></td>
    <td><img src="https://img.022335.xyz/demo3.jpg" /></td>
  </tr>
</table>

## 🐋 Docker部署

```yaml
docker run -d \
  --name pixtale \
  -p 8082:8082 \
  -v /home/pixtale/data:/app/data \
  -e ADMIN=admin \
  -e PASSWORD=123456 \
  -e JWT_SECRET=abc \
  aslost/pixtale:latest
```
将`ADMIN` `PASSWORD` `JWT_SECRET` 变量替换为自己的并执行， 浏览器访问`ip:8082`

更多详细部署及使用教程见 [部署文档](https://doc.022335.xyz)

## ✨ 功能

- **🖼️ 瀑布流列表**：瀑布流无限滚动，采用游标分页+虚拟滚动优化性能

- **🔄 自动同步**：配合本项目的 `pixtale-sync`，可自同步至云端

- **🌄 缩略图优化**：生成缩略图和高清图，优化在弱网环境下的体验

- **📷 EXIF解析**：解析记录照片EXIF信息，按时间线排列照片

- **💻 响应式设计**：响应式布局自动适配PC和大部分手机端浏览器

- **☁️ 聚合存储**：支持本地、 Telegram、 S3等方式聚合存储

- **👥 多用户**：支持添加不同用户，提供多用户使用支持与管理


## 🛠️ 技术栈

- **全栈框架：** [Next.js](https://nextjs.org/)

- **Web框架：** [Hono](https://hono.dev/)

- **ORM：** [Drizzle](https://orm.drizzle.team/)

- **数据库：** [SQLite](https://sqlite.org/)

- **UI组件：** [shadcn/ui](https://ui.shadcn.com/)

## 🤝 友情社区
[LINUXDO](https://linux.do)

## 📄 许可证

`Pixtale` 是基于 [AGPL-3.0](LICENSE) 许可证的开源软件
