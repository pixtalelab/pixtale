<div align="center">
    <img src="https://img.022335.xyz/logo.png" width="80px" />
    <h1 align="center">Pixtale</h1>
    <p align="center"><strong>一个沉浸式瀑布流相册应用🎉</strong></p>
    <p align="center"><a href="README_EN.md">English</a> | 简体中文</p>
    <img alt="Next.js" src="https://img.shields.io/badge/next.js-16-white?labelColor=black&logo=nextdotjs&logoColor=white&style=flat-square">
    <img alt="Docker" src="https://img.shields.io/badge/docker-ready-2496ED?labelColor=black&logo=docker&logoColor=white&style=flat-square">
    <img alt="AGPL-3.0" src="https://img.shields.io/badge/license-AGPL--3.0-blue?labelColor=black&style=flat-square">
</div>


## 前言

Pixtale 是一个基于Next.js构建的沉浸式瀑布流相册，主要用于个人私有存储照片，支持本地和S3等方式聚合存储，可部署到Docker或在Windos运行

## 项目展示

- [在线演示](https://022335.xyz)
- [部署教程](https://doc.022335.xyz/zh/)

![](https://img.022335.xyz/demo.jpg)
![](https://img.022335.xyz/demo1.jpg)


## 功能介绍

- **🖼️ 瀑布流列表**：瀑布流无限滚动，采用游标分页+虚拟滚动优化性能

- **🌄 缩略图优化**：生成缩略图和高清图，优化在弱网环境下的体验

- **📷 EXIF解析**：解析记录照片EXIF信息，按时间线排列照片

- **💻 响应式设计**：响应式布局自动适配PC和大部分手机端浏览器

- **☁️ 聚合存储**：支持本地文件和S3协议对象存储，聚合式存储图片

- **👥 多用户**：支持添加不同用户，提供多用户使用支持与管理


## 技术栈

- **全栈框架：** [Next.js](https://nextjs.org/)

- **Web框架：** [Hono](https://hono.dev/)

- **ORM：** [Drizzle](https://orm.drizzle.team/)

- **数据库：** [SQLite](https://sqlite.org/)

- **UI组件：** [shadcn/ui](https://ui.shadcn.com/)

## 友情社区
[LINUXDO](https://linux.do)

## 许可证

`Pixtale` 是基于 [AGPL-3.0](LICENSE) 许可证的开源软件