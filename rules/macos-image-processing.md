# macOS Image Processing

## sips and filenames with spaces

`sips` silently skips files whose paths contain spaces, even with proper shell quoting. The exit code is still 0. Root cause is a bug in sips's argument parsing.

**Never pass filenames with spaces directly to sips.** Always use the temp-file wrapper below.

**Workaround:** copy the file to a no-space temp path first, then process with sips, then clean up. The function also skips upscaling (never makes images larger than they already are).

```bash
resize_image() {
  local src="$1" dst="$2" max_px="${3:-800}"
  local long_side
  long_side=$(sips -g pixelWidth -g pixelHeight "$src" | awk '/pixel/{print $2}' | sort -n | tail -1)
  if [ "$long_side" -le "$max_px" ]; then
    cp "$src" "$dst"
    return
  fi
  local tmp="/tmp/sips_tmp_$RANDOM.png"
  cp "$src" "$tmp"
  sips -Z "$max_px" "$tmp" --out "$dst" > /dev/null 2>&1
  rm -f "$tmp"
}
```

## sips resize rules

- `-Z 800` resizes the longest side to 800px, preserving aspect ratio
- Never upscale: only call sips when `long_side > 800`
- Check dimensions first: `sips -g pixelWidth -g pixelHeight file.png`

## Iterating over files with non-standard characters (NNBSP)

macOS screenshot filenames contain a narrow no-break space (U+202F, bytes `e2 80 af`) before "AM"/"PM". Hardcoded strings with a regular space won't match.

**Always use glob expansion** to get actual filenames — never hardcode screenshot names:

```bash
for src in /path/to/dir/Screenshot*.png; do
  # $src contains the real bytes from the filesystem
  process "$src"
done
```
