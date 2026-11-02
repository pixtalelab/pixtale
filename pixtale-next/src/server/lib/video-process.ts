import { execFile } from "node:child_process"
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { promisify } from "node:util"
import ffmpegPath from "ffmpeg-static"

// 这个模块使用 FFmpeg 提取视频第一帧，供照片派生图片流程复用。

const execFileAsync = promisify(execFile)

// 将视频写入临时目录，提取第一帧 PNG，并在处理结束后清理临时文件。
export async function readVideoFrame(buffer: Buffer): Promise<Buffer> {
  const executable = process.env.FFMPEG_PATH || ffmpegPath
  if (!executable) {
    throw new Error("FFmpeg is unavailable. Set FFMPEG_PATH to an FFmpeg executable.")
  }

  const directory = await mkdtemp(join(tmpdir(), "pixtale-video-"))
  const input = join(directory, "video")
  const output = join(directory, "frame.png")

  try {
    // 使用临时文件支持索引位于尾部的视频，避免通过 stdin 输入时无法定位。
    await writeFile(input, buffer)
    await execFileAsync(executable, [
      "-nostdin", "-hide_banner", "-loglevel", "error",
      "-protocol_whitelist", "file,pipe",
      "-i", input,
      "-map", "0:V:0",
      "-frames:v", "1",
      "-an", "-sn", "-dn",
      "-threads", "1",
      "-update", "1",
      output,
    ], { timeout: 60_000, windowsHide: true })

    return await readFile(output)
  } finally {
    await rm(directory, { recursive: true, force: true })
  }
}
