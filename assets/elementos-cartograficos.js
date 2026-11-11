function(el) {
  var chart = echarts.getInstanceByDom(el);
  if (!chart) return;
  var ink = '#00305c';
  function text(x, y, label, size) {
    return {type: 'text', silent: true, style: {
      x: x, y: y, text: label, fill: ink, fontSize: size || 11,
      fontFamily: 'Arial, sans-serif', align: 'center', verticalAlign: 'middle'
    }};
  }
  function line(x1, y1, x2, y2) {
    return {type: 'line', silent: true,
      shape: {x1: x1, y1: y1, x2: x2, y2: y2},
      style: {stroke: ink, lineWidth: 1.5}};
  }
  function update() {
    if (chart.isDisposed() || chart.getWidth() < 180 || chart.getHeight() < 160) return;
    var width = chart.getWidth(), height = chart.getHeight();
    var finder = {seriesIndex: 0};
    // Distância geodésica local à latitude da barra, na projeção do mapa.
    var origin = [width - 150, height - 65];
    var a = chart.convertFromPixel(finder, origin);
    var b = chart.convertFromPixel(finder, [origin[0] + 100, origin[1]]);
    if (!a || !b || !a.concat(b).every(Number.isFinite) || Math.abs(a[1]) >= 90) return;
    var rad = Math.PI / 180, radius = 6371.0088;
    var cosine = Math.cos(a[1] * rad);
    var distance = 2 * radius * Math.asin(Math.min(1,
      Math.abs(cosine * Math.sin((b[0] - a[0]) * rad / 2))));
    if (!(distance > 0)) return;
    var power = Math.pow(10, Math.floor(Math.log10(distance)));
    var normalized = distance / power;
    var km = (normalized >= 5 ? 5 : normalized >= 2 ? 2 : 1) * power;
    var longitude = a[0] + 2 * Math.asin(Math.min(1,
      Math.sin(km / (2 * radius)) / cosine)) / rad;
    var end = chart.convertToPixel(finder, [longitude, a[1]]);
    var length = Math.abs(end[0] - origin[0]);
    if (!Number.isFinite(length)) return;
    var rose = [text(34, 5, 'N'), text(64, 35, 'L'),
      text(34, 65, 'S'), text(4, 35, 'O')];
    for (var i = 0; i < 8; i++) {
      var angle = i * Math.PI / 4 - Math.PI / 2;
      var tip = i % 2 === 0 ? 22 : 13;
      rose.push({type: 'polygon', silent: true, shape: {points: [
        [34 + tip * Math.cos(angle), 35 + tip * Math.sin(angle)],
        [34 + 5 * Math.cos(angle + Math.PI / 2), 35 + 5 * Math.sin(angle + Math.PI / 2)],
        [34, 35]
      ]}, style: {fill: ink, stroke: ink, lineWidth: 0.6}});
      rose.push({type: 'polygon', silent: true, shape: {points: [
        [34 + tip * Math.cos(angle), 35 + tip * Math.sin(angle)],
        [34 + 5 * Math.cos(angle - Math.PI / 2), 35 + 5 * Math.sin(angle - Math.PI / 2)],
        [34, 35]
      ]}, style: {fill: '#ffffff', stroke: ink, lineWidth: 0.6}});
    }
    rose.forEach(function(item, index) { item.id = 'rosa-item-' + index; });
    var scale = [
      text(length / 2, 0, 'Escala aprox.', 10),
      line(0, 15, length, 15), line(0, 10, 0, 20),
      line(length / 2, 12, length / 2, 18), line(length, 10, length, 20),
      text(0, 30, '0', 10),
      text(length, 30, km.toLocaleString('pt-BR', {maximumFractionDigits: 3}) + ' km', 10)
    ];
    scale.forEach(function(item, index) { item.id = 'escala-item-' + index; });
    chart.setOption({graphic: [
      {id: 'rosa-dos-ventos', type: 'group', right: 20, top: 85,
        silent: true, z: 100, children: rose},
      {id: 'escala-cartografica', type: 'group', x: origin[0], y: origin[1] - 15,
        silent: true, z: 100, children: scale}
    ]});
  }
  if (el._cartografiaCleanup) el._cartografiaCleanup();
  var frame;
  function schedule() {
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(update);
  }
  chart.on('georoam', schedule);
  window.addEventListener('resize', schedule);
  var observer = new ResizeObserver(schedule);
  observer.observe(el);
  el._cartografiaCleanup = function() {
    chart.off('georoam', schedule);
    window.removeEventListener('resize', schedule);
    observer.disconnect();
    cancelAnimationFrame(frame);
  };
  schedule();
}
