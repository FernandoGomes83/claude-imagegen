#!/usr/bin/env bash
# Generate an image through the Codex CLI in headless mode and guarantee the
# final file exists at the requested path.
#
# Contract: stdout = absolute path of the generated file (nothing else).
#           stderr = diagnostics. Exit != 0 = no image on disk.
#
# Part of https://github.com/FernandoGomes83/claude-imagegen

set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat >&2 <<'EOF'
usage: codex-image.sh --prompt "image description" [--out /path/final.png] [options]

  -p, --prompt TEXT     Image description.
  -f, --prompt-file F   Read the prompt from a file ('-' for stdin).
                        If the file contains ``` fences, the FIRST fenced block is used.
                        One of --prompt / --prompt-file is required.
  -o, --out PATH        Final file. Default: ./<slug>-<timestamp>.png
      --ref FILE        Reference image for style/identity (repeatable). Say in the
                        prompt what must stay the same, not just what changes.
      --log PATH        Where to write the event log. Default: a temp file.
      --keep-log        Keep the log even on success.
      --model MODEL     Codex model. Default: whatever your config.toml uses.
  -h, --help            This help.

Notes:
  - Generation takes ~1-2 minutes. Run it in the background.
  - Uses the Codex built-in image_gen tool (your ChatGPT account, no OPENAI_API_KEY).
EOF
  exit 1
}

PROMPT=""
PROMPT_FILE=""
OUT=""
LOG=""
KEEP_LOG=0
MODEL=""
REFS=()

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--prompt) [ $# -ge 2 ] || die "--prompt requires a value"; PROMPT="$2"; shift 2 ;;
    -f|--prompt-file) [ $# -ge 2 ] || die "--prompt-file requires a value"; PROMPT_FILE="$2"; shift 2 ;;
    -o|--out)    [ $# -ge 2 ] || die "--out requires a value";    OUT="$2";    shift 2 ;;
    --ref)       [ $# -ge 2 ] || die "--ref requires a value";    REFS+=("$2"); shift 2 ;;
    --log)       [ $# -ge 2 ] || die "--log requires a value";    LOG="$2";    shift 2 ;;
    --model)     [ $# -ge 2 ] || die "--model requires a value";  MODEL="$2";  shift 2 ;;
    --keep-log)  KEEP_LOG=1; shift ;;
    -h|--help)   usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

if [ -n "$PROMPT_FILE" ]; then
  [ -n "$PROMPT" ] && die "use --prompt OR --prompt-file, not both"
  if [ "$PROMPT_FILE" = "-" ]; then
    PROMPT=$(cat)
  else
    [ -f "$PROMPT_FILE" ] || die "prompt file does not exist: $PROMPT_FILE"
    PROMPT=$(cat "$PROMPT_FILE")
  fi
  # Prompt files often keep the real prompt inside a ``` fence, and may hold more
  # than one (e.g. an AI prompt plus a human-readable variant). Convention: the
  # first fenced block is the prompt. No fence -> use the whole file.
  fences=$(printf '%s\n' "$PROMPT" | grep -c '^```' || true)
  if [ "$fences" -ge 2 ]; then
    PROMPT=$(printf '%s\n' "$PROMPT" | awk '/^```/{n++; next} n==1')
  fi
  [ -n "${PROMPT//[[:space:]]/}" ] || die "empty prompt in: $PROMPT_FILE"
fi

[ -n "$PROMPT" ] || usage
command -v codex >/dev/null 2>&1 || die "codex not found in PATH. Install the Codex CLI first"

for ref in ${REFS+"${REFS[@]}"}; do
  [ -f "$ref" ] || die "reference image does not exist: $ref"
done

# Default output: prompt slug + timestamp, in the current directory.
if [ -z "$OUT" ]; then
  slug=$(printf '%s' "$PROMPT" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -c 'a-z0-9' '-' \
    | tr -s '-' \
    | sed -e 's/^-//' -e 's/-$//' \
    | cut -c1-40)
  [ -n "$slug" ] || slug="image"
  OUT="$PWD/${slug}-$(date +%Y%m%d-%H%M%S).png"
fi

# Absolute path: Codex needs an unambiguous destination.
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
OUT_DIR=$(dirname "$OUT")
mkdir -p "$OUT_DIR" || die "could not create output directory: $OUT_DIR"
OUT_DIR=$(cd "$OUT_DIR" && pwd)
OUT="$OUT_DIR/$(basename "$OUT")"

[ -e "$OUT" ] && die "file already exists, refusing to overwrite: $OUT"

# mktemp templates must END with the X's: BSD mktemp does not accept a suffix
# after them, and would silently create a file literally named ...-XXXXXX.log,
# so concurrent runs would share one file.
if [ -z "$LOG" ]; then
  LOG=$(mktemp "${TMPDIR:-/tmp}/codex-image-log-XXXXXX")
fi
MSG_FILE=$(mktemp "${TMPDIR:-/tmp}/codex-image-msg-XXXXXX")

cleanup() {
  rm -f "$MSG_FILE"
  if [ "$KEEP_LOG" -eq 0 ] && [ "${SUCCESS:-0}" -eq 1 ]; then
    rm -f "$LOG"
  fi
}
trap cleanup EXIT

# Naming the destination is what makes this work headlessly.
# Without a named destination, Codex's imagegen skill treats the request as
# preview-only and "renders it inline", which does not exist outside the TUI.
# The run then exits 0 with an empty final message and no file anywhere.
REF_BLOCK=""
if [ ${#REFS[@]} -gt 0 ]; then
  REF_BLOCK=$'\nReference images are attached to this prompt: use them for style/composition/subject guidance.'
fi

FULL_PROMPT="Use the imagegen skill with the built-in image_gen tool to generate this image:

${PROMPT}
${REF_BLOCK}
Output requirements (mandatory):
- This is NOT a preview request. The final file MUST exist on disk.
- Save or copy the final file EXACTLY to: ${OUT}
- Do not use the fallback CLI and do not ask for OPENAI_API_KEY; use the built-in tool.
- Do not ask for confirmation; run to completion.
- When done, reply with ONLY the absolute path of the saved file, nothing else."

# `-i/--image` is variadic (<FILE>...), so it swallows every following argument,
# including the positional prompt. Keep the -i flags first: the next flag stops
# each one, and the prompt stays safely at the end.
CODEX_ARGS=(exec)
for ref in ${REFS+"${REFS[@]}"}; do CODEX_ARGS+=(-i "$ref"); done
CODEX_ARGS+=(--json --sandbox workspace-write --skip-git-repo-check
             -C "$OUT_DIR" -o "$MSG_FILE")
[ -n "$MODEL" ] && CODEX_ARGS+=(-m "$MODEL")

set +e
codex "${CODEX_ARGS[@]}" "$FULL_PROMPT" >"$LOG" 2>&1
CODEX_EXIT=$?
set -e

# The file on disk is the source of truth, not the model's answer.
# Codex exits 0 even when it generated no image at all.
if [ ! -s "$OUT" ]; then
  {
    printf 'error: Codex finished (exit %s) but no image appeared at:\n  %s\n\n' "$CODEX_EXIT" "$OUT"
    printf "Codex's final message:\n"
    if [ -s "$MSG_FILE" ]; then sed 's/^/  /' "$MSG_FILE"; else printf '  (empty: the classic symptom of a generation treated as preview)\n'; fi
    printf '\nfull log: %s\n' "$LOG"
  } >&2
  KEEP_LOG=1
  exit 1
fi

# Make sure it is really a raster and not text/HTML that landed there.
# -a is required: without it, BSD grep treats binary input as non-matching and
# rejects every valid PNG.
if ! head -c 12 "$OUT" | LC_ALL=C grep -qaE 'PNG|JFIF|WEBP|Exif'; then
  printf 'error: %s exists but does not look like a valid image\nlog: %s\n' "$OUT" "$LOG" >&2
  KEEP_LOG=1
  exit 1
fi

SUCCESS=1
printf '%s\n' "$OUT"
