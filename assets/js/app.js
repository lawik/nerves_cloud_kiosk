// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Keyboard from './keyboard'

const keyboard = new Keyboard({
  onChange: input => onChange(input),
  onKeyPress: button => onKeyPress(button)
});

let kbEl = document.getElementById("keyboard-container");
kbEl.classList.add("hidden");
let kbTarget = null;
let kbUnhit = true;
let lastKnownCaret = 0;

console.log(keyboard);
kbEl.addEventListener("click", () => {
  kbUnhit = false;
});

function onChange(input) {
  console.log("Input changed", input);
  keepKeyboard();
  // First character
  if (input.length == 1) {
    let text = kbTarget.value;
    let originalLength = text.length;
    let keepFirstOffset = originalLength;
    let keepSecondOffset = originalLength;
    switch (kbTarget.selectionDirection) {
      case "forward":
        lastKnownCaret = kbTarget.selectionEnd;
        keepFirstOffset = kbTarget.selectionStart;
        keepSecondOffset = kbTarget.selectionEnd;
        break;
      case "backward":
        lastKnownCaret = kbTarget.selectionStart;
        keepFirstOffset = kbTarget.selectionStart;
        keepSecondOffset = kbTarget.selectionEnd;
        break;
      default:
        lastKnownCaret = kbTarget.selectionStart;
  }

    let first = text.substring(0, keepFirstOffset);
    let second = text.substring(keepSecondOffset, originalLength)
    kbTarget.value = first + input + second;
    keyboard.setInput(kbTarget.value)
  } else {
    switch (kbTarget.selectionDirection) {
      case "forward":
        lastKnownCaret = kbTarget.selectionEnd;
        break;
      case "backward":
        lastKnownCaret = kbTarget.selectionStart;
        break;
      default:
        lastKnownCaret = kbTarget.selectionStart;
  }
    kbTarget.value = input;
  }

  //can't get focus to stick
  //kbTarget.focus()
}

function onKeyPress(button) {
  console.log("Button pressed", button);
  keepKeyboard();

  /**
   * If you want to handle the shift and caps lock buttons
   */
  if (button === "{shift}" || button === "{lock}") handleShift();
}

function handleShift() {
  let currentLayout = keyboard.options.layoutName;
  let shiftToggle = currentLayout === "default" ? "shift" : "default";

  keyboard.setOptions({
    layoutName: shiftToggle
  });
}

document.body.addEventListener("focusin", (e) => {
  console.log("focusin")
  console.log(e.target)
  if (e.target instanceof HTMLInputElement) {
    keepKeyboard();
    kbTarget = e.target;
    kbTarget.addEventListener("input", updateInput);
    kbEl.classList.remove("hidden");
    keyboard.setInput(kbTarget.value)
  } else {

  }
});

let updateInput = function (event) {
  keyboard.setInput(event.target.value);
}

document.body.addEventListener("focusout", (e) => {
  console.log(e)
  if (kbTarget !== null) {
    kbTarget.removeEventListener("input", updateInput)
  }
  hideKeyboardIfNotHit()
})

function keepKeyboard() {
  kbUnhit = false;
  window.setTimeout(() => {
    // Hack to set this after events have fired but before delayed events
    kbUnhit = false;
  })
}

function hideKeyboardIfNotHit() {
  kbUnhit = true;
  console.log("consider hiding..")
  window.setTimeout(() => {
    console.log("hiding?", kbUnhit)
    if(kbUnhit) {
      console.log("hidden")
      kbEl.classList.add("hidden");
    }
  },100)
}


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

