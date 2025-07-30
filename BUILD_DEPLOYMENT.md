# Build and Deployment Guide

This guide explains how to build and deploy the lsdembed package to PyPI.

## Quick Deployment

For a complete automated build and deployment, simply run:

```bash
./build.sh
```

This script will:
1. ✅ Check all dependencies
2. 🧹 Clean previous builds
3. 📦 Build source distribution
4. 🔧 Build wheel
5. 🛠️ Repair wheel with proper manylinux tags
6. 🚀 Upload to PyPI (with confirmation)

## Prerequisites

### System Dependencies
- Python 3.8+
- pip
- patchelf (automatically installed if missing)

### PyPI Configuration
You need to configure your PyPI credentials. Create `~/.pypirc`:

```ini
[distutils]
index-servers = pypi

[pypi]
username = __token__
password = pypi-your-api-token-here
```

Or use:
```bash
twine configure
```

## Manual Steps

If you prefer to run steps manually:

### 1. Install Dependencies
```bash
pip install build twine auditwheel
sudo apt-get install patchelf  # Linux only
```

### 2. Clean Previous Builds
```bash
rm -rf dist/ build/ wheelhouse/ *.egg-info/
```

### 3. Build Package
```bash
python -m build --sdist --wheel
```

### 4. Repair Wheel (Linux)
```bash
auditwheel repair dist/*linux_x86_64.whl
cp wheelhouse/*.whl dist/
rm dist/*linux_x86_64.whl
```

### 5. Upload to PyPI
```bash
twine upload dist/* --verbose
```

## Troubleshooting

### Common Issues

**1. Platform Tag Error**
```
Binary wheel has an unsupported platform tag 'linux_x86_64'
```
**Solution:** Use `auditwheel repair` to convert to manylinux tags (handled automatically by build.sh)

**2. Missing patchelf**
```
Cannot find required utility `patchelf` in PATH
```
**Solution:** Install patchelf: `sudo apt-get install patchelf`

**3. Authentication Error**
```
403 Forbidden
```
**Solution:** Check your PyPI token in `~/.pypirc`

### Build Script Options

The build script supports these environment variables:

```bash
# Skip upload confirmation
SKIP_CONFIRM=1 ./build.sh

# Dry run (build but don't upload)
DRY_RUN=1 ./build.sh
```

## CI/CD Integration

For automated deployments, you can use the GitHub Actions workflow in `.github/workflows/build-wheels.yml` or integrate the build script into your CI pipeline:

```yaml
- name: Build and Deploy
  run: |
    chmod +x build.sh
    SKIP_CONFIRM=1 ./build.sh
  env:
    TWINE_USERNAME: __token__
    TWINE_PASSWORD: ${{ secrets.PYPI_API_TOKEN }}
```

## Version Management

Update the version in `pyproject.toml` before building:

```toml
[project]
version = "0.2.1"  # Update this
```

The build script will automatically detect and use this version.