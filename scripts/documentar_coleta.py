"""Fotografia somente de leitura dos manifestos; não dispara coletas."""
import datetime
import hashlib
import json
import pathlib
import sqlite3

root = pathlib.Path(__file__).resolve().parents[1]
base = pathlib.Path('/home/rolf/dados_publicos')
snapshot = {'consultado_em': datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'agenda': '0 22 * * 6', 'fuso': 'America/Sao_Paulo', 'fontes': {}}
for flow, pattern in [('siasus', 'pa%'), ('sihsus', 'rd%'), ('sinan', 'violbr%')]:
    with sqlite3.connect(f'file:{base / flow / "state/manifest.sqlite"}?mode=ro', uri=True) as db:
        db.row_factory = sqlite3.Row
        params = (pattern,)
        where = 'where lower(nome) like ? and ativo=1'
        summary = dict(db.execute(f'''select count(*) arquivos,
            min(first_seen_at) primeiro_inventario, max(last_seen_at) ultimo_inventario,
            max(downloaded_at) ultimo_download, max(converted_at) ultima_conversao
            from arquivos {where}''', params).fetchone())
        summary['estados'] = [dict(row) for row in db.execute(
            f'select status, count(*) arquivos from arquivos {where} group by status', params)]
        summary['ultimas_etapas'] = [dict(row) for row in db.execute('''select etapa,
            iniciado_em, concluido_em, resultado from execucoes order by id desc limit 3''')]
        summary['padrao'] = pattern
        snapshot['fontes'][flow] = summary
paths = [base / 'dados_publicos_mensal_dag.py']
paths += [base / f / p for f in ['siasus', 'sihsus', 'sinan']
          for p in [f'{f}_dag.py', 'pipeline.py']]
snapshot['codigo_consultado'] = [
    {'arquivo': str(p.relative_to(base)), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
    for p in paths]
target = root / 'fontes/coleta_airflow.json'
target.parent.mkdir(exist_ok=True)
target.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + '\n')
print(target)
