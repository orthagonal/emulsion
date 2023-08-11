# make an alpha composition of two frames (input1 and input2) with x opacity
# $1: input1
# $2: input2
# $3: opacity
# $4: output
ffmpeg -i $1 -i $2 -filter_complex "[0][1]blend=all_mode='overlay':all_opacity=$3" $4
# echo "*************************************************************************************"
# echo "*************************************************************************************"
# echo "*************************************************************************************"
# echo "ffmpeg -i $1 -i $2 -filter_complex \"[0][1]blend=all_mode='overlay':all_opacity=$3\" $4"
