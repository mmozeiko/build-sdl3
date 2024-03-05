@echo off
setlocal enabledelayedexpansion

cd %~dp0
set PATH=%CD%;%PATH%

rem
rem Required dependencies
rem

set NASM_VERSION=2.16.01
set YASM_VERSION=1.3.0
set NINJA_VERSION=1.11.1

set ZLIB_VERSION=1.3.1
set BZIP2_VERSION=1.0.8
set XZ_VERSION=5.6.1
set ZSTD_VERSION=1.5.5
set LIBPNG_VERSION=1.6.43
set LIBJPEGTURBO_VERSION=3.0.2
set JBIG_VERSION=2.1
set LERC_VERSION=4.0.0
set TIFF_VERSION=4.6.0
set LIBWEBP_VERSION=1.3.2
set AOM_VERSION=3.8.1
set LIBYUV_VERSION=464c51a
set DAV1D_VERSION=1.4.0
set LIBAVIF_VERSION=1.0.4
set LIBJXL_VERSION=0.10.2
set FREETYPE_VERSION=2.13.2
set HARFBUZZ_VERSION=8.3.1
set LIBOGG_VERSION=1.3.5
set LIBVORBIS_VERSION=1.3.7
set OPUS_VERSION=1.5.1
set OPUSFILE_VERSION=0.12
set FLAC_VERSION=1.4.3
set MPG123_VERSION=1.32.5
set LIBXMP_VERSION=4.6.0
set WAVPACK_VERSION=5.7.0

rem libjxl dependencies

set BROTLI_COMMIT=36533a8
set HIGHWAY_COMMIT=58b52a7
set SKCMS_COMMIT=42030a7

rem
rem dependencies
rem

where /q git.exe || (
  echo ERROR: "git.exe" not found
  exit /b 1
)

where /q curl.exe || (
  echo ERROR: "curl.exe" not found
  exit /b 1
)

where /q cmake.exe || (
  echo ERROR: "cmake.exe" not found
  exit /b 1
)

where /q perl.exe || (
  echo ERROR: "perl.exe" not found
  exit /b 1
)

where /q python.exe || (
  echo ERROR: "python.exe" not found
  exit /b 1
)

where /q pip.exe || (
  echo ERROR: "pip.exe" not found
  exit /b 1
)

pip install meson 1>nul 2>nul || exit /b 1

rem
rem 7-Zip
rem

if exist "%ProgramFiles%\7-Zip\7z.exe" (
  set SZIP="%ProgramFiles%\7-Zip\7z.exe"
) else (
  where /q 7za.exe || (
    echo ERROR: 7-Zip installation or "7za.exe" not found
    exit /b 1
  )
  set SZIP=7za.exe
)

rem
rem yasm.exe & nasm.exe & ninja.exe
rem

where /q nasm.exe || (
  echo Downloading nasm.exe
  curl.exe -sfLO "https://www.nasm.us/pub/nasm/releasebuilds/%NASM_VERSION%/win64/nasm-%NASM_VERSION%-win64.zip"
  %SZIP% x -bb0 -y nasm-%NASM_VERSION%-win64.zip nasm-%NASM_VERSION%\nasm.exe 1>nul 2>nul || exit /b 1
  move nasm-%NASM_VERSION%\nasm.exe nasm.exe
  rd /s /q nasm-%NASM_VERSION%
)
nasm.exe --version || exit /b 1

where /q yasm.exe || (
  echo Downloading yasm.exe
  curl -sfLo yasm.exe https://www.tortall.net/projects/yasm/releases/yasm-%YASM_VERSION%-win64.exe || exit /b 1

  if "%GITHUB_WORKFLOW%" neq "" (
    rem Install VS2010 redistributable
    curl -sfLO https://download.microsoft.com/download/3/2/2/3224B87F-CFA0-4E70-BDA3-3DE650EFEBA5/vcredist_x64.exe || exit /b 1
    start /wait vcredist_x64.exe /q /norestart
    del /q vcredist_x64.exe
  )
)
yasm.exe --version || exit /b 1

where /q ninja.exe || (
  echo Downloading ninja.exe
  curl.exe -sfLO "https://github.com/ninja-build/ninja/releases/download/v%NINJA_VERSION%/ninja-win.zip"
  %SZIP% x -bb0 -y ninja-win.zip 1>nul 2>nul || exit /b 1
  del "ninja-win.zip"
)
ninja.exe --version || exit /b 1


rem
rem MSVC environment
rem

where /Q cl.exe || (
  set __VSCMD_ARG_NO_LOGO=1
  for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
  if "!VS!" equ "" (
    echo ERROR: Visual Studio installation not found
    exit /b 1
  )  
  call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" amd64 || exit /b 1

  set MSVC_GENERATOR="Visual Studio 17 2022"
)

rem
rem output folder
rem

set OUTPUT=%~dp0SDL3
if not exist %OUTPUT% mkdir %OUTPUT%

rem
rem temporary folders
rem

set DEPEND=%~dp0depend
set DOWNLOAD=%~dp0download
set BUILD=%~dp0build
if not exist %DEPEND%   mkdir %DEPEND%
if not exist %DOWNLOAD% mkdir %DOWNLOAD%
if not exist %BUILD%    mkdir %BUILD%

set CL=-MP -I%OUTPUT%\include -I%OUTPUT%\include\SDL3 -I%DEPEND%\include  ^
  -wd4244 -wd4267 -wd4996 -wd4305 -wd4311 -wd4005 -wd4018 -wd4068 -wd4146 ^
  -wd4334 -wd4312 -wd4090 -wd4180 -wd4806 -wd4646 -wd4805 -wd4389
set LINK=-incremental:no -libpath:%OUTPUT%\lib -libpath:%DEPEND%\lib

rem
rem downloading & unpacking
rem

call :get "https://github.com/madler/zlib/releases/download/v%ZLIB_VERSION%/zlib-%ZLIB_VERSION%.tar.xz"                                                     || exit /b 1
call :get "https://sourceware.org/pub/bzip2/bzip2-%BZIP2_VERSION%.tar.gz"                                                                                   || exit /b 1
call :get "https://github.com/tukaani-project/xz/releases/download/v%XZ_VERSION%/xz-%XZ_VERSION%.tar.xz"                                                    || exit /b 1
call :get "https://github.com/facebook/zstd/releases/download/v%ZSTD_VERSION%/zstd-%ZSTD_VERSION%.tar.gz"                                                   || exit /b 1
call :get "https://download.sourceforge.net/libpng/libpng-%LIBPNG_VERSION%.tar.xz"                                                                          || exit /b 1
call :get "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/%LIBJPEGTURBO_VERSION%/libjpeg-turbo-%LIBJPEGTURBO_VERSION%.tar.gz"             || exit /b 1
call :get "https://www.cl.cam.ac.uk/~mgk25/jbigkit/download/jbigkit-%JBIG_VERSION%.tar.gz"                                                                  || exit /b 1
call :get "https://github.com/Esri/lerc/archive/refs/tags/v%LERC_VERSION%.tar.gz" lerc-%LERC_VERSION%.tar.gz                                                || exit /b 1
call :get "https://download.osgeo.org/libtiff/tiff-%TIFF_VERSION%.tar.gz"                                                                                   || exit /b 1
call :get "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-%LIBWEBP_VERSION%.tar.gz"                                         || exit /b 1
call :get "https://storage.googleapis.com/aom-releases/libaom-%AOM_VERSION%.tar.gz"                                                                         || exit /b 1
call :get "https://chromium.googlesource.com/libyuv/libyuv/+archive/%LIBYUV_VERSION%.tar.gz" libyuv-%LIBYUV_VERSION%.tar.gz %BUILD%\libyuv-%LIBYUV_VERSION% || exit /b 1
call :get "https://code.videolan.org/videolan/dav1d/-/archive/%DAV1D_VERSION%/dav1d-%DAV1D_VERSION%.tar.bz2"                                                || exit /b 1
call :get "https://github.com/AOMediaCodec/libavif/archive/refs/tags/v%LIBAVIF_VERSION%.tar.gz" libavif-%LIBAVIF_VERSION%.tar.gz                            || exit /b 1
call :get "https://github.com/libjxl/libjxl/archive/refs/tags/v%LIBJXL_VERSION%.tar.gz" libjxl-%LIBJXL_VERSION%.tar.gz                                      || exit /b 1
call :get "https://download.savannah.gnu.org/releases/freetype/freetype-%FREETYPE_VERSION%.tar.xz"                                                          || exit /b 1
call :get "https://github.com/harfbuzz/harfbuzz/releases/download/%HARFBUZZ_VERSION%/harfbuzz-%HARFBUZZ_VERSION%.tar.xz"                                    || exit /b 1
call :get "https://downloads.xiph.org/releases/ogg/libogg-%LIBOGG_VERSION%.tar.xz"                                                                          || exit /b 1
call :get "https://downloads.xiph.org/releases/vorbis/libvorbis-%LIBVORBIS_VERSION%.tar.xz"                                                                 || exit /b 1
call :get "https://downloads.xiph.org/releases/opus/opus-%OPUS_VERSION%.tar.gz"                                                                             || exit /b 1
call :get "https://downloads.xiph.org/releases/opus/opusfile-%OPUSFILE_VERSION%.tar.gz"                                                                     || exit /b 1
call :get "https://downloads.xiph.org/releases/flac/flac-%FLAC_VERSION%.tar.xz"                                                                             || exit /b 1
call :get "https://download.sourceforge.net/mpg123/mpg123-%MPG123_VERSION%.tar.bz2"                                                                         || exit /b 1
call :get "https://github.com/libxmp/libxmp/releases/download/libxmp-%LIBXMP_VERSION%/libxmp-%LIBXMP_VERSION%.tar.gz"                                       || exit /b 1
call :get "https://github.com/dbry/WavPack/releases/download/%WAVPACK_VERSION%/wavpack-%WAVPACK_VERSION%.tar.xz"                                            || exit /b 1

rd /s /q %BUILD%\libjxl-%LIBJXL_VERSION%\third_party\brotli  1>nul 2>nul
rd /s /q %BUILD%\libjxl-%LIBJXL_VERSION%\third_party\highway 1>nul 2>nul

call :get "https://github.com/google/brotli/tarball/%BROTLI_COMMIT%"           google-brotli-%BROTLI_COMMIT%.tar.gz     || exit /b 1
call :get "https://github.com/google/highway/tarball/%HIGHWAY_COMMIT%"         google-highway-%HIGHWAY_COMMIT%.tar.gz   || exit /b 1
call :get "https://skia.googlesource.com/skcms/+archive/%SKCMS_COMMIT%.tar.gz" skcms-%SKCMS_COMMIT%.tar.gz %BUILD%\libjxl-%LIBJXL_VERSION%\third_party\skcms || exit /b 1

move %BUILD%\google-brotli-%BROTLI_COMMIT%     %BUILD%\libjxl-%LIBJXL_VERSION%\third_party\brotli  1>nul 2>nul
move %BUILD%\google-highway-%HIGHWAY_COMMIT%   %BUILD%\libjxl-%LIBJXL_VERSION%\third_party\highway 1>nul 2>nul

call :clone SDL       "https://github.com/libsdl-org/SDL"       main || exit /b 1
call :clone SDL_image "https://github.com/libsdl-org/SDL_image" main || exit /b 1
call :clone SDL_mixer "https://github.com/libsdl-org/SDL_mixer" main || exit /b 1
call :clone SDL_ttf   "https://github.com/libsdl-org/SDL_ttf"   main || exit /b 1
call :clone SDL_rtf   "https://github.com/libsdl-org/SDL_rtf"   main || exit /b 1
call :clone SDL_net   "https://github.com/libsdl-org/SDL_net"   main || exit /b 1

rem
rem zlib
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\zlib-%ZLIB_VERSION%             ^
  -B %BUILD%\zlib-%ZLIB_VERSION%             ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  || exit /b 1
cmake.exe --build %BUILD%\zlib-%ZLIB_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem bzip2
rem

pushd %BUILD%\bzip2-%BZIP2_VERSION%
cl.exe -c -MP -MT -O2 -DNDEBUG blocksort.c huffman.c crctable.c randtable.c compress.c decompress.c bzlib.c        || exit /b 1
lib.exe -nologo -out:libbz2.lib *.obj || exit /b 1
copy /y libbz2.lib %DEPEND%\lib\
copy /y bzlib.h    %DEPEND%\include\
popd

rem
rem xz
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\xz-%XZ_VERSION%                 ^
  -B %BUILD%\xz-%XZ_VERSION%                 ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DBUILD_SHARED_LIBS=OFF                    ^
  -DENABLE_NLS=OFF                           ^
  || exit /b 1
cmake.exe --build %BUILD%\xz-%XZ_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem zstd
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\zstd-%ZSTD_VERSION%\build\cmake ^
  -B %BUILD%\zstd-%ZSTD_VERSION%             ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DZSTD_BUILD_PROGRAMS=OFF                  ^
  -DZSTD_BUILD_STATIC=ON                     ^
  -DZSTD_BUILD_SHARED=OFF                    ^
  -DZSTD_USE_STATIC_RUNTIME=ON               ^
  || exit /b 1
cmake.exe --build %BUILD%\zstd-%ZSTD_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem libpng
rem dependencies: zlib
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\libpng-%LIBPNG_VERSION%         ^
  -B %BUILD%\libpng-%LIBPNG_VERSION%         ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DPNG_SHARED=OFF                           ^
  -DPNG_TESTS=OFF                            ^
  || exit /b 1
cmake.exe --build %BUILD%\libpng-%LIBPNG_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem libjpeg-turbo
rem

cmake.exe -Wno-dev                                ^
  -S %BUILD%\libjpeg-turbo-%LIBJPEGTURBO_VERSION% ^
  -B %BUILD%\libjpeg-turbo-%LIBJPEGTURBO_VERSION% ^
  -A x64 -T host=x64                              ^
  -G %MSVC_GENERATOR%                             ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%                 ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW              ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded      ^
  -DENABLE_SHARED=OFF                             ^
  -DENABLE_STATIC=ON                              ^
  -DREQUIRE_SIMD=ON                               ^
  -DWITH_TURBOJPEG=OFF                            ^
  || exit /b 1
cmake.exe --build %BUILD%\libjpeg-turbo-%LIBJPEGTURBO_VERSION% --config Release --target install || exit /b 1

rem
rem libwebp
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\libwebp-%LIBWEBP_VERSION%       ^
  -B %BUILD%\libwebp-%LIBWEBP_VERSION%       ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DWEBP_BUILD_ANIM_UTILS=OFF                ^
  -DWEBP_BUILD_CWEBP=OFF                     ^
  -DWEBP_BUILD_DWEBP=OFF                     ^
  -DWEBP_BUILD_GIF2WEBP=OFF                  ^
  -DWEBP_BUILD_IMG2WEBP=OFF                  ^
  -DWEBP_BUILD_VWEBP=OFF                     ^
  -DWEBP_BUILD_WEBPINFO=OFF                  ^
  -DWEBP_BUILD_WEBPMUX=OFF                   ^
  -DWEBP_BUILD_EXTRAS=OFF                    ^
  || exit /b 1
cmake.exe --build %BUILD%\libwebp-%LIBWEBP_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem jbig
rem

pushd %BUILD%\jbigkit-%JBIG_VERSION%
cl.exe -c -MP -MT -O2 libjbig\jbig.c libjbig\jbig_ar.c || exit /b 1
lib.exe -nologo -out:jbig.lib *.obj || exit /b 1
copy /y jbig.lib %DEPEND%\lib\
copy /y libjbig\jbig.h    %DEPEND%\include\
copy /y libjbig\jbig_ar.h %DEPEND%\include\
popd

rem
rem lerc
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\lerc-%LERC_VERSION%             ^
  -B %BUILD%\lerc-%LERC_VERSION%             ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DBUILD_SHARED_LIBS=OFF                    ^
  || exit /b 1
cmake.exe --build %BUILD%\lerc-%LERC_VERSION% --config Release --target install || exit /b 1

rem
rem tiff
rem dependencies: libjpeg-turbo, libwebp, jbig, lerc, zstd, xz, zlib
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\tiff-%TIFF_VERSION%             ^
  -B %BUILD%\tiff-%TIFF_VERSION%             ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DCMAKE_C_FLAGS=-DLZMA_API_STATIC          ^
  -Dzlib=ON                                  ^
  -Djpeg=ON                                  ^
  -Dlzma=ON                                  ^
  -Dzstd=ON                                  ^
  -Dwebp=ON                                  ^
  -Djbig=ON                                  ^
  -Dlerc=ON                                  ^
  -Dtiff-tools=OFF                           ^
  -Dtiff-tests=OFF                           ^
  -Dtiff-contrib=OFF                         ^
  -Dtiff-docs=OFF                            ^
  -Dtiff-opengl=OFF                          ^
  -DBUILD_SHARED_LIBS=OFF                    ^
  || exit /b 1
cmake.exe --build %BUILD%\tiff-%TIFF_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem aom
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\libaom-%AOM_VERSION%            ^
  -B %BUILD%\libaom-%AOM_VERSION%\build      ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DAOM_TARGET_CPU=x86_64                    ^
  -DENABLE_EXAMPLES=OFF                      ^
  -DENABLE_TESTDATA=OFF                      ^
  -DENABLE_TESTS=OFF                         ^
  -DENABLE_TOOLS=OFF                         ^
  -DENABLE_DOCS=OFF                          ^
  || exit /b 1
cmake.exe --build %BUILD%\libaom-%AOM_VERSION%\build --config Release --target install --parallel || exit /b 1

rem
rem libyuv
rem

echo CMAKE_MINIMUM_REQUIRED( VERSION 2.8.12 ) > "%BUILD%\libyuv-%LIBYUV_VERSION%\CMakeLists.txt.correct"
move "%BUILD%\libyuv-%LIBYUV_VERSION%\CMakeLists.txt" "%BUILD%\libyuv-%LIBYUV_VERSION%\CMakeLists.txt.old"
type "%BUILD%\libyuv-%LIBYUV_VERSION%\CMakeLists.txt.correct" "%BUILD%\libyuv-%LIBYUV_VERSION%\CMakeLists.txt.old" > "%BUILD%\libyuv-%LIBYUV_VERSION%\CMakeLists.txt"
del "%BUILD%\libyuv-%LIBYUV_VERSION%\CMakeLists.txt.correct" "%BUILD%\libyuv-%LIBYUV_VERSION%\CMakeLists.txt.old"

cmake.exe -Wno-dev                           ^
  -S %BUILD%\libyuv-%LIBYUV_VERSION%         ^
  -B %BUILD%\libyuv-%LIBYUV_VERSION%\build   ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  || exit /b 1
cmake.exe --build %BUILD%\libyuv-%LIBYUV_VERSION%\build --config Release --target yuv --parallel || exit /b 1
copy /Y "%BUILD%\libyuv-%LIBYUV_VERSION%\build\Release\yuv.lib" "%DEPEND%\lib"
xcopy /Y /E "%BUILD%\libyuv-%LIBYUV_VERSION%\include" "%DEPEND%\include"

rem
rem dav1d
rem

pushd %BUILD%\dav1d-%DAV1D_VERSION%

mkdir build
cd build

meson ^
  --prefix=%DEPEND% ^
  --default-library=static ^
  --buildtype release ^
  -Db_ndebug=true ^
  -Db_vscrt=mt ^
  -Denable_tools=false ^
  -Denable_tests=false ^
  -Dlogging=false ^
  .. || exit /b 1
ninja install || exit /b 1

popd

rem
rem libavif
rem dependencies: dav1d, aom, libyuv, libsharpyuv (part of libwebp)
rem

cmake.exe -Wno-dev                                   ^
  -S %BUILD%\libavif-%LIBAVIF_VERSION%               ^
  -B %BUILD%\libavif-%LIBAVIF_VERSION%\build         ^
  -A x64 -T host=x64                                 ^
  -G %MSVC_GENERATOR%                                ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%                    ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW                 ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded         ^
  -DBUILD_SHARED_LIBS=OFF                            ^
  -DAVIF_ENABLE_WERROR=OFF                           ^
  -DAVIF_CODEC_DAV1D=ON                              ^
  -DAVIF_CODEC_AOM=ON                                ^
  -DAVIF_CODEC_AOM_DECODE=OFF                        ^
  -DDAV1D_LIBRARIES=%DEPEND%\lib                     ^
  -DDAV1D_LIBRARY=%DEPEND%\lib\libdav1d.a            ^
  -DLIBSHARPYUV_INCLUDE_DIR=%DEPEND%\include\webp    ^
  -DLIBSHARPYUV_LIBRARY=%DEPEND%\lib\libsharpyuv.lib ^
  || exit /b 1
cmake.exe --build %BUILD%\libavif-%LIBAVIF_VERSION%\build --config Release --target install --parallel || exit /b 1

rem
rem libjxl
rem

set CFLAGS=-DJXL_STATIC_DEFINE
set CXXFLAGS=-DJXL_STATIC_DEFINE

cmake.exe -Wno-dev                           ^
  -S %BUILD%\libjxl-%LIBJXL_VERSION%         ^
  -B %BUILD%\libjxl-%LIBJXL_VERSION%\build   ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DBUILD_SHARED_LIBS=OFF                    ^
  -DBUILD_TESTING=OFF                        ^
  -DJPEGXL_STATIC=true                       ^
  -DJPEGXL_WARNINGS_AS_ERRORS=false          ^
  -DJPEGXL_ENABLE_TOOLS=false                ^
  -DJPEGXL_ENABLE_DOXYGEN=false              ^
  -DJPEGXL_ENABLE_MANPAGES=false             ^
  -DJPEGXL_ENABLE_BENCHMARK=false            ^
  -DJPEGXL_ENABLE_EXAMPLES=false             ^
  -DJPEGXL_ENABLE_VIEWERS=false              ^
  -DJPEGXL_ENABLE_JNI=false                  ^
  -DJPEGXL_ENABLE_SJPEG=false                ^
  -DJPEGXL_ENABLE_OPENEXR=false              ^
  -DJPEGXL_ENABLE_PLUGINS=false              ^
  -DJPEGXL_ENABLE_SKCMS=true                 ^
  -DJPEGXL_ENABLE_AVX512=true                ^
  -DJPEGXL_ENABLE_AVX512_SPR=true            ^
  -DJPEGXL_ENABLE_AVX512_ZEN4=true           ^
  || exit /b 1
cmake.exe --build %BUILD%\libjxl-%LIBJXL_VERSION%\build --config Release --target install --parallel || exit /b 1

set CFLAGS=
set CXXFLAGS=

rem
rem freetype
rem dependencies: zlib, bzip2, libpng
rem

cmake.exe -Wno-dev                             ^
  -S %BUILD%\freetype-%FREETYPE_VERSION%       ^
  -B %BUILD%\freetype-%FREETYPE_VERSION%\build ^
  -A x64 -T host=x64                           ^
  -G %MSVC_GENERATOR%                          ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%              ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW           ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded   ^
  -DBUILD_SHARED_LIBS=OFF                      ^
  -DFT_DISABLE_BROTLI=ON                       ^
  || exit /b 1
cmake.exe --build %BUILD%\freetype-%FREETYPE_VERSION%\build --config Release --target install --parallel || exit /b 1

rem
rem harfbuzz
rem dependencies: freetype
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\harfbuzz-%HARFBUZZ_VERSION%     ^
  -B %BUILD%\harfbuzz-%HARFBUZZ_VERSION%     ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DBUILD_SHARED_LIBS=OFF                    ^
  -DHB_HAVE_FREETYPE=ON                      ^
  || exit /b 1
cmake.exe --build %BUILD%\harfbuzz-%HARFBUZZ_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem libogg
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\libogg-%LIBOGG_VERSION%         ^
  -B %BUILD%\libogg-%LIBOGG_VERSION%         ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DBUILD_SHARED_LIBS=OFF                    ^
  -DINSTALL_DOCS=OFF                         ^
  || exit /b 1
cmake.exe --build %BUILD%\libogg-%LIBOGG_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem libvorbis
rem dependencies: libogg
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\libvorbis-%LIBVORBIS_VERSION%   ^
  -B %BUILD%\libvorbis-%LIBVORBIS_VERSION%   ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DBUILD_SHARED_LIBS=OFF                    ^
  || exit /b 1
cmake.exe --build %BUILD%\libvorbis-%LIBVORBIS_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem opus
rem dependencies: libogg
rem

echo. > %BUILD%\opus-%OPUS_VERSION%\opus_buildtype.cmake
cmake.exe -Wno-dev                           ^
  -S %BUILD%\opus-%OPUS_VERSION%             ^
  -B %BUILD%\opus-%OPUS_VERSION%             ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DBUILD_SHARED_LIBS=OFF                    ^
  || exit /b 1
cmake.exe --build %BUILD%\opus-%OPUS_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem opusfile
rem dependencies: opus
rem

pushd %BUILD%\opusfile-%OPUSFILE_VERSION%
cl.exe -c -MP -MT -O2 -DNDEBUG -Iinclude -I%DEPEND%\include\opus ^
  src\info.c src\internal.c src\opusfile.c src\stream.c ^
  || exit /b 1
lib.exe -nologo -out:opusfile.lib *.obj || exit /b 1
copy /y opusfile.lib       %DEPEND%\lib\
copy /y include\opusfile.h %DEPEND%\include\opus\
popd

rem
rem flac
rem dependencies: libogg
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\flac-%FLAC_VERSION%             ^
  -B %BUILD%\flac-%FLAC_VERSION%             ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DBUILD_SHARED_LIBS=OFF                    ^
  -DBUILD_CXXLIBS=OFF                        ^
  -DBUILD_EXAMPLES=OFF                       ^
  -DBUILD_DOCS=OFF                           ^
  -DINSTALL_MANPAGES=OFF                     ^
  || exit /b 1
cmake.exe --build %BUILD%\flac-%FLAC_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem mpg123
rem

cmake.exe -Wno-dev                               ^
  -S %BUILD%\mpg123-%MPG123_VERSION%\ports\cmake ^
  -B %BUILD%\mpg123-%MPG123_VERSION%             ^
  -A x64 -T host=x64                             ^
  -G %MSVC_GENERATOR%                            ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%                ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW             ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded     ^
  -DBUILD_SHARED_LIBS=OFF                        ^
  -DBUILD_LIBOUT123=OFF                          ^
  || exit /b 1
cmake.exe --build %BUILD%\mpg123-%MPG123_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem libxmp
rem

cmake.exe -Wno-dev                               ^
  -S %BUILD%\libxmp-%LIBXMP_VERSION%             ^
  -B %BUILD%\libxmp-%LIBXMP_VERSION%             ^
  -A x64 -T host=x64                             ^
  -G %MSVC_GENERATOR%                            ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%                ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW             ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded     ^
  -DBUILD_STATIC=ON                              ^
  -DBUILD_SHARED=OFF                             ^
  -DLIBXMP_DOCS=OFF                              ^
  || exit /b 1
cmake.exe --build %BUILD%\libxmp-%LIBXMP_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem wavpack
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\wavpack-%WAVPACK_VERSION%       ^
  -B %BUILD%\wavpack-%WAVPACK_VERSION%       ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DCMAKE_ASM_COMPILER=ml64.exe              ^
  -DCMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DWAVPACK_INSTALL_DOCS=OFF                 ^
  -DWAVPACK_ENABLE_LIBCRYPTO=OFF             ^
  -DWAVPACK_BUILD_PROGRAMS=OFF               ^
  -DWAVPACK_BUILD_COOLEDIT_PLUGIN=OFF        ^
  -DWAVPACK_BUILD_WINAMP_PLUGIN=OFF          ^
  -DBUILD_SHARED_LIBS=OFF                    ^
  || exit /b 1
cmake.exe --build %BUILD%\wavpack-%WAVPACK_VERSION% --config Release --target install --parallel || exit /b 1

rem
rem SDL
rem

cmake.exe -Wno-dev                           ^
  -S %BUILD%\SDL                             ^
  -B %BUILD%\SDL\build                       ^
  -A x64 -T host=x64                         ^
  -G %MSVC_GENERATOR%                        ^
  -DSDL_DISABLE_INSTALL_DOCS=ON              ^
  -DCMAKE_INSTALL_PREFIX=%OUTPUT%            ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DBUILD_SHARED_LIBS=ON                     ^
  || exit /b 1
cmake.exe --build %BUILD%\SDL\build --config Release --target install --parallel || exit /b 1

rem
rem SDL_image
rem dependencies: avif, libjxl, tiff, libjpeg-turbo, libpng, libwebp
rem

pushd %BUILD%\SDL_image
rc.exe -nologo src\version.rc || exit /b 1
cl.exe -MP -MT -O2 -Iinclude -DDLL_EXPORT -DJXL_STATIC_DEFINE -DNDEBUG -DWIN32 ^
  -DSDL_IMAGE_SAVE_AVIF=1 -DSDL_IMAGE_SAVE_PNG=1 -DSDL_IMAGE_SAVE_JPG=1 ^
  -DLOAD_AVIF -DLOAD_BMP -DLOAD_GIF -DLOAD_JPG -DLOAD_JXL -DLOAD_LBM -DLOAD_PCX -DLOAD_PNG -DLOAD_PNM -DLOAD_QOI ^
  -DLOAD_SVG -DLOAD_TGA -DLOAD_TIF -DLOAD_WEBP -DLOAD_XCF -DLOAD_XPM -DLOAD_XV src\IMG.c src\IMG_avif.c src\IMG_bmp.c ^
  src\IMG_gif.c src\IMG_jpg.c src\IMG_jxl.c src\IMG_lbm.c src\IMG_pcx.c src\IMG_png.c src\IMG_pnm.c src\IMG_qoi.c ^
  src\IMG_svg.c src\IMG_tga.c src\IMG_tif.c src\IMG_webp.c src\IMG_xcf.c src\IMG_xpm.c src\IMG_xv.c src\version.res ^
  -link -dll -opt:icf -opt:ref -out:SDL3_image.dll -libpath:%BUILD%\libjxl-%LIBJXL_VERSION%\build\third_party\brotli\Release ^
  SDL3.lib avif.lib libdav1d.a aom.lib yuv.lib jxl.lib brotlicommon.lib brotlidec.lib hwy.lib tiff.lib jpeg-static.lib ^
  libpng16_static.lib libsharpyuv.lib libwebp.lib libwebpdemux.lib jbig.lib lerc.lib zstd_static.lib liblzma.lib zlibstatic.lib ^
  || exit /b 1
copy /y include\SDL3_image\SDL_image.h %OUTPUT%\include\SDL3\
copy /y SDL3_image.dll                 %OUTPUT%\bin\
copy /y SDL3_image.lib                 %OUTPUT%\lib\
popd

rem
rem SDL_mixer
rem dependencies: libxmp, mpg123, flac, opusfile, vorbis, wavpack
rem

pushd %BUILD%\SDL_mixer
rc.exe -nologo src\version.rc || exit /b 1
cl.exe -MP -MT -O2 -Iinclude -DDECLSPEC=__declspec(dllexport) -DNDEBUG -DWIN32 -DLIBXMP_STATIC -DFLAC__NO_DLL ^
  -DMUSIC_WAV -DMUSIC_MOD_XMP -DMUSIC_OGG -DMUSIC_OPUS -DMUSIC_FLAC_LIBFLAC -DMUSIC_WAVPACK -DMUSIC_MP3_MPG123 -DMUSIC_MID_TIMIDITY -DMUSIC_MID_NATIVE ^
  src\*.c src\codecs\*.c src\codecs\timidity\*.c src\codecs\native_midi\native_midi_common.c src\codecs\native_midi\native_midi_win32.c src\version.res ^
  -Iinclude -Isrc -Isrc\codecs -I%DEPEND%\include\opus ^
  -link -dll -opt:icf -opt:ref -out:SDL3_mixer.dll ^
  SDL3.lib libxmp-static.lib mpg123.lib flac.lib libwavpack.lib opusfile.lib opus.lib vorbisfile.lib vorbis.lib ogg.lib winmm.lib user32.lib shlwapi.lib ^
  || exit /b 1
copy /y include\SDL3_mixer\SDL_mixer.h %OUTPUT%\include\SDL3\
copy /y SDL3_mixer.dll                 %OUTPUT%\bin\
copy /y SDL3_mixer.lib                 %OUTPUT%\lib\
popd

rem
rem SDL_ttf
rem dependencies: freetype, harfbuzz
rem

pushd %BUILD%\SDL_ttf
rc.exe -nologo src\version.rc || exit /b 1
cl.exe -MP -MT -O2 -Iinclude -DDLL_EXPORT -DNDEBUG -DWIN32 -DTTF_USE_HARFBUZZ=1 ^
  src\SDL_ttf.c src\version.res ^
  -I%DEPEND%\include\freetype2 -I%DEPEND%\include\harfbuzz ^
  -link -dll -opt:icf -opt:ref -out:SDL3_ttf.dll ^
  SDL3.lib harfbuzz.lib freetype.lib libpng16_static.lib libbz2.lib zlibstatic.lib ^
  || exit /b 1
copy /y include\SDL3_ttf\SDL_ttf.h %OUTPUT%\include\SDL3\
copy /y SDL3_ttf.dll               %OUTPUT%\bin\
copy /y SDL3_ttf.lib               %OUTPUT%\lib\
popd

rem
rem SDL_rtf
rem

pushd %BUILD%\SDL_rtf
rc.exe -nologo src\version.rc || exit /b 1
cl.exe -MP -MT -O2 -DDLL_EXPORT -DNDEBUG -DWIN32 ^
  -Iinclude src\*.c src\version.res ^
  -link -dll -opt:icf -opt:ref -out:SDL3_rtf.dll SDL3.lib ^
  || exit /b 1
copy /y include\SDL3_rtf\SDL_rtf.h %OUTPUT%\include\SDL3\
copy /y SDL3_rtf.dll               %OUTPUT%\bin\
copy /y SDL3_rtf.lib               %OUTPUT%\lib\
popd

rem
rem SDL_net
rem

pushd %BUILD%\SDL_net
rc.exe -nologo src\version.rc || exit /b 1
cl.exe -MP -MT -O2 -Iinclude -DDLL_EXPORT -DNDEBUG -DWIN32 ^
  src\SDL_net.c src\version.res ^
  -link -dll -opt:icf -opt:ref -out:SDL3_net.dll SDL3.lib ws2_32.lib iphlpapi.lib ^
  || exit /b 1
copy /y include\SDL3_net\SDL_net.h %OUTPUT%\include\SDL3\
copy /y SDL3_net.dll               %OUTPUT%\bin\
copy /y SDL3_net.lib               %OUTPUT%\lib\
popd


rem
rem output commits
rem

set /p SDL_COMMIT=<%BUILD%\SDL\.git\refs\heads\main
set /p SDL_IMAGE_COMMIT=<%BUILD%\SDL_image\.git\refs\heads\main
set /p SDL_MIXER_COMMIT=<%BUILD%\SDL_mixer\.git\refs\heads\main
set /p SDL_TTF_COMMIT=<%BUILD%\SDL_ttf\.git\refs\heads\main
set /p SDL_RTF_COMMIT=<%BUILD%\SDL_rtf\.git\refs\heads\main
set /p SDL_NET_COMMIT=<%BUILD%\SDL_net\.git\refs\heads\main

echo SDL commit %SDL_COMMIT% > %OUTPUT%\commits.txt
echo SDL_image commit %SDL_IMAGE_COMMIT% >> %OUTPUT%\commits.txt
echo SDL_mixer commit %SDL_MIXER_COMMIT% >> %OUTPUT%\commits.txt
echo SDL_ttf commit %SDL_TTF_COMMIT% >> %OUTPUT%\commits.txt
echo SDL_rtf commit %SDL_RTF_COMMIT% >> %OUTPUT%\commits.txt
echo SDL_net commit %SDL_NET_COMMIT% >> %OUTPUT%\commits.txt

rem
rem GitHub actions stuff
rem

if "%GITHUB_WORKFLOW%" neq "" (

  for /F "skip=1" %%D in ('WMIC OS GET LocalDateTime') do (set LDATE=%%D & goto :dateok)
  :dateok
  set OUTPUT_DATE=%LDATE:~0,4%-%LDATE:~4,2%-%LDATE:~6,2%

  echo Creating %OUTPUT%.zip
  %SZIP% a -y -r -mx=9 "-x^!build" SDL3-!OUTPUT_DATE!.zip SDL3 || exit /b 1

  echo ::set-output name=OUTPUT_DATE::!OUTPUT_DATE!

  echo ::set-output name=SDL_COMMIT::%SDL_COMMIT%
  echo ::set-output name=SDL_IMAGE_COMMIT::%SDL_IMAGE_COMMIT%
  echo ::set-output name=SDL_MIXER_COMMIT::%SDL_MIXER_COMMIT%
  echo ::set-output name=SDL_TTF_COMMIT::%SDL_TTF_COMMIT%
  echo ::set-output name=SDL_RTF_COMMIT::%SDL_RTF_COMMIT%
  echo ::set-output name=SDL_NET_COMMIT::%SDL_NET_COMMIT%
)

rem
rem done!
rem

goto :eof

rem
rem call :get "https://..." [optional-filename.tar.gz] [unpack folder]
rem

:get
if "%2" equ "" (
  set ARCHIVE=%DOWNLOAD%\%~nx1
  set DNAME=%~nx1
) else (
  set ARCHIVE=%DOWNLOAD%\%2
  set DNAME=%2
)
if not exist %ARCHIVE% (
  echo Downloading %DNAME%
  curl.exe --retry 5 --retry-all-errors -sfLo %ARCHIVE% %1 || exit /b 1
)
for %%N in ("%ARCHIVE%") do set NAME=%%~nN
if exist %NAME% (
  echo Removing %NAME%
  rd /s /q %NAME%
)
echo Unpacking %DNAME%
if "%3" equ "" (
  pushd %BUILD%
) else (
  if not exist "%3" mkdir "%3"
  pushd %3
)
%SZIP% x -bb0 -y %ARCHIVE% -so | %SZIP% x -bb0 -y -ttar -si -aoa -xr^^!*\tools\benchmark\metrics -xr^^!*\tests\cli-tests -xr^^!*\lib\lib.gni 1>nul 2>nul
if exist pax_global_header del /q pax_global_header
popd
goto :eof

rem
rem call :clone output_folder "https://..."
rem

:clone
pushd %BUILD%
if exist %1 (
  echo Updating %1
  pushd %1
  call git clean --quiet -fdx
  call git fetch --quiet --no-tags origin %3:refs/remotes/origin/%3 || exit /b 1
  call git reset --quiet --hard origin/%3 || exit /b 1
  popd
) else (
  echo Cloning %1
  call git clone --quiet --branch %3 --no-tags --depth 1 %2 %1 || exit /b 1
)
popd
goto :eof
