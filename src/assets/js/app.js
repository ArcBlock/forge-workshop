// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"
import { SSL_OP_ALLOW_UNSAFE_LEGACY_RENEGOTIATION } from "constants";

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"

var QRCode = require('qrcode')
var canvases = Array.from(document.getElementsByTagName('canvas'));

if (canvases != null && canvases.length > 0) {
  canvases.forEach((canvas) => {
    var qrValue = document.getElementById('qrValue_' + canvas.id.substr(7));
    QRCode.toCanvas(canvas, qrValue.value, function (error) {
      if (error) console.error(error)
      console.log('success!');
    });
  });
}
window.__socket = require("phoenix").Socket;