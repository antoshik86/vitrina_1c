#!/usr/bin/env python3
"""Build EPF using v8unpack JSON format."""
import json, os, shutil, sys, tempfile, uuid

REPO_DIR = os.path.abspath(sys.argv[1] if len(sys.argv) > 1
              and not sys.argv[1].startswith('--') else os.path.dirname(__file__))

for p in [
    os.path.join(REPO_DIR, '_venv', 'Lib', 'site-packages'),
    os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Python', 'pythoncore-3.14-64', 'Lib', 'site-packages'),
    os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Programs', 'Python', 'Python314', 'Lib', 'site-packages'),
]:
    if os.path.isdir(p):
        sys.path.insert(0, p)
from v8unpack.v8unpack import build as v8_build


def make_uuid():
    return str(uuid.uuid4()).upper()


def load_bsl(path):
    with open(path, 'r', encoding='utf-8-sig') as f:
        return f.read()


def build_epf(src_dir, output_path, name='Обработка', name2_en='Processing',
              form_module='', object_module=''):
    """Build EPF from source BSL files using v8unpack JSON format."""

    if not form_module:
        form_module = load_bsl(os.path.join(src_dir, 'form_module.bsl'))
    if not object_module:
        object_module = load_bsl(os.path.join(src_dir, 'object_module.bsl'))

    print(f"Building: {output_path}")

    # UUIDs
    file_uuid = make_uuid()
    obj_uuid = make_uuid()
    container_uuid = make_uuid()
    form_uuid = make_uuid()
    form_obj_uuid = make_uuid()

    EDP_TYPE = 'c3831ec8-d8d5-4f93-8a22-f9bfae07327f'
    FORM_TYPE = 'd5b0e5ed-256d-401c-9c36-f630cafd8a62'
    CODE_TYPE = '9cd510cd-abfc-11d4-9434-004095e12fc7'

    # Create temp directory with v8unpack structure
    work_dir = os.path.join(tempfile.mkdtemp(), 'build_epf')

    # --- ExternalDataProcessor.json ---
    header = [
        "2",
        file_uuid,
        "",
        [
            EDP_TYPE,
            [
                EDP_TYPE,
                [
                    "1",
                    container_uuid,
                    "",
                    [
                        "1",
                        [
                            "1",
                            [
                                "1",
                                CODE_TYPE,
                                obj_uuid,
                            ],
                            json.dumps(name, ensure_ascii=False),
                            ["0"],
                            '""',
                        ]
                    ]
                ],
                "1",
                [
                    FORM_TYPE,
                    "1",
                    form_uuid,
                ]
            ]
        ]
    ]

    edp_json = {
        "root": True,
        "file_uuid": file_uuid,
        "uuid": obj_uuid,
        "name": name,
        "name2": {"en": name2_en},
        "comment": "",
        "header": [header],
        "v8unpack": "1.2.6",
        "version": [[["217", ["0", "803"]]]],
        "copyinfo": [["4", ["0"], ["0"], ["0"], ["0", "0"], ["0"]]],
        "form1": None,
        "code_info_obj": "file",
        "code_encoding_obj": "utf-8-sig",
        "obj_version": "802",
    }

    os.makedirs(work_dir, exist_ok=True)
    with open(os.path.join(work_dir, 'ExternalDataProcessor.json'), 'w', encoding='utf-8') as f:
        json.dump(edp_json, f, indent=2, ensure_ascii=False)

    # Object module BSL
    with open(os.path.join(work_dir, 'ExternalDataProcessor.obj.bsl'), 'w', encoding='utf-8-sig') as f:
        f.write(object_module)

    # --- Form directory ---
    form_dir = os.path.join(work_dir, 'Form', 'Форма')
    os.makedirs(form_dir, exist_ok=True)

    form_header = [
        "13",
        [
            "1",
            [
                "1",
                [  # form_root
                    "13",
                    [
                        "1",
                        [
                            "1",
                            CODE_TYPE,
                            "в отдельном файле",
                        ],
                        json.dumps('Форма', ensure_ascii=False),
                        ["0"],
                        '""',
                    ]
                ],
                None,
                [  # include section
                    FORM_TYPE,
                    [
                        FORM_TYPE,
                        [
                            "1",
                            container_uuid,
                            "",
                            [
                                "1",
                                [
                                    "1",
                                    [
                                        "1",
                                        CODE_TYPE,
                                        form_obj_uuid,
                                    ],
                                    json.dumps('Форма', ensure_ascii=False),
                                    ["0"],
                                    '""',
                                ]
                            ]
                        ],
                        "1",
                        [
                            FORM_TYPE,
                            "0",
                        ]
                    ]
                ]
            ]
        ]
    ]

    form_json = {
        "name": "Форма",
        "name2": {},
        "comment": "",
        "header": [form_header],
        "Тип формы": "0",
        "form": [[]],
        "code_info_obj": "file",
        "code_encoding_obj": "utf-8-sig",
        "Версия элементов формы": "",
        "obj_version": "13",
    }

    with open(os.path.join(form_dir, 'Form.json'), 'w', encoding='utf-8') as f:
        json.dump(form_json, f, indent=2, ensure_ascii=False)

    # Form identity
    form_id = {"uuid": form_obj_uuid}
    with open(os.path.join(form_dir, 'Form.id.json'), 'w', encoding='utf-8') as f:
        json.dump(form_id, f, indent=2)

    # Form elements (empty)
    form_elem = {
        "params": [],
        "props": [],
        "commands": [],
        "tree": [],
        "data": {},
    }
    with open(os.path.join(form_dir, 'Form.elem.json'), 'w', encoding='utf-8') as f:
        json.dump(form_elem, f, indent=2)

    # Form module BSL
    with open(os.path.join(form_dir, 'Form.obj.bsl'), 'w', encoding='utf-8-sig') as f:
        f.write(form_module)

    # Build EPF using v8unpack
    output_dir = os.path.dirname(output_path) or '.'
    os.makedirs(output_dir, exist_ok=True)
    v8_build(work_dir, output_path)

    size = os.path.getsize(output_path)
    print(f"EPF built: {output_path} ({size} bytes)")
    return True


if __name__ == '__main__':
    if '--src' in sys.argv:
        src_idx = sys.argv.index('--src')
        src_dir = os.path.abspath(sys.argv[src_idx + 1])
        out_idx = sys.argv.index('--out') if '--out' in sys.argv else -1
        out_path = os.path.abspath(sys.argv[out_idx + 1]) if out_idx >= 0 else os.path.join(REPO_DIR, 'export.epf')
        ok = build_epf(src_dir, out_path)
    else:
        ok = True
        builds = [
            ('src/vitrina', 'vitrina_export.epf', 'ВыгрузкаВитриныНаХостинг', 'CatalogExport'),
            ('src/test_runner', 'test_runner.epf', 'ТестВитрины', 'TestRunner'),
        ]
        for src_rel, out_name, name, name_en in builds:
            src_dir = os.path.join(REPO_DIR, src_rel)
            out_path = os.path.join(REPO_DIR, out_name)
            ok = build_epf(src_dir, out_path, name=name, name2_en=name_en) and ok

    sys.exit(0 if ok else 1)
