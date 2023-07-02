import { DataSet, Network } from 'vis/index-network';
window.network = { nodes: [], edges: [] };

let Hooks = {};
Hooks.VisNetwork = {
  mounted() {
    let data = JSON.parse(this.el.attributes['data_diagram_data'].value)
    this.network = this.initNetwork(this.el, data);
    this.handleEvent('update_graph', ({ nodes, edges }) => {
      // Filter nodes and edges to remove duplicates based on 'id'
      const uniqueNodeIds = new Set();
      nodes = nodes.filter(node => {
        if (!uniqueNodeIds.has(node.id)) {
          uniqueNodeIds.add(node.id);
          return true;
        }
        return false;
      });
      const uniqueEdgeIds = new Set();
      edges = edges.filter(edge => {
        if (!uniqueEdgeIds.has(edge.id)) {
          uniqueEdgeIds.add(edge.id);
          return true;
        }
        return false;
      });
      this.network.setData({ nodes, edges });
      window.network = { nodes, edges };
      // Update videos after updating network
      if (window.VideoPlayer) {
        window.VideoPlayer.blocked = true;
        window.VideoPlayer.resetVideos();
      }
    });
  },
  initNetwork(el, data) {
    const nodes = new DataSet(data.nodes)
    const edges = new DataSet(data.edges);
    const container = el;
    const diagram = { nodes, edges };
    const options = {};
    return new Network(container, diagram, options);
  },
};
Hooks.VideoPlayer = {
  mounted() {
    window.VideoPlayer = this; // Expose this object to the global scope

    this.videoA = this.el.querySelector("#videoA");
    this.videoB = this.el.querySelector("#videoB");
    this.blocked = false; // Initially, the player is not blocked

    // Start with videoB hidden, videoA visible
    this.videoB.style.display = "none";
    this.videoA.style.display = "block";

    this.setupEventHandlers();
  },

  setupEventHandlers() {
    this.videoA.onended = () => this.switchVideos(this.videoA, this.videoB);
    this.videoB.onended = () => this.switchVideos(this.videoB, this.videoA);
  },

  async switchVideos(currentVideo, nextVideo) {
    if (this.blocked) return;
    const videoName = currentVideo.src;
    const nextEdge = await this.getNextEdge(videoName);
    if (nextEdge) {
      nextVideo.src = nextEdge.path;
      nextVideo.oncanplaythrough = () => {
        // Hide current video and play next video when it's ready to play
        currentVideo.style.display = "none";
        nextVideo.style.display = "block";
        nextVideo.play();

        // Remove the oncanplaythrough event handler
        nextVideo.oncanplaythrough = null;
      }
    }
  },

  resetVideos() {
    // Block current videos
    this.blocked = true;

    // Set videoA to a random edge path
    if (window.network.edges.length > 0) {
      const nextEdge = window.network.edges[Math.floor(Math.random() * window.network.edges.length)];
      this.videoA.src = nextEdge.path;
    }

    // Unblock videos and reset event handlers
    this.blocked = false;
    this.setupEventHandlers();
  },


  getNextEdge (videoName) {
    return new Promise((resolve, reject) => {
      const checkEdges = () => {
        if (window.network.edges.length > 0) {
          const edge = window.network.edges.find(edge => videoName.endsWith(edge.path));
          if (!edge) {
            return false;
          }
          const curNodeId = edge.to;
          // Pick a random edge from the list of edges
          const validEdges = window.network.edges.filter(edge => edge.from === curNodeId);
          const nextEdge = validEdges[Math.floor(Math.random() * validEdges.length)];
          resolve(nextEdge);
        } else {
          setTimeout(checkEdges, 100);
        }
      }
      checkEdges();
    });
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


module.exports = {
  Hooks,
  VisNetwork: Hooks.VisNetwork,
  VideoPlayer: Hooks.VideoPlayer
}