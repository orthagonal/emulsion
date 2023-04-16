# split into frames only scaled down to 120p
ffmpeg -i $1 -vf scale=160:120 $2/img_%04d.png -hide_banner
