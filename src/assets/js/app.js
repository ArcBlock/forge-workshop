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

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"

var QRCode = require('qrcode')
var canvas = document.getElementById('canvas')
var qrValue = document.getElementById('qrValue')

if (canvas != null) {
  QRCode.toCanvas(canvas, qrValue.value, function (error) {
    if (error) console.error(error)
    console.log('success!');
  });
}
window.__socket = require("phoenix").Socket;