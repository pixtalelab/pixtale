<div align="center">
    <img src="https://img.022335.xyz/logo.png" width="64px" />
    <h1 align="center">Pixtale</h1>
    <p></p>
    <p align="center">A self-hosted cloud photo gallery</p>
    <p>
        <a href="https://022335.xyz">Live Demo</a> · <a href="https://pixtale.aslost.com/en">Deployment Guide</a> ·
        English | <a href="README.md">简体中文</a>
    </p>
    <img alt="Next.js" src="https://img.shields.io/badge/next.js-16-white?labelColor=black&logo=nextdotjs&logoColor=white&style=flat-square">
    <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3-06B6D4?labelColor=black&logo=flutter&logoColor=white&style=flat-square">
    <img alt="Docker" src="https://img.shields.io/badge/docker-ready-2496ED?labelColor=black&logo=docker&logoColor=white&style=flat-square">
    <img alt="AGPL-3.0" src="https://img.shields.io/badge/license-AGPL--3.0-blue?labelColor=black&style=flat-square">
</div>

## 💡 Introduction

**Pixtale** is a self-hosted cloud photo gallery with support for **local storage, S3, Telegram**, and other storage backends. Use the companion sync app to automatically sync photos from your phone and PC to your gallery.

## 💻 Screenshots

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

```bash
docker run -d \
  --name pixtale \
  -p 8082:8082 \
  -v /home/pixtale/data:/app/data \
  -e ADMIN=admin \
  -e PASSWORD=123456 \
  -e JWT_SECRET=abc \
  pixtalelab/pixtale:latest
```

Set `ADMIN`, `PASSWORD`, and `JWT_SECRET` to your own values, then run the command. Open `http://<your-server-ip>:8082` in your browser to access your gallery.

For detailed deployment and usage instructions, see the [Deployment Guide](https://pixtale.aslost.com/en).

## ✨ Features

- **🖼️ Masonry Gallery:** Infinite scrolling with cursor pagination and virtualized rendering for improved performance.

- **🔄 Automatic Sync:** Automatically sync local photos to your gallery with [Pixtale Sync](https://github.com/pixtalelab/pixtale/releases).

- **🌄 Optimized Thumbnails:** Generates thumbnails and high-resolution previews for a better experience on slower networks.

- **📷 EXIF Metadata:** Reads EXIF metadata and organizes photos chronologically.

- **💻 Responsive Design:** Adapts to desktop and mobile screens.

- **☁️ Multiple Storage Backends:** Brings photos from local storage, Telegram, and S3 together in one gallery.

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
