# most of this is the RIFE cde for powering the tween generator
import os
import sys
from collections import namedtuple
import gc
import os
import cv2
import torch
import argparse
from torch.nn import functional as F
import warnings
import subprocess

tween_exp = int(sys.argv[1])
src_frame = sys.argv[2]
dest_frame = sys.argv[3]
ffmpeg_params = sys.argv[4]
output_file = sys.argv[5].strip()

Args = namedtuple('Args', ['img', 'exp', 'ratio', 'rthreshold', 'rmaxcycles', 'modelDir', 'folderOut'])

print("**************************************************************************************************************************************")
print("Source frame: " + src_frame + " Destination frame: " + dest_frame + " Tween exponent: " + str(tween_exp) + " Output file: " + output_file)
print("**************************************************************************************************************************************")
args = Args(
    img=[src_frame, dest_frame],
    exp=tween_exp,
    ratio=0,
    rthreshold=0.02,
    rmaxcycles=8,
    modelDir='lib/scripts/train_log',
    folderOut='output'
)
frame_count = 2 ** tween_exp

warnings.filterwarnings("ignore")

def printMem():
    gc.collect()
    torch.cuda.empty_cache()
    print(torch.cuda.memory_summary())

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"device is {device}")
torch.set_grad_enabled(False)
if torch.cuda.is_available():
    torch.backends.cudnn.enabled = True
    torch.backends.cudnn.benchmark = True

try:
    try:
        print(os.getcwd())
        from model.RIFE_HDv2 import Model
        model = Model()
        model.load_model(args.modelDir, -1)
        print("Loaded v2.x HD model.")
    except:
        from train_log.RIFE_HDv3 import Model
        model = Model()
        model.load_model(args.modelDir, -1)
        print("Loaded v3.x HD model.")
except:
    from model.RIFE_HD import Model
    model = Model()
    model.load_model(args.modelDir, -1)
    print("Loaded v1.x HD model")
model.eval()
model.device()

if args.img[0].endswith('.exr') and args.img[1].endswith('.exr'):
    img0 = cv2.imread(args.img[0], cv2.IMREAD_COLOR | cv2.IMREAD_ANYDEPTH)
    img1 = cv2.imread(args.img[1], cv2.IMREAD_COLOR | cv2.IMREAD_ANYDEPTH)
    if (img0 is None):
        print("Error reading file: " + args.img[0])
        exit(1)
    if (img1 is None):
        print("Error reading file: " + args.img[0])
        exit(1)
    img0 = (torch.tensor(img0.transpose(2, 0, 1)).to(device)).unsqueeze(0)
    img1 = (torch.tensor(img1.transpose(2, 0, 1)).to(device)).unsqueeze(0)

else:
    img0 = cv2.imread(args.img[0], cv2.IMREAD_UNCHANGED)
    img1 = cv2.imread(args.img[1], cv2.IMREAD_UNCHANGED)
    img0 = (torch.tensor(img0.transpose(2, 0, 1)).to(device) / 255.).unsqueeze(0)
    img1 = (torch.tensor(img1.transpose(2, 0, 1)).to(device) / 255.).unsqueeze(0)

n, c, h, w = img0.shape
ph = ((h - 1) // 32 + 1) * 32
pw = ((w - 1) // 32 + 1) * 32
padding = (0, pw - w, 0, ph - h)
img0 = F.pad(img0, padding)
img1 = F.pad(img1, padding)

if args.ratio:
    img_list = [img0]
    img0_ratio = 0.0
    img1_ratio = 1.0
    if args.ratio <= img0_ratio + args.rthreshold / 2:
        middle = img0
    elif args.ratio >= img1_ratio - args.rthreshold / 2:
        middle = img1
    else:
        tmp_img0 = img0
        tmp_img1 = img1
        for inference_cycle in range(args.rmaxcycles):
            print(inference_cycle)
            middle = model.inference(tmp_img0, tmp_img1)
            middle_ratio = ( img0_ratio + img1_ratio ) / 2
            if args.ratio - (args.rthreshold / 2) <= middle_ratio <= args.ratio + (args.rthreshold / 2):
                break
            if args.ratio > middle_ratio:
                tmp_img0 = middle
                img0_ratio = middle_ratio
            else:
                tmp_img1 = middle
                img1_ratio = middle_ratio
    img_list.append(middle)
    img_list.append(img1)
else:
    img_list = [img0, img1]
    for i in range(args.exp):
        tmp = []
        for j in range(len(img_list) - 1):
            print(j)
            printMem()
            print(img_list)
            mid = model.inference(img_list[j], img_list[j + 1])
            tmp.append(img_list[j])
            tmp.append(mid)
        tmp.append(img1)
        img_list = tmp

if not os.path.exists(args.folderOut):
    os.mkdir(args.folderOut)
for i in range(len(img_list)):
    if args.img[0].endswith('.exr') and args.img[1].endswith('.exr'):
        cv2.imwrite(args.folderOut+'/img{}.exr'.format(i), (img_list[i][0]).cpu().numpy().transpose(1, 2, 0)[:h, :w], [cv2.IMWRITE_EXR_TYPE, cv2.IMWRITE_EXR_TYPE_HALF])
    else:
        cv2.imwrite(args.folderOut+'/img{}.png'.format(i), (img_list[i][0] * 255).byte().cpu().numpy().transpose(1, 2, 0)[:h, :w])

print("Done now converting to video")
folderOut = args.folderOut
print(folderOut)
# Create video using ffmpeg
result = subprocess.run([
    "c:/GitHub/emulsion/lib/scripts/ffmpeg.exe", "-start_number", "1", "-i", os.path.join(folderOut, "img%d.png"), "-c:v", "vp9",
    "-s", "1920x1080", "-pix_fmt", "yuva420p", output_file
])
print("Done making video :::" + output_file + ":::")
# Remove generated tween frames
# for file in os.listdir(folderOut):
#     os.remove(os.path.join(folderOut, file))
