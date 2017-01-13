#/bin/bash

# $1 -- inference.cpp
# $2 -- ../cnn-densecrf-kitty-public/densecrf/
# $3 -- output folder

if [ -z $1 ]
then 
    $1="inference.cpp"
fi

if [ -z $2 ]
then 
    $2="../cnn-densecrf-kitty-public/densecrf/"
fi

if [ -z $3 ]
then
    $3="./"
fi

mv "${2}inference/inference.cpp" "${2}inference/inference.cpp.bak"
cp $1 "${2}inference/inference.cpp"
cd $2
mkdir "build"
cd "build"
cmake ..
make
cp "inference/inference" "${3}inference"
cd ..

# clean up
rm -r "build"
mv "inference/inference.cpp.bak" "inference/inference.cpp"