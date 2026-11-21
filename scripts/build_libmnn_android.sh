#!/bin/bash
# Build the Android libMNN.so for the requested ABI.
# Usage:
#   ANDROID_NDK=/path/to/ndk ANDROID_ABI=armeabi-v7a scripts/build_libmnn_android.sh
#   ANDROID_NDK=/path/to/ndk ANDROID_ABI=arm64-v8a scripts/build_libmnn_android.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MNN="$ROOT/third_party/MNN"
: "${ANDROID_NDK:?set ANDROID_NDK}"
ABI="${ANDROID_ABI:-armeabi-v7a}"

case "$ABI" in
    armeabi-v7a|arm64-v8a) ;;
    *) echo "Unsupported Android ABI: $ABI" >&2; exit 2 ;;
esac

BUILD="$MNN/build_android_${ABI//-/_}"
COMMON=(
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake"
    -DCMAKE_BUILD_TYPE=Release
    -DANDROID_ABI="$ABI"
    -DANDROID_NATIVE_API_LEVEL=android-26
    -DANDROID_STL=c++_shared
    -DMNN_USE_SSE=OFF
    -DMNN_BUILD_FOR_ANDROID_COMMAND=true
    -DMNN_LOW_MEMORY=ON
    -DMNN_BUILD_DIFFUSION=ON
    -DMNN_BUILD_LLM=ON
    -DMNN_BUILD_OPENCV=ON
    -DMNN_IMGCODECS=ON
    -DMNN_OPENCL=ON
    -DMNN_SEP_BUILD=OFF
    -DMNN_SUPPORT_TRANSFORMER_FUSE=ON
    -DNATIVE_LIBRARY_OUTPUT=.
    -DNATIVE_INCLUDE_OUTPUT=.
)

mkdir -p "$BUILD"
cd "$BUILD"
cmake .. "${COMMON[@]}" -DMNN_USE_LOGCAT=ON
make -j"$(nproc)" MNN

OUT="$ROOT/qwenimage21/src/main/jniLibs/$ABI"
mkdir -p "$OUT"
cp libMNN.so "$OUT/libMNN.so"

# Headers are shared by both ABIs. Keep the existing checked-in headers.
mkdir -p "$ROOT/qwenimage21/src/main/cpp/include"
if [ ! -d "$ROOT/qwenimage21/src/main/cpp/include/MNN" ]; then
    cp -R "$MNN/include/MNN" "$ROOT/qwenimage21/src/main/cpp/include/"
fi
mkdir -p "$ROOT/qwenimage21/src/main/cpp/include/diffusion"
for header in diffusion.hpp qwen_image21_diffusion.hpp; do
    if [ -f "$MNN/transformers/diffusion/engine/include/diffusion/$header" ]; then
        cp "$MNN/transformers/diffusion/engine/include/diffusion/$header" \
           "$ROOT/qwenimage21/src/main/cpp/include/diffusion/"
    fi
done

echo "Built $OUT/libMNN.so for $ABI"
