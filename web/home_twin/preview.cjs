const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const esbuild = require('esbuild');

const twinRoot = process.env.TODO_TWIN_ROOT || path.join(os.homedir(), 'Documents', 'Todo', 'household', 'twin');
const housePath = path.join(twinRoot, 'house.json');
const pagePath = path.join(__dirname, 'preview.html');
const weatherRoot = path.join(__dirname, '..', '..', 'assets', 'home_twin_web', 'weather');
const wallpaperRoot = path.join(__dirname, '..', '..', 'assets', 'home_twin_web', 'wallpapers');
const clients = new Set();
let bundle;

function send(response, status, type, contents) {
  response.writeHead(status, { 'Content-Type': type, 'Cache-Control': 'no-store' });
  response.end(contents);
}

function sendFile(response, filePath, type) {
  fs.readFile(filePath, (error, contents) => {
    if (error) {
      send(response, error.code === 'ENOENT' ? 404 : 500, 'text/plain; charset=utf-8', 'No se pudo leer el archivo.');
      return;
    }
    send(response, 200, type, contents);
  });
}

async function main() {
  if (!fs.existsSync(housePath)) {
    throw new Error(`No se encuentra la habitación en ${housePath}`);
  }
  const context = await esbuild.context({
    entryPoints: [path.join(__dirname, 'src', 'preview.js')],
    bundle: true,
    format: 'esm',
    loader: { '.jpg': 'dataurl', '.png': 'dataurl' },
    write: false,
    outfile: 'preview.js',
    plugins: [{
      name: 'recarga-vista-previa',
      setup(build) {
        build.onEnd((result) => {
          if (result.errors.length || !result.outputFiles?.length) return;
          bundle = result.outputFiles[0].contents;
          for (const client of clients) client.write('data: recargar\n\n');
          process.stdout.write('Vista previa actualizada.\n');
        });
      },
    }],
  });
  await context.watch();

  const server = http.createServer((request, response) => {
    if (request.method !== 'GET') {
      send(response, 405, 'text/plain; charset=utf-8', 'Método no admitido.');
      return;
    }
    const pathname = new URL(request.url, 'http://127.0.0.1').pathname;
    if (pathname === '/') {
      sendFile(response, pagePath, 'text/html; charset=utf-8');
    } else if (pathname === '/preview.js') {
      if (!bundle) {
        send(response, 503, 'text/plain; charset=utf-8', 'Preparando la vista previa.');
      } else {
        send(response, 200, 'text/javascript; charset=utf-8', bundle);
      }
    } else if (pathname === '/api/house') {
      sendFile(response, housePath, 'application/json; charset=utf-8');
    } else if (/^\/models\/[a-zA-Z0-9_-]+\.glb$/.test(pathname)) {
      sendFile(response, path.join(twinRoot, pathname.slice(1)), 'model/gltf-binary');
    } else if (/^\/weather\/panorama_(despejado|nublado|tormenta|noche|madrugada|atardecer|tarde_noche)\.png$/.test(pathname)) {
      sendFile(response, path.join(weatherRoot, path.basename(pathname)), 'image/png');
    } else if (/^\/wallpapers\/(monitor_izquierdo|monitor_derecho_(dia|atardecer|noche))\.png$/.test(pathname)) {
      sendFile(response, path.join(wallpaperRoot, path.basename(pathname)), 'image/png');
    } else if (pathname === '/__events') {
      response.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-store',
        Connection: 'keep-alive',
      });
      clients.add(response);
      request.on('close', () => clients.delete(response));
    } else {
      send(response, 404, 'text/plain; charset=utf-8', 'No encontrado.');
    }
  });
  server.listen(8788, '127.0.0.1', () => {
    process.stdout.write('Vista previa: http://127.0.0.1:8788/\n');
    process.stdout.write('Guarda desk_details.js para actualizar el navegador. Pulsa Ctrl+C para salir.\n');
  });
  async function stop() {
    server.close();
    for (const client of clients) client.end();
    await context.dispose();
    process.exit(0);
  }
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});
