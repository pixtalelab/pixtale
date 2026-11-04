import { execFile } from "node:child_process"
import { promisify } from "node:util"
import ffmpegPath from "ffmpeg-static"

// 这个模块使用 FFmpeg 提取视频第一帧，供照片派生图片流程复用。

const execFileAsync = promisify(execFile)

// 从视频文件路径提取第一帧 PNG。路径可寻址，能处理索引在文件尾部的视频。
export async function readVideoFrame(inputPath: string, outputPath: string): Promise<string> {
  const executable = process.env.FFMPEG_PATH || ffmpegPath
  if (!executable) {
    throw new Error("FFmpeg is unavailable. Set FFMPEG_PATH to an FFmpeg executable.")
  }

  await execFileAsync(executable, [
    "-nostdin", "-hide_banner", "-loglevel", "error",
    "-protocol_whitelist", "file,pipe",
    "-i", inputPath,
    "-map", "0:V:0",
    "-frames:v", "1",
    "-an", "-sn", "-dn",
    "-threads", "1",
    "-update", "1",
    outputPath,
  ], { timeout: 60_000, windowsHide: true })

  return outputPath
}
