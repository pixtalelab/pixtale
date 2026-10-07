<div align="center">
    <img src="https://img.022335.xyz/logo.png" width="64px" />
    <h1 align="center">Pixtale</h1>
    <p></p>
    <p align="center">An immersive masonry photo gallery</p>
    <p>
        <a href="https://022335.xyz">Live Demo</a> · <a href="https://docs.022335.xyz">Deployment Guide</a> ·
        <a align="center">English | <a href="README.md">简体中文</a></a>
    </p>
    <img alt="Next.js" src="https://img.shields.io/badge/next.js-16-white?labelColor=black&logo=nextdotjs&logoColor=white&style=flat-square">
    <img alt="Tauri" src="https://img.shields.io/badge/tauri-2-24C8D8?labelColor=black&logo=tauri&logoColor=white&style=flat-square">
    <img alt="Docker" src="https://img.shields.io/badge/docker-ready-2496ED?labelColor=black&logo=docker&logoColor=white&style=flat-square">
    <img alt="AGPL-3.0" src="https://img.shields.io/badge/license-AGPL--3.0-blue?labelColor=black&style=flat-square">
</div>

## 💡 Introduction

**Pixtale** is a self-hosted cloud photo gallery that supports **local storage, S3, Telegram**, and other storage backends. Combined with the desktop synchronization tool **pixtale-sync**, it can automatically sync local photos to the cloud.

## 💻 Preview

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

## 🐋 Docker Deployment

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

Replace the `ADMIN`, `PASSWORD`, and `JWT_SECRET` values with your own before running the command, then visit `ip:8082` in your browser.

For detailed deployment and usage instructions, see the [Deployment Guide](https://doc.022335.xyz).

## ✨ Features

- **🖼️ Masonry Gallery:** Infinite scrolling with cursor pagination and virtualized rendering for improved performance.

- **🔄 Automatic Sync:** Automatically sync local photos to the cloud with the included `pixtale-sync` tool.

- **🌄 Optimized Thumbnails:** Generates thumbnails and high-resolution previews for a better experience on slower networks.

- **📷 EXIF Metadata:** Parses photo EXIF metadata and arranges photos chronologically.

- **💻 Responsive Design:** Automatically adapts to desktop and most mobile browsers.

- **☁️ Aggregated Storage:** Combines local, Telegram, and S3 storage in one gallery.

- **👥 Multi-user Support:** Create and manage multiple user accounts.

## 🛠️ Tech Stack

- **Full-stack Framework:** [Next.js](https://nextjs.org/)

- **Web Framework:** [Hono](https://hono.dev/)

- **ORM:** [Drizzle](https://orm.drizzle.team/)

- **Database:** [SQLite](https://sqlite.org/)

- **UI Components:** [shadcn/ui](https://ui.shadcn.com/)

## 🤝 Community

[LINUXDO](https://linux.do)

## 📄 License

`Pixtale` is open-source software licensed under the [AGPL-3.0](LICENSE).
