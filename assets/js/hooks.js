import { DataSet, Network } from 'vis/index-network';
window.network = { nodes: [], edges: [] };

let Hooks = {};
Hooks.VisNetwork = {
  mounted() {
    this.window = window;
    let data = JSON.parse(this.el.attributes['data_diagram_data'].value)
    this.network = this.initNetwork(this.el, data);

    // Add a buffer to store updates
    this.buffer = { nodes: [], edges: [] };
    // Start a 5-second timer
    this.updateTimer = setInterval(() => {
      // Apply all changes in the buffer at once
      if (this.buffer.nodes.length > 0 || this.buffer.edges.length > 0) {
        // Empty the buffer
        let nodes = this.buffer.nodes;
        let edges = this.buffer.edges;
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

        this.network.on("selectNode", params => {
          if (this.window.ContextPanel) {
            const nodeId = params.nodes[0];
            const node = this.network.body.data.nodes.get(nodeId);
            window.ContextPanel.showNode(node);
            this.pushEvent("select_node", {node_id: nodeId});
          }
        });
        
        this.network.on("selectEdge", params => {
          if (this.window.ContextPanel) {
            const edgeId = params.edges[0];
            const edge = this.network.body.data.edges.get(edgeId);
            window.ContextPanel.showEdge(edge);
            this.pushEvent("select_edge", {edge_id: edgeId});
          }
        });
        if (window.VideoPlayer) {
          window.VideoPlayer.blocked = true;
          window.VideoPlayer.resetVideos();
        }
        this.buffer = { nodes: [], edges: [] };
      }
    }, 5000);

    this.handleEvent('update_graph', ({ nodes, edges }) => {
      // Add updates to the buffer instead of immediately applying them
      this.buffer.nodes = [...this.buffer.nodes, ...nodes];
      this.buffer.edges = [...this.buffer.edges, ...edges];
    });
  },

  // Make sure to clear the timer when the component is unmounted
  destroyed() {
    clearInterval(this.updateTimer);
  },
    // this.handleEvent('update_graph', ({ nodes, edges }) => {
    //   // Filter nodes and edges to remove duplicates based on 'id'
    //   const uniqueNodeIds = new Set();
    //   nodes = nodes.filter(node => {
    //     if (!uniqueNodeIds.has(node.id)) {
    //       uniqueNodeIds.add(node.id);
    //       return true;
    //     }
    //     return false;
    //   });
    //   const uniqueEdgeIds = new Set();
    //   edges = edges.filter(edge => {
    //     if (!uniqueEdgeIds.has(edge.id)) {
    //       uniqueEdgeIds.add(edge.id);
    //       return true;
    //     }
    //     return false;
    //   });
      // this.network.setData({ nodes, edges });
      // window.network = { nodes, edges };
      // this.network.on("selectNode", params => {
      //   if (this.window.ContextPanel) {
      //     const nodeId = params.nodes[0];
      //     const node = this.network.body.data.nodes.get(nodeId);
      //     window.ContextPanel.showNode(node);
      //     this.pushEvent("select_node", {node_id: nodeId});
      //   }
      // });
      
      // this.network.on("selectEdge", params => {
      //   if (this.window.ContextPanel) {
      //     const edgeId = params.edges[0];
      //     const edge = this.network.body.data.edges.get(edgeId);
      //     window.ContextPanel.showEdge(edge);
      //     this.pushEvent("select_edge", {edge_id: edgeId});
      //   }
      // });
      
      // Update videos after updating network
  // },
  initNetwork(el, data) {
    const nodes = new DataSet(data.nodes)
    const edges = new DataSet(data.edges);
    const container = el;
    const diagram = { nodes, edges };
    const options = {
      layout: {
        improvedLayout: false,
      }
    };
    return new Network(container, diagram, options);
  },
};
Hooks.VideoPlayer = {
  mounted() {
    window.VideoPlayer = this; // Expose this object to the global scope

    this.queuedVideo = null; // Initially, there is no queued video
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

  queueVideo(videoSrc) {
    this.queuedVideo = videoSrc;
    if (this.videoA.paused && this.videoB.paused) {
      this.videoA.src = this.queuedVideo;
      this.queuedVideo = null; // Clear queued video after setting it
      this.videoA.play();
    }
  },

  async switchVideos(currentVideo, nextVideo) {
    if (this.blocked) return;
    let nextEdge;
    if (this.queuedVideo) {
      nextVideo.src = this.queuedVideo;
      this.queuedVideo = null;  // Clear queued video after setting it
      nextEdge = { path: this.queuedVideo };  // The queued video becomes the nextEdge
    } else {
      const videoName = currentVideo.src;
      nextEdge = await this.getNextEdge(videoName);
      if (nextEdge) {
        nextVideo.src = nextEdge.path;
      }
    }

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

Hooks.ContextPanel = {

  mounted() {
    window.ContextPanel = this;
    this.window = window;
  },

  clear() {
    this.el.innerHTML = '';
  },

  updated() {
    const nodeId = this.el.dataset.selectedNodeId;
    const edgeId = this.el.dataset.selectedEdgeId;

    if (nodeId) {
      const node = window.network.nodes.find((node => node.id == nodeId))
      this.showNode(node);
    } else if (edgeId) {
      const edge = window.network.edges.find({ id: nodeId });
      
      this.showEdge(edge);
    }
  },

  showEdge(edge) {
    const tagList = edge.tags ? edge.tags.join(', ') : '';
    this.el.innerHTML = `
      <h2>Edge Information</h2>
      <p>Edge ID: ${edge.id}</p>
      <p>Edge From: ${edge.from}</p>
      <p>Edge To: ${edge.to}</p>
      <button data-action="goto">Goto</button>
      <div>
        <input type="text" id="tag-input" placeholder="Enter tag">
        <button data-action="tag">Tag</button>
      </div>
      <div id="tag-list">
        <h3>Tags</h3>
        <p>${tagList}</p>
    `;
    let tagButton = document.querySelector('button[data-action="tag"]');
    let self = this;
    tagButton.addEventListener('click', function() {
      let tagInput = document.querySelector('#tag-input');
      let tag = tagInput.value;
      self.pushEvent("tag_edge", {edge_id: edge.id, tag: tag});
    });
    let gotoButton = document.querySelector('button[data-action="goto"]');
    gotoButton.addEventListener('click', () => {
      window.VideoPlayer.queueVideo(edge.path);
    });
  },

  showNode(node) {
    let edgeList = node.edges.reduce((acc, edge) => {
      if (edge.from == node.id) {
        acc = `${acc} <p>Edge To: ${edge.to}</p>`
      } else {
        acc = `${acc} <p>Edge From: ${edge.from}</p>`
      }
      return acc;
    }, `
    <h3>Edges</h3>
    `);
    this.el.innerHTML = `
      <h2>Node Information</h2>
      <p>Node ID: ${node.id}</p>
      <p>Node Label: ${node.label}</p>
      ${edgeList}
      <label>Idle Range: <input type="number" id="idle_range" name="idle_range"></label>
      <button data-action="connect-to">Connect To</button>
      <button data-action="make-idle">Make Idle</button>
      <div>
        <input type="range" id="frame-range" min="0" max="60" value="4">
        <span id="frame-value">4</span>
        <button class="border-2 bg-slate-500" data-action="idle">Idle Around Frame</button>
      </div>
    `;
    let idleButton = document.querySelector('button[data-action="idle"]');
    let frameRange = document.querySelector('#frame-range');
    let frameValueSpan = document.querySelector('#frame-value');
  
    frameRange.addEventListener('input', function() {
      frameValueSpan.textContent = this.value;
    });
  
    idleButton.addEventListener('click', () => {
      let frameValue = frameRange.value;
      this.pushEvent("idle_around_frame", {src_frame: node.id, range: frameValue});
    });
  }
};


module.exports = {
  Hooks,
  ContextPanel: Hooks.ContextPanel,
  VisNetwork: Hooks.VisNetwork,
  VideoPlayer: Hooks.VideoPlayer
}