import { execFile } from "node:child_process"
import { promisify } from "node:util"

// 这个模块使用系统 FFmpeg 提取视频第一帧，并从文件头读取时长。

const execFileAsync = promisify(execFile)

// 返回 FFMPEG_PATH 指向的可执行文件。
function ffmpegExecutable() {
  const executable = process.env.FFMPEG_PATH?.trim()
  return executable || null
}

// 用 FFmpeg 读取视频文件头里的时长（秒）。只读头部，不解码整段视频。
export async function readVideoDuration(inputPath: string): Promise<number | null> {
  const executable = ffmpegExecutable()
  if (!executable) {
    return null
  }

  const stderr = await new Promise<string>((resolve) => {
    execFile(executable, ["-nostdin", "-hide_banner", "-i", inputPath], {
      timeout: 30_000,
      windowsHide: true,
      encoding: "utf8",
    }, (error, _stdout, stderrText) => {
      resolve(stderrText || (error && "stderr" in error ? String(error.stderr ?? "") : ""))
    })
  })

  const match = /Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/.exec(stderr)
  if (!match) {
    return null
  }

  const total = Number(match[1]) * 3600 + Number(match[2]) * 60 + Number(match[3])
  return Number.isFinite(total) && total >= 0 ? Math.round(total) : null
}

// 从视频文件路径提取第一帧 PNG。路径可寻址，能处理索引在文件尾部的视频。
export async function readVideoFrame(inputPath: string, outputPath: string): Promise<string> {
  const executable = ffmpegExecutable()
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
