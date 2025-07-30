//EDIT IP ADDRESS IF NECESSARY
const portal = "http://18.18.18.17 http://18.18.19.30:8000";
const portal_host = "18.18.18.17";
const messenger = "http://18.18.18.17:81";
const ws_messenger= "ws://18.18.18.17:81";
const notifier = "http://18.18.18.17:83";
const streamer = "http://18.18.18.17:82";
const ws_streamer = "ws://18.18.18.17:82";
const mediamtx_streamer = "http://18.18.18.17:8888";
const rtmp_streamer = "http://18.18.18.17:8888"
const vllm_host = "http://18.18.19.30:8000"
//STOP EDITING

//DO NOT EDIT BELOW CONTENT
module.exports = {
   portal: portal,
   portal_host: portal_host,
   accessControlOrigin: [portal, , streamer],
   defaultSrc: ["'self'"],
   frameSrc: ["'self'", "https://www.sandbox.paypal.com", "https://www.paypal.com", streamer, rtmp_streamer],
   imgSrc: ["'self'", "data:", "blob:", "https://www.paypalobjects.com", "https://t.paypal.com", "https://maps.googleapis.com", "https://maps.gstatic.com", "https://optimizationguide-pa.googleapis.com"],
   mediaSrc: ["'self'", "data:", "blob:", messenger, streamer, ws_messenger, ws_streamer, rtmp_streamer],
   fontSrc: ["'self'", "data:","https://fonts.gstatic.com", "https://optimizationguide-pa.googleapis.com"],
   styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com", "https://optimizationguide-pa.googleapis.com","https://vjs.zencdn.net", "https://cdn.jsdelivr.net", "https://cdnjs.cloudflare.com"],
   scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'", "https://www.paypalobjects.com", "https://www.paypal.com", "https://*.paypal.com", "https://cdnjs.cloudflare.com", "https://maps.googleapis.com", "https://maps.gstatic.com", "https://optimizationguide-pa.googleapis.com", "https://cdn.jsdelivr.net"],
   //scriptSrc: ["'self'", "'unsafe-inline'", "https://cdnjs.cloudflare.com", "https://maps.googleapis.com", "https://maps.gstatic.com"],
   connectSrc: ["'self'", "data:", "blob:", "https://www.sandbox.paypal.com", "https://www.paypalobjects.com", "https://www.paypal.com", "https://api.paypal.com",  "https://maps.googleapis.com", messenger, streamer, ws_messenger, ws_streamer, notifier,mediamtx_streamer, vllm_host, rtmp_streamer],
   //scriptSrcAttr: ["'self'", "'unsafe-inline'"],
   scriptSrcAttr: ["'self'", "'unsafe-inline'"],
   formAction: ["'self'"],
   frameAncestors:["'self'"],
   manifestSrc: ["'self'"],
   baseUri: ["'self'"],

   // cspOptions: {
   //    defaultSrc: "'self'",
   //    frameSrc: "'self' https://www.sandbox.paypal.com https://www.paypal.com" + " " + streamer ,
   //    imgSrc: "'self' data: blob: https://www.paypalobjects.com https://t.paypal.com https://maps.googleapis.com https://maps.gstatic.com https://optimizationguide-pa.googleapis.com",
   //    mediaSrc: "'self' data: blob:" + " "  + messenger + " " +  streamer +" " + ws_messenger + " " + ws_streamer,
   //    fontSrc: "'self' data: https://fonts.gstatic.com https://optimizationguide-pa.googleapis.com",
   //    connectSrc: "'self' data: blob:  https://www.sandbox.paypal.com https://www.paypalobjects.com https://www.paypal.com https://api.paypal.com https://maps.googleapis.com" + " " + messenger + " "+ streamer + " " + ws_messenger + " " + ws_streamer + " " + notifier + " " + mediamtx_streamer + " " + vllm_host,
   //    scriptSrcAttr: "'self' 'unsafe-inline'",
   //    formAction: "'self'",
   //    frameAncestors: "'self'",
   //    //frameAncestors: "'self' https://www.sandbox.paypal.com" +" " + streamer ,
   //    objectSrc: "'none'",
   //    styleSrc: "'self' 'unsafe-inline' https://fonts.googleapis.com https://optimizationguide-pa.googleapis.com https://vjs.zencdn.net https://cdn.jsdelivr.net https://cdnjs.cloudflare.com",
   //    scriptSrc: "'self' 'unsafe-inline' 'unsafe-eval' https://www.paypalobjects.com https://www.paypal.com https://*.paypal.com https://cdnjs.cloudflare.com https://maps.googleapis.com https://maps.gstatic.com https://optimizationguide-pa.googleapis.com https://cdn.jsdelivr.net",
   //    manifestSrc: "'self'",
   //    baseUri: "'self'"

   // },
   cspOptions: {
      defaultSrc: "'self'",
      frameSrc: "'self' about: https://www.sandbox.paypal.com https://www.paypal.com https://*.paypal.com " + streamer + " " + rtmp_streamer,
      imgSrc: "'self' data: blob: https://www.paypalobjects.com https://t.paypal.com https://maps.googleapis.com https://maps.gstatic.com https://optimizationguide-pa.googleapis.com",
      mediaSrc: "'self' data: blob:" + " " + messenger + " " + streamer + " " + ws_messenger + " " + ws_streamer + " " + mediamtx_streamer + " " + rtmp_streamer,
      fontSrc: "'self' data: https://fonts.gstatic.com https://optimizationguide-pa.googleapis.com",
      connectSrc: "'self' data: blob: https://*.paypal.com https://www.paypalobjects.com https://maps.googleapis.com " + messenger + " " + streamer + " " + ws_messenger + " " + ws_streamer + " " + notifier + " " + mediamtx_streamer + " " + vllm_host + " " + rtmp_streamer,
      scriptSrcAttr: "'self' 'unsafe-inline'",
      formAction: "'self'",
      frameAncestors: "'self'",
      objectSrc: "'none'",
      styleSrc: "'self' 'unsafe-inline' https://fonts.googleapis.com https://optimizationguide-pa.googleapis.com https://vjs.zencdn.net https://cdn.jsdelivr.net https://cdnjs.cloudflare.com",
      scriptSrc: "'self' 'unsafe-inline' 'unsafe-eval' https://www.paypalobjects.com https://www.paypal.com https://*.paypal.com https://cdnjs.cloudflare.com https://maps.googleapis.com https://maps.gstatic.com https://optimizationguide-pa.googleapis.com https://cdn.jsdelivr.net",
      manifestSrc: "'self'",
      baseUri: "'self'"
   },

   cspOptionsStr:
      "default-src 'self'; " + // Only load resources from the same origin
      "frame-src 'self' https://www.sandbox.paypal.com https://www.paypal.com" + " " + streamer + " " + rtmp_streamer + ";" +
      "img-src 'self' data: blob: https://www.paypalobjects.com https://t.paypal.com https://maps.googleapis.com https://maps.gstatic.com https://optimizationguide-pa.googleapis.com" +  ";" +
      "media-src 'self' data: blob: " + " " +  messenger + " " + streamer + " " + ws_messenger + " " + ws_streamer +  " " + mediamtx_streamer + " " + rtmp_streamer + ";" +
      "font-src 'self'  data: https://fonts.gstatic.com https://optimizationguide-pa.googleapis.com" +  ";" +
      "connect-src 'self' data: blob: https://www.sandbox.paypal.com https://www.paypalobjects.com https://www.paypal.com https://api.paypal.com https://maps.googleapis.com" + " " + messenger + " " + streamer + " " + ws_messenger + " " + ws_streamer + " " + notifier + " " + mediamtx_streamer + " " + rtmp_streamer +  ";" +
      "script-src-attr 'self' 'unsafe-inline'" +  ";" +
      "form-action 'self';" + 
      //"frame-ancestors: 'self' https://www.sandbox.paypal.com " + " " + streamer + ";" +
      "frame-ancestors: 'self';" +
      "object-src 'none';" +
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://optimizationguide-pa.googleapis.com https://vjs.zencdn.net https://optimizationguide-pa.googleapis.com https://cdn.jsdelivr.net https://cdnjs.cloudflare.com" +  ";" +
      "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.paypalobjects.com https://www.paypal.com  https://*.paypal.com https://cdnjs.cloudflare.com https://maps.googleapis.com https://maps.gstatic.com https://optimizationguide-pa.googleapis.com https://cdn.jsdelivr.net" +  ";" +
      "manifest-src 'self';" +
      "base-uri 'self';",

   staticOptions:
      "default-src 'self'; " + // Only load resources from the same origin
      "script-src 'self'; " +  // Only allow scripts from the same origin
      "style-src 'self'; " +   // Only allow styles from the same origin
      "img-src 'self'; " +     // Only allow images from the same origin
      "connect-src 'self'; " + // Only allow XHR requests to the same origin
      "font-src 'self'; " +    // Only allow fonts from the same origin
      "object-src 'none'; " +  // Disallow <object>, <embed>, <applet>
      "frame-src 'none'; " +   // Disallow embedding in iframes
      "form-action 'self'; " +
      "frame-ancestors 'none';" +
      "media-src 'self';" +
      "connect-src 'self';" +
      "manifest-src 'self';" +
      "base-uri 'self';"
}
