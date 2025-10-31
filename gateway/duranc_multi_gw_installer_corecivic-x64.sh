#!/usr/bin/env bash
# Self-decoding installer wrapper
# - Contains base64(+gzip) payload, optionally AES-256-CBC encrypted
# - Decodes, optionally decrypts, ungzips, then execs payload under bash
#
# Runtime:
#   sudo bash ./THIS_SCRIPT.sh
#
set -euo pipefail

need() {
  command -v "$1" >/dev/null 2>&1
}

dec_b64() {
  # Decode base64 from stdin to stdout using available tools
  if need base64; then base64 -d 2>/dev/null || base64 --decode; return; fi
  if need openssl; then openssl base64 -d; return; fi
  if need python3; then python3 - <<'PY'
import sys, base64
sys.stdout.buffer.write(base64.b64decode(sys.stdin.buffer.read()))
PY
  return; fi
  if need python; then python - <<'PY'
import sys, base64
sys.stdout.write(base64.b64decode(sys.stdin.read()))
PY
  return; fi
  if need perl; then perl -MMIME::Base64 -ne 'print decode_base64($_)'; return; fi
  if need busybox; then busybox base64 -d; return; fi
  echo "No base64 decoder found." >&2
  exit 1
}

dec_gzip() {
  # Decompress gzip from stdin to stdout
  if need gzip; then gzip -dc; return; fi
  if need busybox; then busybox gzip -dc; return; fi

  # Python/zlib fallback
  if need python3; then python3 - <<'PY'
import sys, zlib
sys.stdout.buffer.write(zlib.decompress(sys.stdin.buffer.read(), 16+zlib.MAX_WBITS))
PY
  return; fi
  if need python; then python - <<'PY'
import sys, zlib
sys.stdout.write(zlib.decompress(sys.stdin.read(), 16+zlib.MAX_WBITS))
PY
  return; fi

  echo "No gzip decompressor found." >&2
  exit 1
}

dec_aes() {
  # Decrypt AES-256-CBC with OpenSSL from stdin to stdout using OBF_PASSPHRASE
  if ! need openssl; then
    echo "OpenSSL not available for AES decryption." >&2
    exit 1
  fi
  pass="${OBF_PASSPHRASE:-}"
  if [ -z "$pass" ]; then
    printf "Enter passphrase: " >&2
    stty -echo 2>/dev/null || true
    IFS= read -r pass || true
    stty echo 2>/dev/null || true
    echo >&2
  fi
  # pbkdf2 here must match obfuscator mode
  OPENSSL_PASS="pass:$pass" exec openssl enc -d -aes-256-cbc -pbkdf2 -pass "$OPENSSL_PASS"
}

# Metadata injected below
OBF_ENCRYPTED="0"

# Payload markers
PAYLOAD_B64_START="__OBF_B64_PAYLOAD_START__"
PAYLOAD_B64_END="__OBF_B64_PAYLOAD_END__"

extract_payload() {
  # Pull only the lines between markers
  awk "/$PAYLOAD_B64_START/{flag=1;next}/$PAYLOAD_B64_END/{flag=0}flag" "$0"
}

run_payload() {
  # Decode pipeline:
  #   base64 -> (optional AES decrypt) -> gunzip -> bash -s --
  #
  # NOTE: we FORCE bash here. That fixes 'set -o pipefail' problems
  #       in the original installer script.
  if [ "$OBF_ENCRYPTED" = "1" ]; then
    extract_payload | dec_b64 | dec_aes | dec_gzip | /usr/bin/env bash -s -- "$@"
  else
    extract_payload | dec_b64 | dec_gzip | /usr/bin/env bash -s -- "$@"
  fi
}

run_payload "$@"
exit 0

__OBF_B64_PAYLOAD_START__
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
5BOwO38B48a4r5lJAAA=
__OBF_B64_PAYLOAD_END__
