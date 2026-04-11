import zipfile, glob, os, sys

tmpdir, ov_lib = os.environ['_TMPDIR'], os.environ['_OV_LIB']
whls = glob.glob(os.path.join(tmpdir, 'ragfs_python-*.whl'))
assert whls, 'maturin produced no wheel'
with zipfile.ZipFile(whls[0]) as zf:
    for name in zf.namelist():
        bn = os.path.basename(name)
        if bn.startswith('ragfs_python') and (bn.endswith('.so') or bn.endswith('.pyd')):
            dst = os.path.join(ov_lib, bn)
            with zf.open(name) as src, open(dst, 'wb') as f:
                f.write(src.read())
            os.chmod(dst, 0o755)
            print(f'ragfs-python: extracted {bn} -> {dst}')
            sys.exit(0)
print('WARNING: No ragfs_python .so/.pyd in wheel')
sys.exit(1)
