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
s9mUSQAA
__OBF_B64_PAYLOAD_END__
