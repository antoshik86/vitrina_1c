#!/usr/bin/env python3
"""Build EPF external processing file for 1C:Enterprise using v8unpack."""
import os, shutil, sys, tempfile, uuid

REPO_DIR = r'C:\Users\ai86\AppData\Local\Temp\opencode\vitrina_1c'
VITRINA_DIR = os.path.join(REPO_DIR, '1c', 'vitrina_example')
OUTPUT_EPF = os.path.join(REPO_DIR, 'vitrina_export.epf')
WORK_DIR = os.path.join(tempfile.mkdtemp(), 'build_epf')

sys.path.insert(0, r'C:\Users\ai86\AppData\Local\Python\pythoncore-3.14-64\Lib\site-packages')
from v8unpack import helper
from v8unpack.json_container_decoder import JsonContainerDecoder

def make_uuid():
    return str(uuid.uuid4()).upper()

def load_bsl(path):
    with open(path, 'r', encoding='utf-8-sig') as f:
        return f.read()

def brace_write(data, dest_dir, file_name):
    """Write data as brace-format file."""
    helper.makedirs(dest_dir, exist_ok=True)
    decoder = JsonContainerDecoder(src_dir=dest_dir, file_name=file_name)
    raw_data = decoder.encode_root_object(data)
    decoder.write_data(dest_dir, file_name, raw_data)

def build_epf():
    print(f"Output: {OUTPUT_EPF}")

    # Load BSL modules
    obj_module = load_bsl(os.path.join(VITRINA_DIR, 'object_module.bsl'))
    form_module = load_bsl(os.path.join(VITRINA_DIR, 'form_module.bsl'))

    # UUIDs
    file_uuid = make_uuid()           # root uses this, and header file name
    obj_uuid = make_uuid()            # object module code file: {obj_uuid}.0
    container_uuid = make_uuid()      # container UUID in header
    form_uuid = make_uuid()           # form file UUID
    form_obj_uuid = make_uuid()       # form module code UUID

    obj_name = "ВыгрузкаВитриныНаХостинг"
    EDP_TYPE_UUID = 'c3831ec8-d8d5-4f93-8a22-f9bfae07327f'
    FORM_TYPE_UUID = 'd5b0e5ed-256d-401c-9c36-f630cafd8a62'

    # ===== STAGE 1: Build brace format files directly =====
    stage1 = os.path.join(WORK_DIR, 'stage1', '0')
    os.makedirs(stage1, exist_ok=True)

    # 1. root
    brace_write([["2", file_uuid, ""]], stage1, 'root')

    # 2. version  (must satisfy Decoder: version[0][0][0] >= 216 string, so [0][0] must be a list)
    brace_write([[["217", ["0", "803"]]]], stage1, 'version')

    # 3. copyinfo
    brace_write([["4", ["0"], ["0"], ["0"], ["0", "0"], ["0"]]], stage1, 'copyinfo')

    # 4. Header file (named by file_uuid)
    # Structure based on v8unpack decode paths:
    #   get_decode_header  → header_data[0][3][1][1][3][1]
    #   get_container_uuid → header_data[0][3][1][1][1]
    #   get_decode_includes → [header_data[0][3][1]]

    # Inner header (the part that get_decode_header returns)
    inner_header = [
        "1",                                 # [0] some field
        ["1", "9cd510cd-abfc-11d4-9434-004095e12fc7", obj_uuid],  # [1][2] = obj_uuid
        f'"{obj_name}"',                     # [2] quoted name
        ["0"],                               # [3] name2 (no localizations)
        '""',                                # [4] comment
    ]

    # Obj data (container_info[3])
    obj_data = [
        "1",                                  # [0] counter
        inner_header,                         # [1] the decoded header
    ]

    # Container info (include[1])
    container_info = [
        "1",                                  # [0] counter
        container_uuid,                       # [1] container UUID
        "",                                   # [2] empty
        obj_data,                             # [3] obj data
    ]

    # Include for Form type
    # include[2] = count_include_types, include[3+] = type data
    # type data: [type_uuid, count_objects, obj_0_uuid]
    form_type_data = [
        FORM_TYPE_UUID,                       # [0] Form type UUID
        "1",                                  # [1] count = 1 form
        form_uuid,                            # [2] UUID reference to form file
    ]

    include = [
        EDP_TYPE_UUID,                        # [0] ExternalDataProcessor type
        container_info,                       # [1] container info
        "1",                                  # [2] count_include_types = 1
        form_type_data,                       # [3] first type data (Form)
    ]

    # header_data[0][3] must satisfy:
    #   detect_version: header[0][3][0] = MetaDataTypes UUID
    #   get_decode_includes: [header_data[0][3][1]]
    #   get_decode_header: header_data[0][3][1][1][3][1]
    #   get_container_uuid: header_data[0][3][1][1][1]
    section = [
        EDP_TYPE_UUID,                        # [0] type UUID for detection
        include,                              # [1] include element
    ]

    # Full header_data
    header_data = [
        "2",                                  # [0] version
        file_uuid,                            # [1] file UUID
        "",                                   # [2] empty
        section,                              # [3] section
    ]

    # Wrap in outer array (decode returns [header_data])
    brace_write([header_data], stage1, file_uuid)

    # 5. Object module code file: {obj_uuid}.0
    with open(os.path.join(stage1, f'{obj_uuid}.0'), 'w', encoding='utf-8-sig') as f:
        f.write(obj_module)

    # 6. Form header file: {form_uuid}
    # Form.get_form_root expects header_data[0][1] to be a list
    #   with [0] = obj_version ('0' or '1')
    #   with [1] = form_root (when obj_version == '1')
    # form_root[1][1] = inner_header
    # form_root[1][0] = form format version
    form_inner_header = [
        "1",
        ["1", "9cd510cd-abfc-11d4-9434-004095e12fc7", form_obj_uuid],
        '"Форма"',
        ["0"],
        '""',
    ]

    form_obj_data = [
        "1",
        form_inner_header,
    ]

    form_container_info = [
        "1",
        container_uuid,
        "",
        form_obj_data,
    ]

    form_type_data_inner = [
        FORM_TYPE_UUID,
        "0",  # no sub-objects
    ]

    form_include = [
        FORM_TYPE_UUID,
        form_container_info,
        "1",
        form_type_data_inner,
    ]

    form_includes_section = [
        FORM_TYPE_UUID,
        form_include,
    ]

    form_root = [
        "1",                       # [0] some field
        [                          # [1] version + inner header
            "13",                  # [1][0] = form version (5, 7, 9, 12, 13, 14)
            [                      # [1][1] = inner_header for get_decode_header
                "1",
                ["1", "9cd510cd-abfc-11d4-9434-004095e12fc7", form_obj_uuid],
                '"Форма"',
                ["0"],
                '""'
            ]
        ]
    ]

    form_header_data = [
        "13",                      # [0] form version
        [                          # [1] MUST be a list
            "1",                   # [1][0] = obj_version
            form_root,             # [1][1] = form_root
        ],
        "",                        # [2]
        form_includes_section,     # [3]
    ]

    brace_write([form_header_data], stage1, form_uuid)

    # 7. Form elements file: {form_uuid}.1
    # Minimal form elements data - an empty form
    form_elements = [
        [
            "4",                   # version
            [
                "49",              # elements count
                "0", "0", "0", "0", "0", "0", "0",
                "00000000-0000-0000-0000-000000000000",
                "0",
            ],
            "1",                   # options
            "",                    # empty
            "",                    # empty
            ["0", "0"],            # some list
            ["0", "0"],            # some list
            ["0", "0"],            # some list
            ["0", "0"],            # some list
            "0",
            "0",
        ],
        "0",                       # short
        ["0", "0"],                # settings
        "0",
        "0",
        ["0"],
        "0",
        ["0"],
        "0",
        "0",
        "0",
        "0",
        "0",
        "0",
        "1",                       # auto
        "0",
        ["0", "0"],
        "0",
        ["0"],
        "0",
        ["0"],
        ["0", "0"],
        ["0", "0"],
        "0",
        "0",
        "0",
        ["0", "0"],
        ["0"],
        "0",
        ["0"],
        ["0"],
        "0",
        "0",
        "0",
    ]
    brace_write(form_elements, stage1, f'{form_uuid}.1')

    # 8. Form module code file: {form_obj_uuid}.0
    with open(os.path.join(stage1, f'{form_obj_uuid}.0'), 'w', encoding='utf-8-sig') as f:
        f.write(form_module)

    # 9. versions file - list all files with UUIDs
    file_list = [
        'root', 'version', 'copyinfo',
        file_uuid, f'{obj_uuid}.0',
        form_uuid, f'{form_uuid}.1', f'{form_obj_uuid}.0',
    ]
    versions = ["1", str(len(file_list) + 1), '""', make_uuid()]
    for fn in file_list:
        versions.append(f'"{fn}"')
        versions.append(make_uuid())

    brace_write([versions], stage1, 'versions')

    print(f"Stage1 files: {os.listdir(stage1)}")

    # ===== BUILD CONTAINER =====
    from v8unpack.container_writer import compress_and_build as cb, build as container_build

    stage1_parent = os.path.join(WORK_DIR, 'stage1')
    stage0 = os.path.join(WORK_DIR, 'stage0')
    cb(stage1_parent, stage0)
    container_build(stage0, OUTPUT_EPF, True)

    print(f"\nEPF built: {OUTPUT_EPF} ({os.path.getsize(OUTPUT_EPF)} bytes)")
    return True

if __name__ == '__main__':
    sys.exit(0 if build_epf() else 1)
