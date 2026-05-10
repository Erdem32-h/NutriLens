// 1024x500 Play feature graphic exporter
// Kullanım:
//   1) npm install puppeteer
//   2) node assets/store/export_feature_graphic.js
//
// Çıktı: assets/store/feature_graphic.png

const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch({
    defaultViewport: { width: 1024, height: 500, deviceScaleFactor: 2 }, // 2x retina
  });
  const page = await browser.newPage();

  const file = 'file://' + path.resolve(__dirname, 'feature_graphic.html');
  await page.goto(file, { waitUntil: 'networkidle0' });

  const el = await page.$('#feature');
  await el.screenshot({
    path: path.resolve(__dirname, 'feature_graphic.png'),
    omitBackground: false,
  });

  await browser.close();
  console.log('✓ feature_graphic.png üretildi');
})();
