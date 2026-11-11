// Uso: node scripts/verificar_mapas.cjs [diretorio], após quarto render.
// Executa o ECharts do próprio painel em SVG, sem navegador ou DOM.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const cartografia = fs.readFileSync(path.join(__dirname, '../assets/elementos-cartograficos.js'), 'utf8');
const root = path.resolve(__dirname, '..', process.argv[2] || 'publica');
const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const bundle = html.match(/<script src="([^"]*\/echarts(?:-en)?\.min\.js)"/);
assert(bundle, 'Biblioteca ECharts não encontrada no HTML');
// Node 22+ expõe navigator; ECharts deve detectar aqui o ambiente de servidor.
delete global.navigator;
const echarts = require(path.join(root, bundle[1]));
function readMaps(page) {
  return [...page.matchAll(/<script type="application\/json" data-for="([^"]+)">(.*?)<\/script>/gs)]
  .map(match => {
    const payload = JSON.parse(match[2]);
    return {...payload.x, jsHooks: payload.jsHooks};
  })
  .filter(widget => widget.opts?.series?.some(series =>
    series.type === 'map' && series.map?.startsWith('municipios')));
}
const widgets = readMaps(html);
assert.equal(widgets.length, 3, 'Os três mapas municipais precisam estar no HTML');
const storyMaps = readMaps(fs.readFileSync(path.join(root, 'historia/historia.html'), 'utf8'));
assert.equal(storyMaps.length, 1, 'O mapa da história precisa estar no HTML');
widgets.push(...storyMaps);
const councilMaps = widgets.filter(widget => widget.opts.series[0].map === 'municipios_ct');
const sharedGeometry = councilMaps[0].registerMap[0].geoJSON;
assert.deepEqual(councilMaps[1].registerMap[0].geoJSON, sharedGeometry,
  'Painel e história devem reutilizar a mesma malha de 2022');
assert.equal(sharedGeometry.features.length, 5570, 'Municípios de 2022 ausentes');
for (const feature of sharedGeometry.features) {
  assert.equal(feature.geometry.type, 'MultiPolygon', 'Geometria incompatível com o ECharts');
  assert(feature.geometry.coordinates.length > 0, 'Município sem geometria');
}
for (const widget of councilMaps) {
  assert.deepEqual(new Set(widget.opts.series[0].data.map(item => item.name)),
    new Set(sharedGeometry.features.map(feature => feature.properties.name)),
    'Os indicadores precisam corresponder aos municípios da malha');
}
for (const widget of widgets) {
  for (const map of widget.registerMap || []) {
    echarts.registerMap(map.mapName, map.geoJSON);
  }
  const chart = echarts.init(null, null, { renderer: 'svg', ssr: true, width: 900, height: 700 });
  try {
    chart.setOption(widget.opts);
    const hook = widget.jsHooks?.render?.find(hook => hook.code.includes('rosa-dos-ventos'));
    assert(hook, 'Elementos cartográficos ausentes no widget exportado');
    assert.equal(hook.code.trim(), cartografia.trim(), 'HTML com elementos cartográficos desatualizados');
    const frames = [];
    const listeners = {};
    const init = vm.runInNewContext('(' + hook.code + ')', {
      echarts: {getInstanceByDom: () => chart},
      requestAnimationFrame: callback => { frames.push(callback); return frames.length; },
      cancelAnimationFrame: () => {},
      ResizeObserver: class { observe() {} disconnect() {} },
      window: {addEventListener: (name, callback) => { listeners[name] = callback; },
        removeEventListener: () => {}}
    });
    init({});
    frames.shift()();
    function checkScale() {
      const graphics = chart.getOption().graphic[0].elements;
      const rose = graphics.find(item => item.id === 'rosa-dos-ventos');
      const scale = graphics.find(item => item.id === 'escala-cartografica');
      assert(rose && scale, 'Rosa dos ventos ou escala ausente');
      for (const original of widget.opts.graphic || []) {
        if (original.type === 'text') assert(graphics.some(item =>
          item.style?.text === original.style.text), 'Texto original do mapa foi alterado');
      }
      const svg = chart.renderToSVGString();
      for (const label of ['N', 'S', 'L', 'O', 'Escala aprox.']) {
        assert(svg.includes('>' + label + '</tspan>') || svg.includes('>' + label + '</text>'),
          'Rótulo cartográfico ausente: ' + label);
      }
      const children = graphics.filter(item => item.parentId === scale.id);
      const label = children[6].style.text;
      const km = Number(label.replace(' km', '').replace(/\./g, '').replace(',', '.'));
      const start = chart.convertFromPixel({seriesIndex: 0}, [scale.x, scale.y + 15]);
      const end = chart.convertFromPixel({seriesIndex: 0},
        [scale.x + children[1].shape.x2, scale.y + 15]);
      const rad = Math.PI / 180;
      const measured = 2 * 6371.0088 * Math.asin(Math.abs(
        Math.cos(start[1] * rad) * Math.sin((end[0] - start[0]) * rad / 2)));
      assert(Math.abs(measured - km) < 0.001, 'Escala incompatível com a distância geográfica');
      return km;
    }
    const originalKm = checkScale();
    chart.setOption({series: [{zoom: 2}]});
    chart.trigger('georoam', {});
    frames.shift()();
    assert(checkScale() < originalKm, 'Escala não foi atualizada após zoom');
    chart.setOption({series: [{center: [-47, -10]}]});
    chart.trigger('georoam', {});
    frames.shift()();
    checkScale();
    chart.resize({width: 650, height: 500});
    listeners.resize();
    frames.shift()();
    checkScale();
    const svg = chart.renderToSVGString();
    assert((svg.match(/<path\b/g) || []).length > 100, 'Mapa sem polígonos visíveis');
    console.log(`OK: ${widget.opts.series[0].map} renderizado pelo ECharts`);
  } finally {
    chart.dispose();
  }
}
