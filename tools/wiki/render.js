// node render.js <build dir> <out dir> [names...]: prints each volume HTML to PDF with Chromium.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
(async () => {
  const build = process.argv[2], out = process.argv[3];
  const only = process.argv.slice(4);
  const manifest = JSON.parse(fs.readFileSync(path.join(build, 'manifest.json')));
  const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });
  const page = await browser.newPage();
  for (const v of manifest) {
    if (only.length && !only.includes(v.name)) continue;
    await page.goto('file://' + path.join(build, v.name + '.html'), { waitUntil: 'load', timeout: 120000 });
    await page.evaluate(() => document.fonts.ready);
    await page.pdf({
      path: path.join(out, v.name + '.pdf'), format: 'A4', printBackground: true, preferCSSPageSize: true,
      displayHeaderFooter: true, outline: true, tagged: true,
      headerTemplate: '<span></span>',
      footerTemplate: `<div style="width:100%;font-size:7px;color:#9a8a78;padding:0 15mm;display:flex;justify-content:space-between;font-family:Inter,sans-serif">
        <span>Swarmed · ${v.title}</span><span class="pageNumber"></span></div>`,
    });
    console.log('pdf', v.name);
  }
  await browser.close();
})();
