# a script that generates the tween frames using rife and then joins the frames together in a video using ffmpeg

# $2 exponent frequency (number of frames) to be generated
# $3 filepath of the start frame
# $4 filepath of the end frame
# $5 ffmpeg parameters
# $6 final output video path, notifywhendone should watch for this file's existence

# exp table: 3 = 9 images (0-8)
# exp table: 4 = 17 images (0-16)
# exp table: 5 = 33 images (0-32) etc
frameCount=$((2**$2))
cd rife
python.exe inference_img.py --exp $2 --img $3 $4 --folderout ./temptween
ffmpeg  -start_number 1 -i ./temptween/img%d.png -frames:v $frameCount $5 $6
rm ./temptween/*