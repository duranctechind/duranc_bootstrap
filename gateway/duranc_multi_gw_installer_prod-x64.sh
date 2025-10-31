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
AFqUSQAA
__OBF_B64_PAYLOAD_END__
