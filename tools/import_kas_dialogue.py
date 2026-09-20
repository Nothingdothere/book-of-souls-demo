"""Import supplied art without modifying pixels; convert the authored dialogue to data."""
from pathlib import Path
import json
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DESKTOP = Path('C:/Users/playd/OneDrive/Рабочий стол')
SOURCE = Path('C:/Users/playd/.codex/attachments/4846e86c-26dd-449d-802a-8e229ad292af/Вставленный текст.txt')

for archive, folder, prefix in [
    ('kas_idle_cycle_v1.zip', 'idle', 'kas_idle_right_'),
    ('kas_idle_front_v1.zip', 'conversation', 'kas_idle_front_'),
]:
    destination = ROOT / 'assets/npc/kas' / folder
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(DESKTOP / archive) as bundle:
        for item in bundle.infolist():
            name = Path(item.filename).name
            if re.fullmatch(re.escape(prefix) + r'0[1-8]\.png', name):
                (destination / name).write_bytes(bundle.read(item))
            elif name == 'animation_manifest.json':
                (destination / name).write_bytes(bundle.read(item))

ui = ROOT / 'assets/ui/dialogue'
ui.mkdir(parents=True, exist_ok=True)
for name in ['dialogue_panel_darkness.png', 'portrait_dark.png', 'portrait_kas.png']:
    shutil.copy2(DESKTOP / name, ui / name)

dialogue_dir = ROOT / 'dialogue'
dialogue_dir.mkdir(exist_ok=True)
shutil.copy2(SOURCE, dialogue_dir / 'kas_source.txt')
paragraphs = re.split(r'\n\s*\n', SOURCE.read_text(encoding='utf-8-sig').strip())
document = {'intro': [], 'topics': []}
section = document['intro']
for paragraph in paragraphs:
    paragraph = paragraph.strip()
    if paragraph.startswith('«') and paragraph.endswith('»'):
        topic = {'id': 'topic_' + str(len(document['topics']) + 1), 'label': paragraph[1:-1], 'lines': []}
        document['topics'].append(topic)
        section = topic['lines']
    else:
        speaker, separator, body = paragraph.partition('\n')
        if speaker in ('КАС:', 'ДАРК:'):
            section.append({'speaker': 'kas' if speaker == 'КАС:' else 'dark', 'text': body.strip()})
        else:
            section.append({'speaker': '', 'text': paragraph})
assert len(document['topics']) == 6
assert len(document['intro']) == 4
(dialogue_dir / 'kas_intro.json').write_text(json.dumps(document, ensure_ascii=False, indent=2), encoding='utf-8')

resource = ['[gd_resource type="SpriteFrames" load_steps=17 format=3]', '']
for animation, folder, prefix in [('idle', 'idle', 'kas_idle_right'), ('conversation', 'conversation', 'kas_idle_front')]:
    for frame in range(1, 9):
        resource.append(f'[ext_resource type="Texture2D" path="res://assets/npc/kas/{folder}/{prefix}_{frame:02}.png" id="{animation}_{frame}"]')
resource.extend(['', '[resource]', 'animations = ['])
for index, animation in enumerate(['idle', 'conversation']):
    # The eight supplied images already include the return phase of the cycle.
    frames = ',\n'.join(f'{{"duration": 1.0, "texture": ExtResource("{animation}_{frame}")}}' for frame in range(1, 9))
    exported_name = 'side' if animation == 'idle' else 'front'
    resource.append('{"frames": [\n' + frames + f'\n], "loop": true, "name": &"{exported_name}", "speed": 4.0' + '}' + (',' if index == 0 else ''))
resource.append(']')
(ROOT / 'assets/npc/kas/kas_frames.tres').write_text('\n'.join(resource) + '\n', encoding='utf-8')
print('Imported 16 NPC frames, 3 UI images,', len(document['topics']), 'topics,', sum(len(t['lines']) for t in document['topics']) + len(document['intro']), 'dialogue entries.')
