// Smoke test for the Web export: serve release/web, open it in Chromium and
// check that the engine boots, draws a non-black frame and logs no errors.
// Usage: node tools/web_smoke/smoke.mjs [build-dir] [screenshot.png]
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { extname, join, resolve, sep } from "node:path";
import { chromium } from "playwright";

const root = resolve(process.argv[2] ?? "release/web");
const screenshotPath = process.argv[3] ?? join(root, "..", "web-smoke.png");
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm", ".pck": "application/octet-stream", ".png": "image/png" };
// Served under a sub-path, as on GitHub Pages.
const BASE = "/echovillage/";

const server = createServer(async (request, response) => {
  const path = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
  if (!path.startsWith(BASE)) { response.writeHead(404).end(); return; }
  const file = resolve(root, "." + sep + (path.slice(BASE.length) || "index.html"));
  if (!file.startsWith(root + sep)) { response.writeHead(403).end(); return; }
  try {
    await stat(file);
    response.writeHead(200, { "Content-Type": TYPES[extname(file)] ?? "application/octet-stream" });
    response.end(await readFile(file));
  } catch {
    response.writeHead(404).end();
  }
});
await new Promise((done) => server.listen(0, "127.0.0.1", done));
const url = `http://127.0.0.1:${server.address().port}${BASE}`;

const browser = await chromium.launch({ args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"] });
const failures = [];
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on("console", (message) => {
    if (message.type() === "error") failures.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => failures.push(`page: ${error.message}`));
  page.on("requestfailed", (request) => failures.push(`request: ${request.url()} ${request.failure()?.errorText}`));
  await page.goto(url);
  await page.waitForSelector("#canvas", { timeout: 30_000 });
  // The loading overlay is removed (or hidden) once the engine runs its main loop.
  await page.waitForFunction(() => {
    const status = document.getElementById("status");
    return !status || getComputedStyle(status).display === "none" || getComputedStyle(status).visibility === "hidden";
  }, null, { timeout: 120_000 });
  await page.waitForTimeout(4_000);
  const shot = await page.locator("#canvas").screenshot({ path: screenshotPath });
  const stats = await page.evaluate(async (base64) => {
    const image = new Image();
    image.src = `data:image/png;base64,${base64}`;
    await image.decode();
    const canvas = new OffscreenCanvas(image.width, image.height);
    const context = canvas.getContext("2d");
    context.drawImage(image, 0, 0);
    const { data } = context.getImageData(0, 0, image.width, image.height);
    let bright = 0;
    const colours = new Set();
    for (let i = 0; i < data.length; i += 4 * 97) {
      if (data[i] + data[i + 1] + data[i + 2] > 60) bright += 1;
      colours.add((data[i] >> 4) * 256 + (data[i + 1] >> 4) * 16 + (data[i + 2] >> 4));
    }
    return { samples: Math.floor(data.length / (4 * 97)), bright, colours: colours.size, width: image.width, height: image.height };
  }, shot.toString("base64"));
  console.log(`canvas ${stats.width}x${stats.height}: ${stats.bright}/${stats.samples} non-dark samples, ${stats.colours} colours`);
  if (stats.bright < stats.samples * 0.2 || stats.colours < 16) failures.push("canvas looks blank");
} finally {
  await browser.close();
  server.close();
}
if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}
console.log(`PASS: web build boots and renders (${screenshotPath})`);
