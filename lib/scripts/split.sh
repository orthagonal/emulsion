# split into frames
ffmpeg -i $1 $2/img_%04d.png -hide_banner
