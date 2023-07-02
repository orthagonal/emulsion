/**
 * @jest-environment jsdom
 */

import { DataSet, Network } from 'vis/index-network'; // Assuming this is a node package
import { Hooks } from '../assets/js/hooks.js';

const { window } = global;
let document;

// Creating the mock video elements
let mockPlay = async function() {
  await new Promise(resolve => setTimeout(resolve, 500));
  this.onended();
}
let mockVideoA = { src: "http://localhost/file/MVI_5979/tweens/img_0012_to_img_0001.webm", onended: null, play: mockPlay, style: { display: "" } };
let mockVideoB = { src: "", onended: null, play: mockPlay, style: { display: "" } };

beforeEach(() => {
  document = {
    querySelector: jest.fn().mockImplementation((selector) => {
      if (selector === "#videoA") return mockVideoA;
      if (selector === "#videoB") return mockVideoB;
    }),
  };
});

const mockNodes =       [
  {
      "edges": [],
      "id": "e:/emulsion_workspace/MVI_5979/frames/img_0012.png",
      "label": "img_0012.png",
      "name": "e:/emulsion_workspace/MVI_5979/frames/img_0012.png"
  },
  {
      "edges": [],
      "id": "e:/emulsion_workspace/MVI_5979/frames/img_0001.png",
      "label": "img_0001.png",
      "name": "e:/emulsion_workspace/MVI_5979/frames/img_0001.png"
  }
]; 
const mockEdges = [
  {
      "destination": "e:/emulsion_workspace/MVI_5979/frames/img_0001.png",
      "from": "e:/emulsion_workspace/MVI_5979/frames/img_0012.png",
      "fromPath": "/file/MVI_5979/frames/img_0012.png",
      "id": "img_0012_to_img_0001.webm",
      "path": "/file/MVI_5979/tweens/img_0012_to_img_0001.webm",
      "to": "e:/emulsion_workspace/MVI_5979/frames/img_0001.png",
      "toPath": "/file/MVI_5979/frames/img_0001.png"
  },
  {
      "destination": "e:/emulsion_workspace/MVI_5979/frames/img_0012.png",
      "from": "e:/emulsion_workspace/MVI_5979/frames/img_0001.png",
      "fromPath": "/file/MVI_5979/frames/img_0001.png",
      "id": "1_thru_12.webm",
      "path": "/file/MVI_5979/output/1_thru_12.webm",
      "to": "e:/emulsion_workspace/MVI_5979/frames/img_0012.png",
      "toPath": "/file/MVI_5979/frames/img_0012.png"
  }
];

describe("VideoPlayer tests", () => {
  beforeEach(async () => {
    // Mocking window.network before each test
    window.network = { nodes: [], edges: [] };
    // Setting up the hooks
    window.VideoPlayer = Hooks.VideoPlayer;
    window.VideoPlayer.el = document;
    await window.VideoPlayer.mounted();
    // window.VisNetwork = Hooks.VisNetwork;
    // window.VisNetwork.el = document;
    // window.VisNetwork.el.attributes = { 'data_diagram_data': { value: JSON.stringify({ nodes: [], edges: [] }) } };
    // window.VisNetwork.mounted();
  });

  test("continuously plays videos with .play", async () => {
    window.network = { nodes: mockNodes, edges: mockEdges };
    // Mocking the onended event
    mockVideoA.play();
    await new Promise(resolve => setTimeout(resolve, 5000));
    // mockVideoB.onended();
    // await new Promise(resolve => setTimeout(resolve, 3000));
    // mockVideoA.onended();
    // await new Promise(resolve => setTimeout(resolve, 3000));
    // console.log(mockVideoA);
    // console.log(mockVideoB);
    // expect(mockVideoA.style.display).toBe("none");
    // expect(mockVideoB.style.display).toBe("block");

    // Similarly, you can mock onended event for mockVideoB
  }, 15000);
});
