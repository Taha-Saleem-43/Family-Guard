# FamilyGuard introduction and icon

Original programmatically drawn assets; no stock footage, remote playback, or paid service.

The silent introduction is a six-second, 720 × 576 H.264 MP4 at 24 fps. Flutter bundles its poster for reduced motion and unavailable video playback. The player pauses in the background and is disposed when leaving the introduction.

The teal family location mark is exported for Android legacy/adaptive launchers and the existing iOS icon catalog. The previews use sample data and never start tracking or dispatch SOS.

Regenerate from the repository root using the project virtual environment:

```powershell
.venv/Scripts/python.exe -m pip install --cache-dir .cache/pip -r scripts/intro-assets-requirements.txt
.venv/Scripts/python.exe scripts/generate_intro_assets.py
```
