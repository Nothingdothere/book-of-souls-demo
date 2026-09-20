"""Import authored reading-room art and structured dialogue, preserving source text."""
from pathlib import Path
import json, re, shutil, zipfile

ROOT = Path(__file__).resolve().parents[1]
DESKTOP = Path('C:/Users/playd/OneDrive/Рабочий стол')
SOURCE = Path('C:/Users/playd/.codex/attachments/befb3980-0513-4007-b1bb-6259d48334f1/Вставленный текст.txt')
frames_dir = ROOT / 'assets/npc/lina'
frames_dir.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(DESKTOP / 'fractured_soul_idle_front_v1.zip') as bundle:
    for entry in bundle.infolist():
        name = Path(entry.filename).name
        if re.fullmatch(r'fractured_soul_idle_front_(0[1-9]|1[0-4])\.png', name) or name == 'animation_manifest.json':
            (frames_dir / name).write_bytes(bundle.read(entry))
shutil.copy2(DESKTOP / 'Изображение Codex 20 сент. 2026 г., 16_38_30.png', ROOT / 'assets/background/reading_tables.png')
shutil.copy2(DESKTOP / 'Изображение Codex 20 сент. 2026 г., 16_43_53.png', ROOT / 'assets/ui/dialogue/portrait_lina.png')
shutil.copy2(SOURCE, ROOT / 'dialogue/lina_source.txt')

topics = [
    ('name', 'Как тебя зовут?', 'КАК ТЕБЯ ЗОВУТ?', []),
    ('last_memory', 'Что ты помнишь последним?', 'ЧТО ТЫ ПОМНИШЬ ПОСЛЕДНИМ?', []),
    ('wrists', 'Что у тебя на запястьях?', 'ЧТО У ТЕБЯ НА ЗАПЯСТЬЯХ?', []),
    ('life', 'Расскажи о своей жизни.', 'РАССКАЖИ О СВОЕЙ ЖИЗНИ', []),
    ('reluctance', 'Почему ты не хочешь вспоминать?', 'ПОЧЕМУ ТЫ НЕ ХОЧЕШЬ ВСПОМИНАТЬ?', ['wrists']),
    ('death_wish', 'Ты действительно хотела умереть?', 'ТЫ ДЕЙСТВИТЕЛЬНО ХОТЕЛА УМЕРЕТЬ?', ['last_memory']),
    ('alone', 'Никто не знал, что тебе плохо?', 'НИКТО НЕ ЗНАЛ, ЧТО ТЕБЕ ПЛОХО?', ['last_memory']),
    ('kris', 'Что было в последнем сообщении Крис?', 'ЧТО БЫЛО В ПОСЛЕДНЕМ СООБЩЕНИИ КРИС?', ['alone']),
    ('return', 'Если бы ты могла вернуться, что бы ты сделала?', 'ЕСЛИ БЫ ТЫ МОГЛА ВЕРНУТЬСЯ', ['name', 'last_memory', 'wrists', 'life']),
]
data = {'intro': [], 'topics': [], 'endings': {}, 'understood_requires': ['name', 'last_memory', 'wrists', 'life', 'return']}
by_heading = {}
for ident, label, heading, requirements in topics:
    topic = {'id': ident, 'label': label, 'requires': requirements, 'lines': []}
    data['topics'].append(topic)
    by_heading[heading] = topic['lines']
section = data['intro']
speaker = ''
for raw in SOURCE.read_text(encoding='utf-8-sig').splitlines()[1:]:
    line = raw.strip()
    if not line:
        continue
    if line.startswith('ВЕТКА:'):
        heading = line.split('«', 1)[1].rsplit('»', 1)[0]
        section = by_heading[heading]
        speaker = ''
        continue
    if line.startswith('ВАРИАНТ:'):
        key = 'oblivion' if 'ЗАБВЕНИЕ' in line else 'rebirth_understood' if 'ДУША ВЫСЛУШАНА' in line else 'rebirth_rushed'
        section = []
        data['endings'][key] = section
        speaker = ''
        continue
    if line in ['ЛИНА:', 'ДАРК:', 'СИСТЕМНОЕ СООБЩЕНИЕ:']:
        speaker = {'ЛИНА:': 'lina', 'ДАРК:': 'dark', 'СИСТЕМНОЕ СООБЩЕНИЕ:': 'system'}[line]
        continue
    if line.startswith(('ВАРИАНТЫ ДИАЛОГА:', 'Открывается вопрос:', 'Открываются вопросы:', 'ПОСЛЕ ИЗУЧЕНИЯ', '— ')) or line == 'РЕШЕНИЕ':
        speaker = ''
        continue
    if line.startswith('Молча вздыхает'):
        speaker = ''
    entry = {'speaker': speaker, 'text': line}
    if line == 'Лина исчезает.' or line.startswith('Она исчезает в звёздной дымке.') or line.startswith('Дымка темнеет и постепенно поглощает её.'):
        entry['effect'] = 'depart'
    if line == 'В темноте Дарка остаётся маленькая звезда.':
        entry['effect'] = 'star'
    section.append(entry)
    speaker = ''
assert all(t['lines'] for t in data['topics'])
assert set(data['endings']) == {'oblivion', 'rebirth_understood', 'rebirth_rushed'}
(ROOT / 'dialogue/lina_intro.json').write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
resource = ['[gd_resource type="SpriteFrames" load_steps=15 format=3]', '']
for i in range(1, 15):
    resource.append(f'[ext_resource type="Texture2D" path="res://assets/npc/lina/fractured_soul_idle_front_{i:02}.png" id="{i}"]')
resource.extend(['', '[resource]', 'animations = [{"name": &"idle", "loop": true, "speed": 4.0, "frames": ['])
resource.append(',\n'.join(f'{{"duration": 1.0, "texture": ExtResource("{i}")}}' for i in range(1, 15)))
resource.append(']}]')
(frames_dir / 'lina_frames.tres').write_text('\n'.join(resource) + '\n', encoding='utf-8')
print('Imported 14 frames, reading tables, portrait,', len(data['intro']), 'intro entries, 9 topics and 3 endings.')
