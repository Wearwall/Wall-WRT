#!/usr/bin/env python3
"""Verify existing build artifacts and prepare dated GitHub Release assets."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import zipfile


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def firmware_type(name):
    for original, short in (
        ('initramfs-uImage.itb', 'initramfs.itb'),
        ('squashfs-factory.bin', 'factory.bin'),
        ('squashfs-sysupgrade.bin', 'sysupgrade.bin'),
    ):
        if name.endswith('jdcloud_re-cs-02-' + original):
            return short
    raise ValueError(f'Unknown firmware type: {name}')


def prepare(root, output, run_id):
    if not re.fullmatch(r'[0-9]+', run_id):
        raise ValueError('Invalid build run ID')
    folders = []
    for folder in sorted(root.iterdir()):
        match = re.fullmatch(r'Athena-(libwrt|immortalwrt)-(\d{8})-' + run_id, folder.name)
        if folder.is_dir() and match:
            datetime.datetime.strptime(match[2], '%Y%m%d')
            folders.append((folder, match[1], match[2]))
    if not folders or len({date for _, _, date in folders}) != 1:
        raise ValueError('Missing firmware artifacts or inconsistent build dates')
    assets = output / 'assets'
    assets.mkdir(parents=True, exist_ok=False)
    for folder, flavor, date in folders:
        records = {}
        for line in (folder / 'SHA256SUMS').read_text().splitlines():
            checksum, name = line.split(maxsplit=1)
            name = name.removeprefix('*')
            if Path(name).name != name or not re.fullmatch(r'[0-9a-f]{64}', checksum):
                raise ValueError('Invalid checksum entry')
            records[name] = checksum
        files = sorted(path for path in folder.iterdir() if path.name != 'SHA256SUMS')
        if {path.name for path in files} != set(records):
            raise ValueError('Artifact files differ from SHA256SUMS')
        for path in files:
            if path.is_symlink() or not path.is_file() or digest(path) != records[path.name]:
                raise ValueError(f'Artifact checksum failed: {path.name}')
        info = json.loads((folder / 'build-info.json').read_text())
        if info['device'] != 'jdcloud_re-cs-02' or info['flavor'] != flavor:
            raise ValueError('Artifact device/flavor mismatch')
        images = [path for path in files if path.suffix in ('.bin', '.itb', '.img', '.gz')]
        if not any('sysupgrade' in path.name and path.stat().st_size for path in images):
            raise ValueError('Missing sysupgrade firmware')
        prefix = f'JDCloud-Athena-{flavor}-{date}-{run_id}'
        for image in images:
            if 'jdcloud_re-cs-02' not in image.name or not image.stat().st_size:
                raise ValueError('Unexpected firmware image')
            destination = assets / f'{prefix}-{firmware_type(image.name)}'
            if destination.exists():
                raise ValueError(f'Duplicate firmware type: {destination.name}')
            shutil.copy2(image, destination)
        with zipfile.ZipFile(assets / f'{prefix}-info.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
            for path in files:
                if path not in images:
                    archive.write(path, path.name)
    with (assets / 'SHA256SUMS').open('w') as stream:
        for path in sorted(assets.iterdir()):
            if path.name != 'SHA256SUMS':
                stream.write(f'{digest(path)}  {path.name}\n')
    date = folders[0][2]
    pretty_date = datetime.datetime.strptime(date, '%Y%m%d').date().isoformat()
    (output / 'tag.txt').write_text(f'athena-{date}-{run_id}\n')
    (output / 'title.txt').write_text(f'京东雅典娜AX6600 {pretty_date}\n')
    repo = os.environ.get('GITHUB_REPOSITORY', 'Wearwall/Wall-WRT')
    flavors = ', '.join(flavor for _, flavor, _ in folders)
    (output / 'notes.md').write_text(
        f'京东云雅典娜 AX6600 / `jdcloud_re-cs-02`，编译日期：{pretty_date}。\n\n'
        f'分支：{flavors}。\n\n'
        f'[原始构建及日志](https://github.com/{repo}/actions/runs/{run_id})\n\n'
        '固件文件名包含分支、编译日期与构建编号。下载对应分支的镜像；'
        '`info.zip` 包含配置、manifest、源码版本与配置审计。'
        '附件 `SHA256SUMS` 校验发布后的文件名，可运行 `sha256sum -c SHA256SUMS`。\n'
    )
    print(f'Prepared {flavors}: {output}')


if __name__ == '__main__':
    prepare(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3])
