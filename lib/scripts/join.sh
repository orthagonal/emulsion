# folder, # of frames, ffmpeg parameters, outPath
ffmpeg  -start_number 1 -i $1/img%d.png -frames:v $2 $3 $4
