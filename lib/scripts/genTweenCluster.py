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
print(f"Source frame: {src_frame} Destination frame: {dest_frame} Tween exponent: {tween_exp} Output file: {output_file}")
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

def interpolate_frames(model, img_list, num_exp):
    for i in range(num_exp):
        tmp = []
        for j in range(len(img_list) - 1):
            # printMem()
            mid = model.inference(img_list[j], img_list[j + 1])
            tmp.append(img_list[j])
            tmp.append(mid)
        tmp.append(img_list[-1])
        img_list = tmp

    return img_list

def pad_image(img):
    """
    Pad the image so its height and width are divisible by 32.
    Return the padded image along with the original height and width.
    """
    n, c, h, w = img.shape
    ph = ((h - 1) // 32 + 1) * 32
    pw = ((w - 1) // 32 + 1) * 32
    padding = (0, pw - w, 0, ph - h)
    return F.pad(img, padding), h, w


device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"device is {device}")
torch.set_grad_enabled(False)
if torch.cuda.is_available():
    torch.backends.cudnn.enabled = True
    torch.backends.cudnn.benchmark = True

# Load Model
try:
    from model.RIFE_HDv2 import Model
    model = Model()
    model.load_model(args.modelDir, -1)
    print("Loaded v2.x HD model.")
except:
    try:
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

# Read Images
if args.img[0].endswith('.exr') and args.img[1].endswith('.exr'):
    img0 = cv2.imread(args.img[0], cv2.IMREAD_COLOR | cv2.IMREAD_ANYDEPTH)
    img1 = cv2.imread(args.img[1], cv2.IMREAD_COLOR | cv2.IMREAD_ANYDEPTH)
    img0 = (torch.tensor(img0.transpose(2, 0, 1)).to(device)).unsqueeze(0)
    img1 = (torch.tensor(img1.transpose(2, 0, 1)).to(device)).unsqueeze(0)
else:
    img0 = cv2.imread(args.img[0], cv2.IMREAD_UNCHANGED)
    img1 = cv2.imread(args.img[1], cv2.IMREAD_UNCHANGED)
    img0 = (torch.tensor(img0.transpose(2, 0, 1)).to(device) / 255.).unsqueeze(0)
    img1 = (torch.tensor(img1.transpose(2, 0, 1)).to(device) / 255.).unsqueeze(0)


# Pad Image
img0, h0, w0 = pad_image(img0)
img1, h1, w1 = pad_image(img1)


# First Generation
first_gen_folder = os.path.join(args.folderOut, 'first_generation')
if not os.path.exists(first_gen_folder):
    os.mkdir(first_gen_folder)

img_list = interpolate_frames(model, [img0, img1], args.exp)

# Save interpolated images of the first generation
for i in range(len(img_list)):
    if args.img[0].endswith('.exr') and args.img[1].endswith('.exr'):
        cv2.imwrite(os.path.join(first_gen_folder, f'img{i}.exr'), (img_list[i][0]).cpu().numpy().transpose(1, 2, 0)[:h0, :w0], [cv2.IMWRITE_EXR_TYPE, cv2.IMWRITE_EXR_TYPE_HALF])
    else:
        cv2.imwrite(os.path.join(first_gen_folder, f'img{i}.png'), (img_list[i][0] * 255).byte().cpu().numpy().transpose(1, 2, 0)[:h0, :w0])


# Second Generation
second_gen_folder = os.path.join(args.folderOut, 'second_generation')
if not os.path.exists(second_gen_folder):
    os.mkdir(second_gen_folder)

def second_gen_interpolation(src, tgt, exp, folderOut, direction):
    # Interpolate for the second generation
    img_list = interpolate_frames(model, [src, tgt], exp)

    second_gen_folder = os.path.join(folderOut, f'{direction}_generation')
    if not os.path.exists(second_gen_folder):
        os.mkdir(second_gen_folder)
    
    # Save interpolated images of the second generation
    for i in range(len(img_list)):
        cv2.imwrite(os.path.join(second_gen_folder, f'img{i}.png'), (img_list[i][0] * 255).byte().cpu().numpy().transpose(1, 2, 0)[:h1, :w1])

    # Convert the images in the second_generation folder into a video using ffmpeg
    result = subprocess.run([
        "c:/GitHub/emulsion/lib/scripts/ffmpeg.exe", 
        "-start_number", "1", 
        "-i", os.path.join(second_gen_folder, "img%d.png"), 
        "-c:v", "vp9",
        "-s", "1920x1080", 
        "-pix_fmt", "yuva420p", 
        f"{direction}_" + output_file# if direction == "reverse" else output_file
    ])

# Read the interpolated images from the first generation

first_frame_of_first_gen = os.path.join(first_gen_folder, 'img1.png')
img_fwd = cv2.imread(src_frame, cv2.IMREAD_UNCHANGED)
img_fwd = (torch.tensor(img_fwd.transpose(2, 0, 1)).to(device) / 255.).unsqueeze(0)
img_fwd, _, _ = pad_image(img_fwd)

img_rev = cv2.imread(first_frame_of_first_gen, cv2.IMREAD_UNCHANGED)
img_rev = (torch.tensor(img_rev.transpose(2, 0, 1)).to(device) / 255.).unsqueeze(0)
img_rev, _, _ = pad_image(img_rev)

# Interpolate and create video for the forward direction
second_gen_interpolation(img_fwd, img_rev, args.exp, args.folderOut, 'forward')

# Interpolate and create video for the reverse direction
second_gen_interpolation(img_rev, img_fwd, args.exp, args.folderOut, 'reverse')

# img0 = cv2.imread(src_frame, cv2.IMREAD_UNCHANGED)
# img1 = cv2.imread(first_frame_of_first_gen, cv2.IMREAD_UNCHANGED)
# img0 = (torch.tensor(img0.transpose(2, 0, 1)).to(device) / 255.).unsqueeze(0)
# img1 = (torch.tensor(img1.transpose(2, 0, 1)).to(device) / 255.).unsqueeze(0)

# img0, h0, w0 = pad_image(img0)
# img1, h1, w1 = pad_image(img1)

# Interpolate for the second generation
# img_list = interpolate_frames(model, [img0, img1], args.exp)

# # Save interpolated images of the second generation
# for i in range(len(img_list)):
#     cv2.imwrite(os.path.join(second_gen_folder, f'img{i}.png'), (img_list[i][0] * 255).byte().cpu().numpy().transpose(1, 2, 0)[:h1, :w1])

# # Convert the images in the second_generation folder into a video using ffmpeg
# result = subprocess.run([
#     "c:/GitHub/emulsion/lib/scripts/ffmpeg.exe", 
#     "-start_number", "1", 
#     "-i", os.path.join(second_gen_folder, "img%d.png"), 
#     "-c:v", "vp9",
#     "-s", "1920x1080", 
#     "-pix_fmt", "yuva420p", 
#     output_file
# ])
