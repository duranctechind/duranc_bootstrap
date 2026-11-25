// ---- endpoints ----
const portal = "http://18.18.18.5 https://devllm.duranc.com/api/generate";
const portal_host = "18.18.18.5";
const messenger = "http://18.18.18.5:81";
const ws_messenger = "ws://18.18.18.5:81";
const notifier = "http://18.18.18.5:83";
const streamer = "http://18.18.18.5:82";
const ws_streamer = "ws://18.18.18.5:82";
const mediamtx_streamer = "http://18.18.18.5:8888";
const vllm_host = "https://devllm.duranc.com/api/generate";
const rtmp_streamer = "http://18.18.18.5:8888";
const extra_frame = "";

// every source once per directive, whatever the endpoints above share
const src = (...parts) => [...new Set(parts.join(' ').split(/\s+/).filter(Boolean))].join(' ');
const arr = (...parts) => src(...parts).split(' ');

// ---- allowed domains ----
// Origins a browser loads the portal from: the CORS allow-list (index.js, and the messenger's
// ALLOWED_ORIGINS via environment.js). Scheme included - an Origin header always carries it. Never the
// LLM hosts (vllm_host, rtmp_streamer). Keep in step with logos_map.
const portal_origins = [
   "http://18.18.18.5"
];
// Host headers that get the nonce-based script policy.
const portal_hosts = [
   "18.18.18.5"
];

const PAYPAL_FRAME = "'self' about: https://www.sandbox.paypal.com https://www.paypal.com https://*.paypal.com";
const IMG = "'self' data: blob: https://www.paypalobjects.com https://t.paypal.com https://maps.googleapis.com https://maps.gstatic.com https://optimizationguide-pa.googleapis.com";
const FONT = src("'self' data: https://optimizationguide-pa.googleapis.com");
const STYLE = src("'self' 'unsafe-inline' https://optimizationguide-pa.googleapis.com https://vjs.zencdn.net https://cdn.jsdelivr.net");
const SCRIPT = src("'self' 'unsafe-eval' https://www.paypalobjects.com https://www.paypal.com https://*.paypal.com https://maps.googleapis.com https://maps.gstatic.com https://optimizationguide-pa.googleapis.com https://cdn.jsdelivr.net");

module.exports = {
   portal: portal,
   portal_host: portal_host,
   portal_hosts: portal_hosts,
   portal_origins: portal_origins,
   // branding per portal host (images/<file>); unlisted hosts get duranc.png
   logos_map: {
      "18.18.18.5": "duranc.png"
   },
   accessControlOrigin: [portal, streamer],

   // ---- legacy array form (kept for any reader of the top-level keys) ----
   defaultSrc: ["'self'"],
   frameSrc: arr("'self' https://www.sandbox.paypal.com https://www.paypal.com", extra_frame, streamer, rtmp_streamer),
   imgSrc: arr(IMG),
   mediaSrc: arr("'self' data: blob:", messenger, streamer, ws_messenger, ws_streamer, rtmp_streamer),
   fontSrc: arr(FONT),
   styleSrc: arr(STYLE),
   scriptSrc: arr(SCRIPT),
   connectSrc: arr("'self' data: blob: https://www.sandbox.paypal.com https://www.paypalobjects.com https://www.paypal.com https://api.paypal.com https://maps.googleapis.com", messenger, streamer, ws_messenger, ws_streamer, notifier, mediamtx_streamer, vllm_host, rtmp_streamer),
   scriptSrcAttr: ["'self'", "'unsafe-inline'"],
   formAction: ["'self'"],
   frameAncestors: ["'self'"],
   manifestSrc: ["'self'"],
   baseUri: ["'self'"],
   workerSrc: ["'self'"],

   // ---- pages (index.js; script-src gets the nonce, or 'unsafe-inline' off the portal hosts) ----
   cspOptions: {
      defaultSrc: "'self'",
      frameSrc: src(PAYPAL_FRAME, extra_frame, streamer, mediamtx_streamer, rtmp_streamer),
      imgSrc: IMG,
      mediaSrc: src("'self' data: blob:", messenger, streamer, ws_messenger, ws_streamer, mediamtx_streamer, rtmp_streamer),
      fontSrc: FONT,
      connectSrc: src("'self' data: blob: https://*.paypal.com https://www.paypalobjects.com https://maps.googleapis.com", messenger, streamer, ws_messenger, ws_streamer, notifier, mediamtx_streamer, vllm_host, rtmp_streamer),
      scriptSrcAttr: "'self' 'unsafe-inline'",
      formAction: "'self'",
      frameAncestors: "'self'",
      objectSrc: "'none'",
      styleSrc: STYLE,
      scriptSrc: SCRIPT,
      manifestSrc: "'self'",
      baseUri: "'self'",
      // index.js emits "worker-src " + workerSrc unconditionally: never leave it out
      workerSrc: "'self' blob:"
   },

   // ---- static files served by express.static ----
   cspOptionsStr:
      "default-src 'self'; " +
      "frame-src " + src("'self' https://www.sandbox.paypal.com https://www.paypal.com", extra_frame, streamer, rtmp_streamer) + "; " +
      "img-src " + IMG + "; " +
      "media-src " + src("'self' data: blob:", messenger, streamer, ws_messenger, ws_streamer, mediamtx_streamer, rtmp_streamer) + "; " +
      "font-src " + FONT + "; " +
      "connect-src " + src("'self' data: blob: https://www.sandbox.paypal.com https://www.paypalobjects.com https://www.paypal.com https://api.paypal.com https://maps.googleapis.com", messenger, streamer, ws_messenger, ws_streamer, notifier, mediamtx_streamer, rtmp_streamer) + "; " +
      "script-src-attr 'self' 'unsafe-inline'; " +
      "form-action 'self'; " +
      "frame-ancestors 'self'; " +
      "object-src 'none'; " +
      "style-src " + STYLE + "; " +
      "script-src " + src("'self' 'unsafe-inline'", SCRIPT) + "; " +
      "manifest-src 'self'; " +
      "worker-src 'self' blob:; " +
      "base-uri 'self';",

   // ---- not-found page (index.js catch-all app.get('*')) ----
   staticOptions:
      "default-src 'self'; " +
      "script-src 'self'; " +
      "style-src 'self'; " +
      "img-src 'self'; " +
      "connect-src 'self'; " +
      "font-src 'self'; " +
      "object-src 'none'; " +
      "frame-src 'none'; " +
      "form-action 'self'; " +
      "frame-ancestors 'none'; " +
      "media-src 'self'; " +
      "manifest-src 'self'; " +
      "base-uri 'self'; " +
      "worker-src 'self';"
};
