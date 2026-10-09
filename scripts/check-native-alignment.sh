#!/usr/bin/env bash
set -euo pipefail

# Use Android's LLVM and zipalign tools; do not modify or re-sign the APK.
apk="${1:?APK path required}"
objdump="${2:?Android NDK llvm-objdump path required}"
zipalign="${3:?Android build-tools zipalign path required}"
[[ -f "$apk" && -x "$objdump" && -x "$zipalign" ]] || {
  echo 'APK or Android verification tools are missing' >&2
  exit 1
}
mkdir -p .cache
validation_dir="$(mktemp -d "$PWD/.cache/native-alignment.XXXXXX")"
unzip -q "$apk" 'lib/arm64-v8a/*.so' -d "$validation_dir"
mapfile -d '' libraries < <(find "$validation_dir/lib/arm64-v8a" -type f -name '*.so' -print0)
[[ ${#libraries[@]} -gt 0 ]] || { echo 'No ARM64 shared libraries found' >&2; exit 1; }
for library in "${libraries[@]}"; do
  if ! "$objdump" -p "$library" | awk '
    /LOAD/ {
      count++;
      split($NF, alignment, /\*\*/);
      if (alignment[1] != 2 || alignment[2] + 0 < 14) bad = 1;
    }
    END { if (count == 0 || bad) exit 1; }
  '; then
    echo "16 KB ELF alignment failed: ${library##*/}" >&2
    "$objdump" -p "$library"
    exit 1
  fi
  echo "16 KB ELF alignment passed: ${library##*/}"
done
"$zipalign" -c -P 16 -v 4 "$apk" > "$validation_dir/zipalign.log"
tail -n 1 "$validation_dir/zipalign.log"
echo "Verified ${#libraries[@]} ARM64 shared libraries and APK ZIP alignment"
