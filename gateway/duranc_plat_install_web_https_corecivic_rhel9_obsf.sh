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
__OBF_B64_PAYLOAD_END__
