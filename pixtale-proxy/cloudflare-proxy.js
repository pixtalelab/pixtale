// Cloudflare Worker proxy for Telegram Bot API and file downloads.

const TELEGRAM_ORIGIN = 'https://api.telegram.org';

// Resolve the response MIME type from the requested filename extension.
function getContentType(filename, filePath) {
  const resolvedFilename = filename || filePath.split('/').pop() || 'file';
  const extension = resolvedFilename.split('.').pop()?.toLowerCase();
  const contentTypes = {
    avif: 'image/avif',
    bmp: 'image/bmp',
    gif: 'image/gif',
    jfif: 'image/jpeg',
    jpeg: 'image/jpeg',
    jpg: 'image/jpeg',
    png: 'image/png',
    svg: 'image/svg+xml',
    webp: 'image/webp',
  };

  return contentTypes[extension] || 'application/octet-stream';
}

// Read a Telegram file by file_id and return its content.
async function getFile(fileIdWithName, env) {
  const [fileId, encodedFilename] = fileIdWithName.split('&', 2);
  const filename = encodedFilename ? decodeURIComponent(encodedFilename) : '';
  const token = env.TG_BOT_TOKEN?.trim();

  if (!token) {
    return new Response('TELEGRAM_BOT_TOKEN is not configured', {
      status: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
    });
  }

  const fileInfoResponse = await fetch(
    `${TELEGRAM_ORIGIN}/bot${token}/getFile?file_id=${fileId}`,
  );
  const fileInfo = await fileInfoResponse.json();

  if (!fileInfoResponse.ok || !fileInfo.ok || !fileInfo.result?.file_path) {
    return new Response(fileInfo.description || 'Unable to resolve Telegram file', {
      status: fileInfoResponse.ok ? 502 : fileInfoResponse.status,
      headers: {
        'Access-Control-Allow-Origin': '*',
      },
    });
  }

  const filePath = fileInfo.result.file_path;
  const response = await fetch(`${TELEGRAM_ORIGIN}/file/bot${token}/${filePath}`);

  if (!response.ok) {
    return response;
  }

  const headers = new Headers(response.headers);
  headers.set('Access-Control-Allow-Origin', '*');
  headers.set('Cache-Control', 'public, max-age=604800');
  headers.set('Content-Type', getContentType(filename, filePath));

  if (filename) {
    headers.set('Content-Disposition', `inline; filename*=UTF-8''${encodedFilename}`);
  }

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

// Forward a Telegram API request to the Telegram origin.
async function proxy(request) {
  const url = new URL(request.url);

  const targetUrl = `${TELEGRAM_ORIGIN}${url.pathname}${url.search}`;
  const targetRequest = new Request(targetUrl, request);

  return fetch(targetRequest);
}

// Handle Cloudflare Worker requests.
const worker = {
  async fetch(request, env) {
    try {
      const url = new URL(request.url);

      if (url.pathname === '/') {
        return new Response('success');
      }

      const fileId = url.pathname.slice(1);

      if (fileId && !fileId.includes('/')) {
        return await getFile(fileId, env);
      }

      if (url.pathname.startsWith('/bot') || url.pathname.startsWith('/file/')) {
        return await proxy(request);
      }

      return new Response('Not Found', { status: 404 });
    } catch (error) {
      return new Response(error instanceof Error ? error.message : 'Proxy request failed', {
        status: 502,
      });
    }
  },
};

export default worker;
