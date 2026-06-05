#!/usr/bin/env python3
"""Build EPF external processing file for 1C:Enterprise using v8unpack.
Usage:
  python build_epf.py [<repo_dir>]                 # build vitrina_example
  python build_epf.py --src <dir> --out <file>     # generic build
"""
import os, sys, tempfile, uuid

REPO_DIR = os.path.abspath(sys.argv[1] if len(sys.argv) > 1
              and not sys.argv[1].startswith('--') else os.path.dirname(__file__))

for p in [
    os.path.join(REPO_DIR, '_venv', 'Lib', 'site-packages'),
    os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Python', 'pythoncore-3.14-64', 'Lib', 'site-packages'),
    os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Programs', 'Python', 'Python314', 'Lib', 'site-packages'),
]:
    if os.path.isdir(p):
        sys.path.insert(0, p)
from v8unpack import helper
from v8unpack.json_container_decoder import JsonContainerDecoder
from v8unpack.container_writer import compress_and_build as cb, build as container_build


def make_uuid():
    return str(uuid.uuid4()).upper()


def load_bsl(path):
    with open(path, 'r', encoding='utf-8-sig') as f:
        return f.read()


def brace_write(data, dest_dir, file_name):
    helper.makedirs(dest_dir, exist_ok=True)
    decoder = JsonContainerDecoder(src_dir=dest_dir, file_name=file_name)
    raw_data = decoder.encode_root_object(data)
    decoder.write_data(dest_dir, file_name, raw_data)


def build_epf(src_dir, output_path, name='Обработка', form_module='', object_module=''):
    """Build EPF from source BSL files in src_dir, or from provided module text."""

    if not form_module:
        form_module = load_bsl(os.path.join(src_dir, 'form_module.bsl'))
    if not object_module:
        object_module = load_bsl(os.path.join(src_dir, 'object_module.bsl'))

    print(f"Output: {output_path}")

    file_uuid = make_uuid()
    obj_uuid = make_uuid()
    container_uuid = make_uuid()
    form_uuid = make_uuid()
    form_obj_uuid = make_uuid()

    EDP_TYPE_UUID = 'c3831ec8-d8d5-4f93-8a22-f9bfae07327f'
    FORM_TYPE_UUID = 'd5b0e5ed-256d-401c-9c36-f630cafd8a62'

    work_dir = os.path.join(tempfile.mkdtemp(), 'build_epf')
    stage1 = os.path.join(work_dir, 'stage1', '0')
    os.makedirs(stage1, exist_ok=True)

    # root
    brace_write([["2", file_uuid, ""]], stage1, 'root')

    # version
    brace_write([[["217", ["0", "803"]]]], stage1, 'version')

    # copyinfo
    brace_write([["4", ["0"], ["0"], ["0"], ["0", "0"], ["0"]]], stage1, 'copyinfo')

    # Header file
    inner_header = [
        "1",
        ["1", "9cd510cd-abfc-11d4-9434-004095e12fc7", obj_uuid],
        f'"{name}"',
        ["0"],
        '""',
    ]
    obj_data = ["1", inner_header]
    container_info = ["1", container_uuid, "", obj_data]
    form_type_data = [FORM_TYPE_UUID, "1", form_uuid]
    include = [EDP_TYPE_UUID, container_info, "1", form_type_data]
    section = [EDP_TYPE_UUID, include]
    header_data = ["2", file_uuid, "", section]
    brace_write([header_data], stage1, file_uuid)

    # Object module code
    with open(os.path.join(stage1, f'{obj_uuid}.0'), 'w', encoding='utf-8-sig') as f:
        f.write(object_module)

    # Form header
    form_inner_header = ["1", ["1", "9cd510cd-abfc-11d4-9434-004095e12fc7", form_obj_uuid], '"Форма"', ["0"], '""']
    form_obj_data = ["1", form_inner_header]
    form_container_info = ["1", container_uuid, "", form_obj_data]
    form_type_data_inner = [FORM_TYPE_UUID, "0"]
    form_include = [FORM_TYPE_UUID, form_container_info, "1", form_type_data_inner]
    form_includes_section = [FORM_TYPE_UUID, form_include]
    form_root = ["1", ["13", ["1", ["1", "9cd510cd-abfc-11d4-9434-004095e12fc7", form_obj_uuid], '"Форма"', ["0"], '""']]]
    form_header_data = ["13", ["1", form_root, "", form_includes_section]]
    brace_write([form_header_data], stage1, form_uuid)

    # Form elements
    form_elements = [
        [
            "4",
            ["49", "0","0","0","0","0","0","0","00000000-0000-0000-0000-000000000000","0"],
            "1", "","",["0","0"],["0","0"],["0","0"],["0","0"],"0","0",
        ],
        "0", ["0","0"], "0", "0", ["0"], "0", ["0"], "0", "0", "0", "0", "0", "0", "1", "0",
        ["0","0"], "0", ["0"], "0", ["0"], ["0","0"], ["0","0"], "0", "0", "0",
        ["0","0"], ["0"], "0", ["0"], ["0"], "0", "0", "0",
    ]
    brace_write(form_elements, stage1, f'{form_uuid}.1')

    # Form module code
    with open(os.path.join(stage1, f'{form_obj_uuid}.0'), 'w', encoding='utf-8-sig') as f:
        f.write(form_module)

    # versions
    file_list = ['root', 'version', 'copyinfo', file_uuid, f'{obj_uuid}.0', form_uuid, f'{form_uuid}.1', f'{form_obj_uuid}.0']
    versions = ["1", str(len(file_list) + 1), '""', make_uuid()]
    for fn in file_list:
        versions.append(f'"{fn}"')
        versions.append(make_uuid())
    brace_write([versions], stage1, 'versions')

    # Build container
    stage1_parent = os.path.join(work_dir, 'stage1')
    stage0 = os.path.join(work_dir, 'stage0')
    cb(stage1_parent, stage0)
    container_build(stage0, output_path, True)

    print(f"\nEPF built: {output_path} ({os.path.getsize(output_path)} bytes)")
    return True


if __name__ == '__main__':
    # Check for generic --src/--out mode
    if '--src' in sys.argv:
        src_idx = sys.argv.index('--src')
        src_dir = os.path.abspath(sys.argv[src_idx + 1])
        out_idx = sys.argv.index('--out') if '--out' in sys.argv else -1
        out_path = os.path.abspath(sys.argv[out_idx + 1]) if out_idx >= 0 else os.path.join(REPO_DIR, 'export.epf')
        ok = build_epf(src_dir, out_path)
    else:
        # Default: build all
        ok = True
        builds = [
            ('src/vitrina', 'vitrina_export.epf', 'ВыгрузкаВитриныНаХостинг'),
            ('src/test_runner', 'test_runner.epf', 'ТестВитрины'),
        ]
        for src_rel, out_name, name in builds:
            src_dir = os.path.join(REPO_DIR, src_rel)
            out_path = os.path.join(REPO_DIR, out_name)
            ok = build_epf(src_dir, out_path, name=name) and ok

    sys.exit(0 if ok else 1)