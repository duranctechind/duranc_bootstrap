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
AA==
__OBF_B64_PAYLOAD_END__
