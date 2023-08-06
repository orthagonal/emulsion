# just transforms one image into a thumb
ffmpeg -i $1 -vf scale=160:120 $2 -hide_banner