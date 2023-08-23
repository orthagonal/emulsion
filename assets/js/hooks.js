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
    // Start a  timer so that large graphs don't overload everything
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
            this.pushEvent("select_node", { node_id: nodeId });
          }
        });

        // when they hover, show the id of the edge
        this.network.on('hoverEdge', params => {
          const edgeId = params.edge;
          const edge = this.network.body.data.edges.get(edgeId);
          const label = edge.tags ? edge.tags.join(',') : edge.id;
          this.network.body.data.edges.update({ id: edgeId, label: label });
        });

        this.network.on("selectEdge", params => {
          if (this.window.ContextPanel) {
            const edgeId = params.edges[0];
            const edge = this.network.body.data.edges.get(edgeId);
            window.ContextPanel.showEdge(edge);
            window.VideoPlayer.queueVideo(edge.path);
            this.pushEvent("select_edge", { edge_id: edgeId });
            // Set nextSelectedEdge on window object
            // window.nextSelectedEdge = edgeId;
          }
        });
        if (window.VideoPlayer) {
          window.VideoPlayer.blocked = true;
          window.VideoPlayer.resetVideos();
        }
        this.buffer = { nodes: [], edges: [] };
      }
    }, 2500);

    this.handleEvent('update_graph', ({ nodes, edges }) => {
      // Attach a title to each edge if it doesn't already have one
      edges.forEach(edge => {
        edge.label = edge.tags ? edge.tags.join(',') : edge.id;
      });

      // Add updates to the buffer instead of immediately applying them
      this.buffer.nodes = [...this.buffer.nodes, ...nodes];
      this.buffer.edges = [...this.buffer.edges, ...edges];
    });
  },

  // Make sure to clear the timer when the component is unmounted
  destroyed() {
    clearInterval(this.updateTimer);
  },

  initNetwork(el, data) {
    const nodes = new DataSet(data.nodes)
    const edges = new DataSet(data.edges);
    const container = el;
    const diagram = { nodes, edges };
    const options = {
      edges: {
        font: {
          size: 12
        },
        color: 'gray',
        arrows: 'to',
        smooth: true,
        hoverWidth: 1.5
      },
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
    window.nextSelectedEdge = null; // if there is a next edge to play, this is it, default is to play the any 'idle' edge
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
      this.videoB.style.display = "none";
      this.videoA.style.display = "block";
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

  createButton(edge) {
    const button = document.createElement('button');
    button.textContent = edge.tags ? edge.tags.join(',') : '(' + edge.id + ")";
    button.addEventListener('click', () => {
      window.nextSelectedEdge = edge.id;
    });
    return button;
  },

  getNextEdge(videoName) {
    let edge = window.network.edges.find(edge => videoName.endsWith(edge.path));
    if (!edge) {
      return null;
    }

    const curNodeId = edge.to;
    const outgoingEdges = window.network.edges.filter(edge => edge.from === curNodeId);

    // Remove any previously generated buttons
    const container = document.getElementById('buttons-container');
    while (container.firstChild) {
      container.firstChild.remove();
    }

    // Create a button for each outgoing edge
    outgoingEdges.forEach(edge => {
      const button = this.createButton(edge);
      container.appendChild(button);
    });

    let nextEdge = null;

    // If 'nextSelectedEdge' is defined, find the corresponding edge by id or tag
    if (window.nextSelectedEdge) {
      // nextEdge = outgoingEdges.find(edge => edge.id === window.nextSelectedEdge);
      nextEdge = window.network.edges.find(edge => edge.id === window.nextSelectedEdge);
      if (!nextEdge) {
        nextEdge = outgoingEdges.find(edge => edge.tags && edge.tags.includes(window.nextSelectedEdge));
      }
    }

    // If no edge was selected or 'nextSelectedEdge' didn't match any edge, find an 'idle' edge
    if (!nextEdge) {
      nextEdge = outgoingEdges.find(edge => edge.tags && edge.tags.includes('idle'));
    }

    // If no idle edge found, just pick the first one
    if (!nextEdge) {
      nextEdge = outgoingEdges[0];
    }

    // Reset 'nextSelectedEdge'
    window.nextSelectedEdge = null;

    return nextEdge;
  },

  // callback handler for when user clicks an edge in the VisGraph 
  // todo: needs to be debugged
  playEdge(edge) {
    this.queueVideo(edge.path);
  },
};

// next up: 
// add a panel that lists the idle options for the current node and auto-plays idle videos attached to it
// automatically play idle frames on infinite loop, allow option to go to 'next' which means transitioning to new node/list of edges
// clicking the node goes to that frame

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
      <button data-action="regenerate-video">Regenerate Video</button>
      <button data-action="goto">Goto</button>
      <button data-action="delete">Delete Edge</button>
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
    tagButton.addEventListener('click', function () {
      let tagInput = document.querySelector('#tag-input');
      let tag = tagInput.value;
      self.pushEvent("tag_edge", { edge_id: edge.id, tag: tag });
    });
    let gotoButton = document.querySelector('button[data-action="goto"]');
    gotoButton.addEventListener('click', () => {
      window.VideoPlayer.queueVideo(edge.path);
    });
    let deleteButton = document.querySelector('button[data-action="delete"]');
    deleteButton.addEventListener('click', function () {
      self.pushEvent("delete_edge", { edge_id: edge.id });
    });

    function determineEdgeType(edgeId) {
      if (edgeId.includes("_to_")) {
        return "tween";
      } else if (edgeId.includes("_thru_")) {
        return "sequence";
      }
      return null;  // or some other default value
    }
        
    let regenerateButton = document.querySelector('button[data-action="regenerate-video"]');
    regenerateButton.addEventListener('click', function () {
      self.pushEvent("regenerate_video", { from: edge.from, to: edge.to, edge_type: determineEdgeType(edge.id) });
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

    frameRange.addEventListener('input', function () {
      frameValueSpan.textContent = this.value;
    });

    idleButton.addEventListener('click', () => {
      let frameValue = frameRange.value;
      this.pushEvent("idle_around_frame", { src_frame: node.id, range: frameValue });
    });
  }
};

Hooks.ScrollToThumb = {
  mounted() {
    this.el.addEventListener("input", event => {
      console.log(event.target.value);
      let searchStr = event.target.value;
      if (searchStr) {
        let thumbEls = document.querySelectorAll("#thumbGrid img");
        let rightColumn = document.querySelector("#right-column");
        for (let i = 0; i < thumbEls.length; i++) {
          let thumbEl = thumbEls[i];
          if (thumbEl.src.includes(searchStr)) {
            rightColumn.scrollTop = thumbEl.offsetParent.offsetTop - rightColumn.offsetTop;
            break;
          }
        }
      }
    });
  }

}

module.exports = {
  Hooks,
  ContextPanel: Hooks.ContextPanel,
  VisNetwork: Hooks.VisNetwork,
  VideoPlayer: Hooks.VideoPlayer,
  ScrollToThumb: Hooks.ScrollToThumb
}