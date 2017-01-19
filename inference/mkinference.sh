#/bin/bash

# $1 -- inference.cpp
# $2 -- ../cnn-densecrf-kitty-public/densecrf/
# $3 -- output folder

INFERENCE=${1:-inference.cpp}
DENSECRF=${2:-../cnn-densecrf-kitti-public/densecrf/}
OUT=${3:-./}

TMP=$(pwd)

mv "${DENSECRF}inference/inference.cpp" "${DENSECRF}inference/inference.cpp.bak"
cp "${INFERENCE}" "${DENSECRF}inference/inference.cpp"
cd "${DENSECRF}"
mkdir "build"
cd "build"
cmake -D CMAKE_BUILD_TYPE=Release ..
make
cd "$TMP"
cp "${DENSECRF}/build/inference/inference" "${OUT}inference"

# clean up
rm -r "${DENSECRF}build"
mv "${DENSECRF}inference/inference.cpp.bak" "${DENSECRF}inference/inference.cpp"