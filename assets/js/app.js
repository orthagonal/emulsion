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
import { DataSet, Network } from 'vis/index-network';

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

let Hooks = {};
Hooks.VisNetwork = {
  mounted() {
    let data = JSON.parse(this.el.attributes['data_diagram_data'].value)
    this.network = this.initNetwork(this.el, data);
    this.handleEvent('update_graph', ({ nodes, edges }) => {
      console.log("update_graph", nodes, edges);
      this.updateGraph(nodes, edges);
    });
  },
  initNetwork(el, data) {
    console.log("data", data);
    const nodes = new DataSet(data.nodes)
    const edges = new DataSet(data.edges);
    const container = el;
    const diagram = { nodes, edges };
    const options = {};
    return new Network(container, diagram, options);
  },
  updateGraph(nodes, edges) {
    this.network.setData({ nodes, edges });
  },
};
Hooks.VideoPlayer = {
  mounted() {
    this.videoA = this.el.querySelector("#videoA");
    this.videoB = this.el.querySelector("#videoB");
    this.videoB.style.display = "none";
    this.videoA.style.display = "block";

    this.videoA.onended = () => {
      this.videoB.play();
      this.videoA.style.display = "none";
      this.videoB.style.display = "block";
      this.pushEvent('video_started', { video_name: this.videoB.dataset.videoName });
      this.pushEvent('next_video', {});
    };

    this.videoB.onended = () => {
      this.videoA.play();
      this.videoB.style.display = "none";
      this.videoA.style.display = "block";
      this.pushEvent('video_started', { video_name: this.videoA.dataset.videoName });
      this.pushEvent('next_video', {});
    };
  },

  updated() {
    const nextVideoA = this.el.dataset.nextVideoA;
    const nextVideoB = this.el.dataset.nextVideoB;
    if (nextVideoA) {
      this.videoA.src = nextVideoA;
    }
    if (nextVideoB) {
      this.videoB.src = nextVideoB;
    }
  }
};


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { 
  hooks: Hooks,
  params: {_csrf_token: csrfToken}
});

// connect if there are any LiveViews on the page
liveSocket.connect();
