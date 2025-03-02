@echo off
setlocal enabledelayedexpansion

rem
rem Architectures
rem

if "%PROCESSOR_ARCHITECTURE%" equ "AMD64" (
  set HOST_ARCH=x64
) else if "%PROCESSOR_ARCHITECTURE%" equ "ARM64" (
  set HOST_ARCH=arm64
)

if "%1" equ "x64" (
  set TARGET_ARCH=x64
) else if "%1" equ "arm64" (
  set TARGET_ARCH=arm64
) else if "%1" neq "" (
  echo Unknown target "%1" architecture!
  exit /b 1
) else (
  set TARGET_ARCH=%HOST_ARCH%
)

rem
rem Library Versions
rem

set NASM_VERSION=2.16.03
set YASM_VERSION=1.3.0
set NINJA_VERSION=1.12.1

set ZLIB_VERSION=1.3.1
set BZIP2_VERSION=1.0.8
set XZ_VERSION=5.6.4
set ZSTD_VERSION=1.5.7
set LIBPNG_VERSION=1.6.47
set LIBJPEGTURBO_VERSION=3.1.0
set JBIG_VERSION=2.1
set LERC_VERSION=4.0.0
set TIFF_VERSION=4.7.0
set LIBWEBP_VERSION=1.5.0
set AOM_VERSION=3.12.0
set LIBYUV_VERSION=464c51a
set DAV1D_VERSION=1.5.1
set LIBAVIF_VERSION=1.2.0
set LIBJXL_VERSION=0.11.1
set FREETYPE_VERSION=2.13.3
set HARFBUZZ_VERSION=10.4.0
set LIBOGG_VERSION=1.3.5
set LIBVORBIS_VERSION=1.3.7
set OPUS_VERSION=1.5.2
set OPUSFILE_VERSION=0.12
set FLAC_VERSION=1.5.0
set MPG123_VERSION=1.32.10
set LIBXMP_VERSION=4.6.0
set LIBGME_VERSION=0.6.3
set WAVPACK_VERSION=5.7.0
set LIBSNDFILE_VERSION=1.2.2

rem libjxl dependencies

set BROTLI_COMMIT=36533a8
set HIGHWAY_COMMIT=457c891
set SKCMS_COMMIT=42030a7

rem
rem Output Folder
rem

set OUTPUT=%~dp0SDL3-%TARGET_ARCH%
if not exist %OUTPUT% mkdir %OUTPUT%

rem
rem Temporary Folders
rem

set DOWNLOAD=%~dp0download
set SOURCE=%~dp0source
set BUILD=%~dp0build-%TARGET_ARCH%
set DEPEND=%~dp0depend-%TARGET_ARCH%

if not exist %DOWNLOAD% mkdir %DOWNLOAD% || exit /b 1
if not exist %SOURCE%   mkdir %SOURCE%   || exit /b 1
if not exist %BUILD%    mkdir %BUILD%    || exit /b 1
if not exist %DEPEND%   mkdir %DEPEND%   || exit /b 1

cd %~dp0
set PATH=%DOWNLOAD%;%PATH%

rem
rem Dependencies
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

where /q meson.exe || (
  pip.exe install meson
  where /q meson.exe || (
    echo ERROR: "meson.exe" not found
    exit /b 1
  )
)

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

if "%TARGET_ARCH%" equ "x64" (
  rem nasm is used for libjpeg-turbo and dav1d
  where /q nasm.exe || (
    echo Downloading nasm
    pushd %DOWNLOAD%
    curl.exe -sfLo nasm.zip "https://www.nasm.us/pub/nasm/releasebuilds/%NASM_VERSION%/win64/nasm-%NASM_VERSION%-win64.zip"
    %SZIP% x -bb0 -y nasm.zip nasm-%NASM_VERSION%\nasm.exe 1>nul 2>nul || exit /b 1
    move nasm-%NASM_VERSION%\nasm.exe nasm.exe 1>nul 2>nul
    rd /s /q nasm-%NASM_VERSION% 1>nul 2>nul
    popd
  )
  nasm.exe --version || exit /b 1

  rem yasm is used for mpg123
  where /q yasm.exe || (
    echo Downloading yasm
    pushd %DOWNLOAD%
    curl -sfLo yasm.exe https://www.tortall.net/projects/yasm/releases/yasm-%YASM_VERSION%-win64.exe || exit /b 1
    popd

    if "%GITHUB_WORKFLOW%" neq "" (
      rem Install VS2010 redistributable
      curl -sfLO https://download.microsoft.com/download/3/2/2/3224B87F-CFA0-4E70-BDA3-3DE650EFEBA5/vcredist_x64.exe || exit /b 1
      start /wait vcredist_x64.exe /q /norestart
      del /q vcredist_x64.exe
    )
  )
  yasm.exe --version || exit /b 1
)

where /q ninja.exe || (
  echo Downloading ninja
  pushd %DOWNLOAD%
  if "%HOST_ARCH%" equ "x64" (
    curl -Lsfo ninja-win.zip "https://github.com/ninja-build/ninja/releases/download/v%NINJA_VERSION%/ninja-win.zip" || exit /b 1
  ) else if "%HOST_ARCH%" equ "arm64" (
    curl -Lsfo ninja-win.zip "https://github.com/ninja-build/ninja/releases/download/v%NINJA_VERSION%/ninja-winarm64.zip" || exit /b 1
  )
  %SZIP% x -bb0 -y ninja-win.zip 1>nul 2>nul || exit /b 1
  popd
)
ninja.exe --version || exit /b 1

rem
rem Downloading & Unpacking
rem

call :get "https://github.com/madler/zlib/releases/download/v%ZLIB_VERSION%/zlib-%ZLIB_VERSION%.tar.xz"                                                      || exit /b 1
call :get "https://sourceware.org/pub/bzip2/bzip2-%BZIP2_VERSION%.tar.gz"                                                                                    || exit /b 1
call :get "https://github.com/tukaani-project/xz/releases/download/v%XZ_VERSION%/xz-%XZ_VERSION%.tar.xz"                                                     || exit /b 1
call :get "https://github.com/facebook/zstd/releases/download/v%ZSTD_VERSION%/zstd-%ZSTD_VERSION%.tar.gz"                                                    || exit /b 1
call :get "https://download.sourceforge.net/libpng/libpng-%LIBPNG_VERSION%.tar.xz"                                                                           || exit /b 1
call :get "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/%LIBJPEGTURBO_VERSION%/libjpeg-turbo-%LIBJPEGTURBO_VERSION%.tar.gz"              || exit /b 1
call :get "https://www.cl.cam.ac.uk/~mgk25/jbigkit/download/jbigkit-%JBIG_VERSION%.tar.gz"                                                                   || exit /b 1
call :get "https://github.com/Esri/lerc/archive/refs/tags/v%LERC_VERSION%.tar.gz" lerc-%LERC_VERSION%.tar.gz                                                 || exit /b 1
call :get "https://download.osgeo.org/libtiff/tiff-%TIFF_VERSION%.tar.gz"                                                                                    || exit /b 1
call :get "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-%LIBWEBP_VERSION%.tar.gz"                                          || exit /b 1
call :get "https://storage.googleapis.com/aom-releases/libaom-%AOM_VERSION%.tar.gz"                                                                          || exit /b 1
call :get "https://chromium.googlesource.com/libyuv/libyuv/+archive/%LIBYUV_VERSION%.tar.gz" libyuv-%LIBYUV_VERSION%.tar.gz %SOURCE%\libyuv-%LIBYUV_VERSION% || exit /b 1
call :get "https://downloads.videolan.org/pub/videolan/dav1d/%DAV1D_VERSION%/dav1d-%DAV1D_VERSION%.tar.xz"                                                   || exit /b 1
call :get "https://github.com/AOMediaCodec/libavif/archive/refs/tags/v%LIBAVIF_VERSION%.tar.gz" libavif-%LIBAVIF_VERSION%.tar.gz                             || exit /b 1
call :get "https://github.com/libjxl/libjxl/archive/refs/tags/v%LIBJXL_VERSION%.tar.gz" libjxl-%LIBJXL_VERSION%.tar.gz                                       || exit /b 1
call :get "https://download.savannah.gnu.org/releases/freetype/freetype-%FREETYPE_VERSION%.tar.xz"                                                           || exit /b 1
call :get "https://github.com/harfbuzz/harfbuzz/releases/download/%HARFBUZZ_VERSION%/harfbuzz-%HARFBUZZ_VERSION%.tar.xz"                                     || exit /b 1
call :get "https://downloads.xiph.org/releases/ogg/libogg-%LIBOGG_VERSION%.tar.xz"                                                                           || exit /b 1
call :get "https://downloads.xiph.org/releases/vorbis/libvorbis-%LIBVORBIS_VERSION%.tar.xz"                                                                  || exit /b 1
call :get "https://downloads.xiph.org/releases/opus/opus-%OPUS_VERSION%.tar.gz"                                                                              || exit /b 1
call :get "https://downloads.xiph.org/releases/opus/opusfile-%OPUSFILE_VERSION%.tar.gz"                                                                      || exit /b 1
call :get "https://github.com/xiph/flac/releases/download/%FLAC_VERSION%/flac-%FLAC_VERSION%.tar.xz"                                                         || exit /b 1
call :get "https://download.sourceforge.net/mpg123/mpg123-%MPG123_VERSION%.tar.bz2"                                                                          || exit /b 1
call :get "https://github.com/libxmp/libxmp/releases/download/libxmp-%LIBXMP_VERSION%/libxmp-%LIBXMP_VERSION%.tar.gz"                                        || exit /b 1
call :get "https://github.com/libgme/game-music-emu/archive/refs/tags/%LIBGME_VERSION%.tar.gz" libgme-%LIBGME_VERSION%.tar.gz                                || exit /b 1
call :get "https://github.com/dbry/WavPack/releases/download/%WAVPACK_VERSION%/wavpack-%WAVPACK_VERSION%.tar.xz"                                             || exit /b 1
call :get "https://github.com/libsndfile/libsndfile/releases/download/%LIBSNDFILE_VERSION%/libsndfile-%LIBSNDFILE_VERSION%.tar.xz"                           || exit /b 1

rd /s /q %SOURCE%\libjxl-%LIBJXL_VERSION%\third_party\brotli  1>nul 2>nul
rd /s /q %SOURCE%\libjxl-%LIBJXL_VERSION%\third_party\highway 1>nul 2>nul

call :get "https://github.com/google/brotli/tarball/%BROTLI_COMMIT%"           google-brotli-%BROTLI_COMMIT%.tar.gz                                           || exit /b 1
call :get "https://github.com/google/highway/tarball/%HIGHWAY_COMMIT%"         google-highway-%HIGHWAY_COMMIT%.tar.gz                                         || exit /b 1
call :get "https://skia.googlesource.com/skcms/+archive/%SKCMS_COMMIT%.tar.gz" skcms-%SKCMS_COMMIT%.tar.gz %SOURCE%\libjxl-%LIBJXL_VERSION%\third_party\skcms || exit /b 1

move %SOURCE%\google-brotli-%BROTLI_COMMIT%   %SOURCE%\libjxl-%LIBJXL_VERSION%\third_party\brotli  1>nul 2>nul
move %SOURCE%\google-highway-%HIGHWAY_COMMIT% %SOURCE%\libjxl-%LIBJXL_VERSION%\third_party\highway 1>nul 2>nul

call :clone SDL             "https://github.com/libsdl-org/SDL"             main || exit /b 1
call :clone SDL_image       "https://github.com/libsdl-org/SDL_image"       main || exit /b 1
call :clone SDL_mixer       "https://github.com/libsdl-org/SDL_mixer"       main || exit /b 1
call :clone SDL_ttf         "https://github.com/libsdl-org/SDL_ttf"         main || exit /b 1
call :clone SDL_rtf         "https://github.com/libsdl-org/SDL_rtf"         main || exit /b 1
call :clone SDL_net         "https://github.com/libsdl-org/SDL_net"         main || exit /b 1
call :clone SDL_shadercross "https://github.com/libsdl-org/SDL_shadercross" main || exit /b 1
call :clone SDL2_compat     "https://github.com/libsdl-org/sdl2-compat"     main || exit /b 1

echo Updating SDL_shadercross submodules
call git -C source\SDL_shadercross submodule update --init --recursive --quiet || exit /b 1
call git -C source\SDL_shadercross submodule foreach git reset --quiet --hard HEAD || exit /b 1

rem
rem apply patches
rem 

call git apply -p1 --directory=source/SDL_shadercross                                patches/SDL_shadercross.patch       || exit /b 1
call git apply -p1 --directory=source/SDL_shadercross/external/DirectXShaderCompiler patches/DirectXShaderCompiler.patch || exit /b 1
call git apply -p1 --directory=source/libyuv-%LIBYUV_VERSION%                        patches/libyuv.patch                || exit /b 1
call git apply -p1 --directory=source/game-music-emu-%LIBGME_VERSION%                patches/libgme.patch                || exit /b 1
call git apply -p1 --directory=source/libjpeg-turbo-%LIBJPEGTURBO_VERSION%           patches/libjpeg-turbo.patch         || exit /b 1
call git apply -p1 --directory=source/flac-%FLAC_VERSION%                            patches/flac.patch                  || exit /b 1

rem
rem MSVC Environment
rem

set OLD_PATH=%PATH%

where /q cl.exe || (
  for /f "tokens=*" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
  if "!VS!" equ "" (
    echo ERROR: Visual Studio installation not found
    exit /b 1
  )

  call "!VS!\Common7\Tools\VsDevCmd.bat" -arch=%TARGET_ARCH% -host_arch=%HOST_ARCH% -startdir=none -no_logo || exit /b 1
)

rem
rem Build Flags
rem

set CMAKE_COMMON_ARGS=-Wno-dev                ^
  -G Ninja                                    ^
  -D CMAKE_BUILD_TYPE="Release"               ^
  -D CMAKE_POLICY_DEFAULT_CMP0074=NEW         ^
  -D CMAKE_POLICY_DEFAULT_CMP0091=NEW         ^
  -D CMAKE_POLICY_DEFAULT_CMP0092=NEW         ^
  -D CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded

if "%TARGET_ARCH%" equ "arm64" (
  set CMAKE_COMMON_ARGS=%CMAKE_COMMON_ARGS% ^
    -DCMAKE_SYSTEM_NAME=Windows             ^
    -DCMAKE_SYSTEM_PROCESSOR=arm64

  where /q clang-cl.exe || (
    echo ERROR: "clang-cl.exe" not found, required to build "dav1d" and "libjxl" with neon intrinsic optimizations
    exit /b 1
  )
)

rem
rem zlib
rem

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\zlib-%ZLIB_VERSION%  ^
  -B %BUILD%\zlib-%ZLIB_VERSION%   ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND% ^
  -D BUILD_SHARED_LIBS=OFF         ^
  || exit /b 1
ninja.exe -C %BUILD%\zlib-%ZLIB_VERSION% install || exit /b 1

del %DEPEND%\lib\zlib.lib 1>nul 2>nul

rem
rem bzip2
rem

if not exist %BUILD%\bzip2-%BZIP2_VERSION% mkdir %BUILD%\bzip2-%BZIP2_VERSION% || exit /b 1
pushd %BUILD%\bzip2-%BZIP2_VERSION%

cl.exe -nologo -c -MP -MT -O2 -DNDEBUG ^
  %SOURCE%\bzip2-%BZIP2_VERSION%\blocksort.c  ^
  %SOURCE%\bzip2-%BZIP2_VERSION%\huffman.c    ^
  %SOURCE%\bzip2-%BZIP2_VERSION%\crctable.c   ^
  %SOURCE%\bzip2-%BZIP2_VERSION%\randtable.c  ^
  %SOURCE%\bzip2-%BZIP2_VERSION%\compress.c   ^
  %SOURCE%\bzip2-%BZIP2_VERSION%\decompress.c ^
  %SOURCE%\bzip2-%BZIP2_VERSION%\bzlib.c      ^
  || exit /b 1
lib.exe -nologo -out:libbz2.lib *.obj || exit /b 1

popd

copy /y %BUILD%\bzip2-%BZIP2_VERSION%\libbz2.lib  %DEPEND%\lib\
copy /y %SOURCE%\bzip2-%BZIP2_VERSION%\bzlib.h    %DEPEND%\include\

rem
rem xz
rem

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\xz-%XZ_VERSION%      ^
  -B %BUILD%\xz-%XZ_VERSION%       ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND% ^
  -D BUILD_SHARED_LIBS=OFF         ^
  || exit /b 1
ninja.exe -C %BUILD%\xz-%XZ_VERSION% install || exit /b 1

rem
rem zstd
rem

cmake.exe %CMAKE_COMMON_ARGS%                 ^
  -S %SOURCE%\zstd-%ZSTD_VERSION%\build\cmake ^
  -B %BUILD%\zstd-%ZSTD_VERSION%              ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -D BUILD_SHARED_LIBS=OFF                    ^
  -D ZSTD_BUILD_STATIC=ON                     ^
  -D ZSTD_BUILD_SHARED=OFF                    ^
  -D ZSTD_BUILD_PROGRAMS=OFF                  ^
  -D ZSTD_BUILD_CONTRIB=OFF                   ^
  -D ZSTD_BUILD_TESTS=OFF                     ^
  -D ZSTD_LEGACY_SUPPORT=ON                   ^
  -D ZSTD_MULTITHREAD_SUPPORT=ON              ^
  -D ZSTD_USE_STATIC_RUNTIME=ON               ^
  || exit /b 1
ninja.exe -C %BUILD%\zstd-%ZSTD_VERSION% install || exit /b 1

rem
rem libpng
rem dependencies: zlib
rem

cmake.exe %CMAKE_COMMON_ARGS%         ^
  -S %SOURCE%\libpng-%LIBPNG_VERSION% ^
  -B %BUILD%\libpng-%LIBPNG_VERSION%  ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%    ^
  -D PNG_STATIC=ON                    ^
  -D PNG_SHARED=OFF                   ^
  -D PNG_TESTS=OFF                    ^
  -D PNG_TOOLS=OFF                    ^
  -D PNG_DEBUG=OFF                    ^
  -D PNG_HARDWARE_OPTIMIZATIONS=ON    ^
  || exit /b 1
ninja.exe -C %BUILD%\libpng-%LIBPNG_VERSION% install || exit /b 1

rem
rem libjpeg-turbo
rem

if "%TARGET_ARCH%" equ "arm64" (
  set LIBJPEG_TURBO_CMAKE_EXTRA=^
    -D CPU_TYPE=arm64           ^
    -D NEON_INTRINSICS=ON
)

cmake.exe %CMAKE_COMMON_ARGS%                      ^
  -S %SOURCE%\libjpeg-turbo-%LIBJPEGTURBO_VERSION% ^
  -B %BUILD%\libjpeg-turbo-%LIBJPEGTURBO_VERSION%  ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%                 ^
  -D ENABLE_SHARED=OFF                             ^
  -D ENABLE_STATIC=ON                              ^
  -D REQUIRE_SIMD=ON                               ^
  -D WITH_SIMD=ON                                  ^
  -D WITH_ARITH_DEC=ON                             ^
  -D WITH_ARITH_ENC=ON                             ^
  -D WITH_JPEG7=ON                                 ^
  -D WITH_JPEG8=ON                                 ^
  -D WITH_TURBOJPEG=OFF                            ^
  -D WITH_JAVA=OFF                                 ^
  %LIBJPEG_TURBO_CMAKE_EXTRA%                      ^
  || exit /b 1
ninja.exe -C %BUILD%\libjpeg-turbo-%LIBJPEGTURBO_VERSION% install || exit /b 1

rem
rem libwebp
rem

cmake.exe %CMAKE_COMMON_ARGS%           ^
  -S %SOURCE%\libwebp-%LIBWEBP_VERSION% ^
  -B %BUILD%\libwebp-%LIBWEBP_VERSION%  ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%      ^
  -D BUILD_SHARED_LIBS=OFF              ^
  -D WEBP_ENABLE_SIMD=ON                ^
  -D WEBP_BUILD_ANIM_UTILS=OFF          ^
  -D WEBP_BUILD_CWEBP=OFF               ^
  -D WEBP_BUILD_DWEBP=OFF               ^
  -D WEBP_BUILD_GIF2WEBP=OFF            ^
  -D WEBP_BUILD_IMG2WEBP=OFF            ^
  -D WEBP_BUILD_VWEBP=OFF               ^
  -D WEBP_BUILD_WEBPINFO=OFF            ^
  -D WEBP_BUILD_LIBWEBPMUX=OFF          ^
  -D WEBP_BUILD_WEBPMUX=OFF             ^
  -D WEBP_BUILD_EXTRAS=OFF              ^
  -D WEBP_BUILD_WEBP_JS=OFF             ^
  -D WEBP_USE_THREAD=ON                 ^
  -D WEBP_NEAR_LOSSLESS=ON              ^
  || exit /b 1
ninja.exe -C %BUILD%\libwebp-%LIBWEBP_VERSION% install || exit /b 1

rem
rem jbig
rem

if not exist %BUILD%\jbigkit-%JBIG_VERSION% mkdir %BUILD%\jbigkit-%JBIG_VERSION% || exit /b 1
pushd %BUILD%\jbigkit-%JBIG_VERSION%

cl.exe -nologo -c -MP -MT -O2                       ^
  %SOURCE%\jbigkit-%JBIG_VERSION%\libjbig\jbig.c    ^
  %SOURCE%\jbigkit-%JBIG_VERSION%\libjbig\jbig_ar.c ^
  || exit /b 1
lib.exe -nologo -out:jbig.lib *.obj || exit /b 1

popd

copy /y %BUILD%\jbigkit-%JBIG_VERSION%\jbig.lib           %DEPEND%\lib\
copy /y %SOURCE%\jbigkit-%JBIG_VERSION%\libjbig\jbig.h    %DEPEND%\include\
copy /y %SOURCE%\jbigkit-%JBIG_VERSION%\libjbig\jbig_ar.h %DEPEND%\include\

rem
rem lerc
rem

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\lerc-%LERC_VERSION%  ^
  -B %BUILD%\lerc-%LERC_VERSION%   ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND% ^
  -D BUILD_SHARED_LIBS=OFF         ^
  || exit /b 1
ninja.exe -C %BUILD%\lerc-%LERC_VERSION% install || exit /b 1

rem
rem tiff
rem dependencies: libjpeg-turbo, libwebp, jbig, lerc, zstd, xz, zlib
rem

cmake.exe %CMAKE_COMMON_ARGS%              ^
  -S %SOURCE%\tiff-%TIFF_VERSION%          ^
  -B %BUILD%\tiff-%TIFF_VERSION%           ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%         ^
  -D CMAKE_C_FLAGS=-DLZMA_API_STATIC       ^
  -D BUILD_SHARED_LIBS=OFF                 ^
  -D WebP_LIBRARY=%DEPEND%\lib\libwebp.lib ^
  -D tiff-tools=OFF                        ^
  -D tiff-tools-unsupported=OFF            ^
  -D tiff-tests=OFF                        ^
  -D tiff-contrib=OFF                      ^
  -D tiff-docs=OFF                         ^
  -D tiff-deprecated=OFF                   ^
  -D ccitt=ON                              ^
  -D packbits=ON                           ^
  -D lzw=ON                                ^
  -D thunder=ON                            ^
  -D next=ON                               ^
  -D mdi=ON                                ^
  -D zlib=ON                               ^
  -D pixarlog=ON                           ^
  -D jpeg=ON                               ^
  -D jbig=ON                               ^
  -D lerc=ON                               ^
  -D lzma=ON                               ^
  -D zstd=ON                               ^
  -D webp=ON                               ^
  || exit /b 1
ninja.exe -C %BUILD%\tiff-%TIFF_VERSION% install || exit /b 1

call git apply -p1 --directory=depend-%TARGET_ARCH% patches/tiff.patch || ^
call git apply -p1 --directory=depend-%TARGET_ARCH% patches/tiff2.patch || exit /b 1

rem
rem aom
rem

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\libaom-%AOM_VERSION% ^
  -B %BUILD%\libaom-%AOM_VERSION%  ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND% ^
  -D BUILD_SHARED_LIBS=OFF         ^
  -D ENABLE_EXAMPLES=OFF           ^
  -D ENABLE_TESTDATA=OFF           ^
  -D ENABLE_TESTS=OFF              ^
  -D ENABLE_TOOLS=OFF              ^
  -D ENABLE_DOCS=OFF               ^
  || exit /b 1
ninja.exe -C %BUILD%\libaom-%AOM_VERSION% install || exit /b 1

rem
rem libyuv
rem

cmake.exe %CMAKE_COMMON_ARGS%         ^
  -S %SOURCE%\libyuv-%LIBYUV_VERSION% ^
  -B %BUILD%\libyuv-%LIBYUV_VERSION%  ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%    ^
  -D TEST=OFF                         ^
  || exit /b 1
ninja.exe -C %BUILD%\libyuv-%LIBYUV_VERSION% yuv || exit /b 1

copy  /Y    %BUILD%\libyuv-%LIBYUV_VERSION%\yuv.lib  %DEPEND%\lib\
xcopy /Y /E %SOURCE%\libyuv-%LIBYUV_VERSION%\include %DEPEND%\include\

rem
rem dav1d
rem

meson.exe setup --reconfigure                 ^
  --prefix=%DEPEND%                           ^
  --default-library=static                    ^
  --buildtype=release                         ^
  --cross-file "%~dp0meson-%TARGET_ARCH%.txt" ^
  -Db_ndebug=true                             ^
  -Db_vscrt=mt                                ^
  -Denable_asm=true                           ^
  -Denable_tools=false                        ^
  -Denable_examples=false                     ^
  -Denable_tests=false                        ^
  -Denable_docs=false                         ^
  -Dlogging=false                             ^
  %DAV1D_MESON_EXTRA%                         ^
  %BUILD%\dav1d-%DAV1D_VERSION%               ^
  %SOURCE%\dav1d-%DAV1D_VERSION%              ^
  || exit /b 1
ninja.exe -C %BUILD%\dav1d-%DAV1D_VERSION% install || exit /b 1

rem
rem libavif
rem dependencies: dav1d, aom, libyuv, libsharpyuv (part of libwebp)
rem

cmake.exe %CMAKE_COMMON_ARGS%                         ^
  -S %SOURCE%\libavif-%LIBAVIF_VERSION%               ^
  -B %BUILD%\libavif-%LIBAVIF_VERSION%                ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%                    ^
  -D BUILD_SHARED_LIBS=OFF                            ^
  -D AVIF_ENABLE_WERROR=OFF                           ^
  -D AVIF_CODEC_AOM=SYSTEM                            ^
  -D AVIF_CODEC_AOM_ENCODE=ON                         ^
  -D AVIF_CODEC_AOM_DECODE=OFF                        ^
  -D AVIF_CODEC_DAV1D=SYSTEM                          ^
  -D AVIF_LIBSHARPYUV=SYSTEM                          ^
  -D DAV1D_LIBRARIES=%DEPEND%\lib                     ^
  -D DAV1D_LIBRARY=%DEPEND%\lib\libdav1d.a            ^
  -D LIBSHARPYUV_INCLUDE_DIR=%DEPEND%\include\webp    ^
  -D LIBSHARPYUV_LIBRARY=%DEPEND%\lib\libsharpyuv.lib ^
  -D VCPKG_TARGET_TRIPLET=1                           ^
  || exit /b 1
ninja.exe -C %BUILD%\libavif-%LIBAVIF_VERSION% install || exit /b 1

rem
rem libjxl
rem

set LIBJXL_EXTRA_CFLAGS=-w -DJXL_STATIC_DEFINE

if "%TARGET_ARCH%" equ "arm64" (
  set LIBJXL_CMAKE_EXTRA=-DCMAKE_C_COMPILER=clang-cl.exe -DCMAKE_CXX_COMPILER=clang-cl.exe
  set LIBJXL_EXTRA_CFLAGS=%LIBJXL_EXTRA_CFLAGS% --target=aarch64-win32-msvc
)

cmake.exe %CMAKE_COMMON_ARGS%                                                                   ^
  -S %SOURCE%\libjxl-%LIBJXL_VERSION%                                                           ^
  -B %BUILD%\libjxl-%LIBJXL_VERSION%                                                            ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%                                                              ^
  -D CMAKE_C_FLAGS="%LIBJXL_EXTRA_CFLAGS%"                                                      ^
  -D CMAKE_CXX_FLAGS="%LIBJXL_EXTRA_CFLAGS% -EHsc \"-D_STL_EXTRA_DISABLED_WARNINGS=4244 4267\"" ^
  -D BUILD_SHARED_LIBS=OFF                                                                      ^
  -D BUILD_TESTING=OFF                                                                          ^
  -D JPEGXL_STATIC=ON                                                                           ^
  -D JPEGXL_WARNINGS_AS_ERRORS=OFF                                                              ^
  -D JPEGXL_ENABLE_FUZZERS=OFF                                                                  ^
  -D JPEGXL_ENABLE_DEVTOOLS=OFF                                                                 ^
  -D JPEGXL_ENABLE_TOOLS=OFF                                                                    ^
  -D JPEGXL_ENABLE_JPEGLI=OFF                                                                   ^
  -D JPEGXL_ENABLE_DOXYGEN=OFF                                                                  ^
  -D JPEGXL_ENABLE_MANPAGES=OFF                                                                 ^
  -D JPEGXL_ENABLE_BENCHMARK=OFF                                                                ^
  -D JPEGXL_ENABLE_EXAMPLES=OFF                                                                 ^
  -D JPEGXL_BUNDLE_LIBPNG=OFF                                                                   ^
  -D JPEGXL_ENABLE_JNI=OFF                                                                      ^
  -D JPEGXL_ENABLE_SJPEG=OFF                                                                    ^
  -D JPEGXL_ENABLE_OPENEXR=OFF                                                                  ^
  -D JPEGXL_ENABLE_SKCMS=ON                                                                     ^
  -D JPEGXL_ENABLE_VIEWERS=OFF                                                                  ^
  -D JPEGXL_ENABLE_TCMALLOC=OFF                                                                 ^
  -D JPEGXL_ENABLE_PLUGINS=OFF                                                                  ^
  -D JPEGXL_ENABLE_COVERAGE=OFF                                                                 ^
  -D JPEGXL_ENABLE_TRANSCODE_JPEG=OFF                                                           ^
  -D JPEGXL_ENABLE_AVX512=ON                                                                    ^
  -D JPEGXL_ENABLE_AVX512_ZEN4=ON                                                               ^
  %LIBJXL_CMAKE_EXTRA%                                                                          ^
  || exit /b 1
ninja.exe -C %BUILD%\libjxl-%LIBJXL_VERSION% install || exit /b 1

rem
rem harfbuzz (dummy build, just to have dependency for freetype)
rem

cmake.exe %CMAKE_COMMON_ARGS%             ^
  -S %SOURCE%\harfbuzz-%HARFBUZZ_VERSION% ^
  -B %BUILD%\harfbuzz-%HARFBUZZ_VERSION%  ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%        ^
  -D BUILD_SHARED_LIBS=OFF                ^
  -D HB_BUILD_SUBSET=OFF                  ^
  -D HB_HAVE_FREETYPE=OFF                 ^
  || exit /b 1
ninja.exe -C %BUILD%\harfbuzz-%HARFBUZZ_VERSION% install || exit /b 1

rem
rem freetype
rem dependencies: zlib, bzip2, libpng, harfbuzz, brotli (part of libjxl)
rem

cmake.exe %CMAKE_COMMON_ARGS%             ^
  -S %SOURCE%\freetype-%FREETYPE_VERSION% ^
  -B %BUILD%\freetype-%FREETYPE_VERSION%  ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%        ^
  -D BUILD_SHARED_LIBS=OFF                ^
  -D FT_REQUIRE_ZLIB=ON                   ^
  -D FT_REQUIRE_BZIP2=ON                  ^
  -D FT_REQUIRE_BROTLI=ON                 ^
  -D FT_REQUIRE_PNG=ON                    ^
  -D FT_REQUIRE_HARFBUZZ=ON               ^
  || exit /b 1
ninja.exe -C %BUILD%\freetype-%FREETYPE_VERSION% install || exit /b 1

rem
rem harfbuzz
rem dependencies: freetype
rem

cmake.exe %CMAKE_COMMON_ARGS%             ^
  -S %SOURCE%\harfbuzz-%HARFBUZZ_VERSION% ^
  -B %BUILD%\harfbuzz-%HARFBUZZ_VERSION%  ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%        ^
  -D BUILD_SHARED_LIBS=OFF                ^
  -D HB_BUILD_SUBSET=OFF                  ^
  -D HB_HAVE_FREETYPE=ON                  ^
  || exit /b 1
ninja.exe -C %BUILD%\harfbuzz-%HARFBUZZ_VERSION% install || exit /b 1

rem
rem libogg
rem

cmake.exe %CMAKE_COMMON_ARGS%         ^
  -S %SOURCE%\libogg-%LIBOGG_VERSION% ^
  -B %BUILD%\libogg-%LIBOGG_VERSION%  ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%    ^
  -D BUILD_SHARED_LIBS=OFF            ^
  -D BUILD_TESTING=OFF                ^
  -D INSTALL_DOCS=OFF                 ^
  || exit /b 1
ninja.exe -C %BUILD%\libogg-%LIBOGG_VERSION% install || exit /b 1

rem
rem libvorbis
rem dependencies: libogg
rem

cmake.exe %CMAKE_COMMON_ARGS%               ^
  -S %SOURCE%\libvorbis-%LIBVORBIS_VERSION% ^
  -B %BUILD%\libvorbis-%LIBVORBIS_VERSION%  ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%          ^
  -D BUILD_SHARED_LIBS=OFF                  ^
  || exit /b 1
ninja.exe -C %BUILD%\libvorbis-%LIBVORBIS_VERSION% install || exit /b 1

rem
rem opus
rem dependencies: libogg
rem

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\opus-%OPUS_VERSION%  ^
  -B %BUILD%\opus-%OPUS_VERSION%   ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND% ^
  -D BUILD_SHARED_LIBS=OFF         ^
  -D OPUS_BUILD_SHARED_LIBRARY=OFF ^
  -D OPUS_BUILD_TESTING=OFF        ^
  -D OPUS_BUILD_PROGRAMS=OFF       ^
  -D OPUS_ASSERTIONS=OFF           ^
  -D OPUS_HARDENING=OFF            ^
  -D OPUS_FUZZING=OFF              ^
  -D OPUS_CHECK_ASM=OFF            ^
  -D OPUS_DRED=OFF                 ^
  -D OPUS_OSCE=OFF                 ^
  -D OPUS_STATIC_RUNTIME=ON        ^
  -D OPUS_FAST_MATH=OFF            ^
  -D OPUS_STACK_PROTECTOR=OFF      ^
  -D OPUS_FORTIFY_SOURCE=OFF       ^
  || exit /b 1
ninja.exe -C %BUILD%\opus-%OPUS_VERSION% install || exit /b 1

rem
rem opusfile
rem dependencies: opus
rem

if not exist %BUILD%\opusfile-%OPUSFILE_VERSION% mkdir %BUILD%\opusfile-%OPUSFILE_VERSION% || exit /b 1
pushd %BUILD%\opusfile-%OPUSFILE_VERSION%

cl.exe -nologo -c -MP -MT -O2 -DNDEBUG                ^
  -I%SOURCE%\opusfile-%OPUSFILE_VERSION%\include      ^
  -I%DEPEND%\include -I%DEPEND%\include\opus          ^
  %SOURCE%\opusfile-%OPUSFILE_VERSION%\src\info.c     ^
  %SOURCE%\opusfile-%OPUSFILE_VERSION%\src\internal.c ^
  %SOURCE%\opusfile-%OPUSFILE_VERSION%\src\opusfile.c ^
  %SOURCE%\opusfile-%OPUSFILE_VERSION%\src\stream.c   ^
  || exit /b 1
lib.exe -nologo -out:opusfile.lib *.obj || exit /b 1

popd

copy /y %BUILD%\opusfile-%OPUSFILE_VERSION%\opusfile.lib        %DEPEND%\lib\
copy /y %SOURCE%\opusfile-%OPUSFILE_VERSION%\include\opusfile.h %DEPEND%\include\opus\

rem
rem flac
rem dependencies: libogg
rem

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\flac-%FLAC_VERSION%  ^
  -B %BUILD%\flac-%FLAC_VERSION%   ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND% ^
  -D BUILD_SHARED_LIBS=OFF         ^
  -D BUILD_CXXLIBS=OFF             ^
  -D BUILD_PROGRAMS=OFF            ^
  -D BUILD_EXAMPLES=OFF            ^
  -D BUILD_TESTING=OFF             ^
  -D BUILD_DOCS=OFF                ^
  -D INSTALL_MANPAGES=OFF          ^
  -D WITH_FORTIFY_SOURCE=OFF       ^
  -D WITH_STACK_PROTECTOR=OFF      ^
  -D WITH_OGG=ON                   ^
  -D WITH_AVX=ON                   ^
  || exit /b 1
ninja.exe -C %BUILD%\flac-%FLAC_VERSION% install || exit /b 1

rem
rem mpg123
rem

cmake.exe %CMAKE_COMMON_ARGS%                      ^
  -S %SOURCE%\mpg123-%MPG123_VERSION%\ports\cmake  ^
  -B %BUILD%\mpg123-%MPG123_VERSION%               ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%                 ^
  -D BUILD_SHARED_LIBS=OFF                         ^
  -D BUILD_LIBOUT123=OFF                           ^
  || exit /b 1
ninja.exe -C %BUILD%\mpg123-%MPG123_VERSION% install || exit /b 1

rem
rem libxmp
rem

cmake.exe %CMAKE_COMMON_ARGS%         ^
  -S %SOURCE%\libxmp-%LIBXMP_VERSION% ^
  -B %BUILD%\libxmp-%LIBXMP_VERSION%  ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%    ^
  -D BUILD_STATIC=ON                  ^
  -D BUILD_SHARED=OFF                 ^
  -D LIBXMP_DOCS=OFF                  ^
  -D WITH_UNIT_TESTS=OFF              ^
  || exit /b 1
ninja.exe -C %BUILD%\libxmp-%LIBXMP_VERSION% install || exit /b 1

rem
rem libgme
rem dependencies: zlib
rem

cmake.exe %CMAKE_COMMON_ARGS%                 ^
  -S %SOURCE%\game-music-emu-%LIBGME_VERSION% ^
  -B %BUILD%\game-music-emu-%LIBGME_VERSION%  ^
  -D CMAKE_IGNORE_PREFIX_PATH=%~dp0           ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -D CMAKE_CXX_FLAGS=-DBLARGG_EXPORT=         ^
  -D BUILD_SHARED_LIBS=OFF                    ^
  -D ENABLE_UBSAN=OFF                         ^
  -D ZLIB_LIBRARY=%DEPEND%\lib\zlibstatic.lib ^
  || exit /b 1
ninja.exe -C %BUILD%\game-music-emu-%LIBGME_VERSION% install || exit /b 1

rem
rem wavpack
rem

if "%TARGET_ARCH%" equ "x64" (
  set WAVPACK_EXTRA_CMAKE=-D CMAKE_ASM_COMPILER=ml64.exe -D WAVPACK_ENABLE_ASM=ON
) else (
  set WAVPACK_EXTRA_CMAKE=-D WAVPACK_ENABLE_ASM=OFF
)

cmake.exe %CMAKE_COMMON_ARGS%           ^
  -S %SOURCE%\wavpack-%WAVPACK_VERSION% ^
  -B %BUILD%\wavpack-%WAVPACK_VERSION%  ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%      ^
  %WAVPACK_EXTRA_CMAKE%                 ^
  -D BUILD_SHARED_LIBS=OFF              ^
  -D BUILD_TESTING=OFF                  ^
  -D WAVPACK_INSTALL_DOCS=OFF           ^
  -D WAVPACK_BUILD_PROGRAMS=OFF         ^
  -D WAVPACK_BUILD_COOLEDIT_PLUGIN=OFF  ^
  -D WAVPACK_BUILD_WINAMP_PLUGIN=OFF    ^
  || exit /b 1
ninja.exe -C %BUILD%\wavpack-%WAVPACK_VERSION% install || exit /b 1

rem
rem libsndfile
rem

cmake.exe %CMAKE_COMMON_ARGS%                 ^
  -S %SOURCE%\libsndfile-%LIBSNDFILE_VERSION% ^
  -B %BUILD%\libsndfile-%LIBSNDFILE_VERSION%  ^
  -D CMAKE_INSTALL_PREFIX=%DEPEND%            ^
  -D BUILD_SHARED_LIBS=OFF                    ^
  -D BUILD_PROGRAMS=OFF                       ^
  -D BUILD_EXAMPLES=OFF                       ^
  -D BUILD_TESTING=OFF                        ^
  -D ENABLE_EXTERNAL_LIBS=OFF                 ^
  -D ENABLE_MPEG=OFF                          ^
  || exit /b 1
ninja.exe -C %BUILD%\libsndfile-%LIBSNDFILE_VERSION% install || exit /b 1

rem
rem SDL
rem

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\SDL                  ^
  -B %BUILD%\SDL                   ^
  -D CMAKE_INSTALL_PREFIX=%OUTPUT% ^
  -D BUILD_SHARED_LIBS=ON          ^
  || exit /b 1
ninja.exe -C %BUILD%\SDL install || exit /b 1

rem
rem SDL_image
rem dependencies: avif, libjxl, tiff, libjpeg-turbo, libpng, libwebp
rem

set SDL3_IMAGE_LINK_FLAGS=-LIBPATH:%DEPEND%\lib brotlicommon.lib brotlidec.lib hwy.lib libsharpyuv.lib yuv.lib libdav1d.a aom.lib

cmake.exe %CMAKE_COMMON_ARGS%                            ^
  -S %SOURCE%\SDL_image                                  ^
  -B %BUILD%\SDL_image                                   ^
  -D CMAKE_INSTALL_PREFIX=%OUTPUT%                       ^
  -D CMAKE_PREFIX_PATH=%DEPEND%                          ^
  -D CMAKE_C_FLAGS=-DJXL_STATIC_DEFINE                   ^
  -D CMAKE_SHARED_LINKER_FLAGS="%SDL3_IMAGE_LINK_FLAGS%" ^
  -D BUILD_SHARED_LIBS=ON                                ^
  -D SDL3_ROOT=%OUTPUT%                                  ^
  -D SDLIMAGE_DEPS_SHARED=OFF                            ^
  -D SDLIMAGE_VENDORED=OFF                               ^
  -D SDLIMAGE_WERROR=OFF                                 ^
  -D SDLIMAGE_STRICT=ON                                  ^
  -D SDLIMAGE_SAMPLES=OFF                                ^
  -D SDLIMAGE_TESTS=OFF                                  ^
  -D SDLIMAGE_BACKEND_STB=OFF                            ^
  -D SDLIMAGE_BACKEND_WIC=OFF                            ^
  -D SDLIMAGE_BACKEND_IMAGEIO=OFF                        ^
  -D SDLIMAGE_AVIF=ON                                    ^
  -D SDLIMAGE_BMP=ON                                     ^
  -D SDLIMAGE_GIF=ON                                     ^
  -D SDLIMAGE_JPG=ON                                     ^
  -D SDLIMAGE_JXL=ON                                     ^
  -D SDLIMAGE_LBM=ON                                     ^
  -D SDLIMAGE_PCX=ON                                     ^
  -D SDLIMAGE_PNG=ON                                     ^
  -D SDLIMAGE_PNM=ON                                     ^
  -D SDLIMAGE_QOI=ON                                     ^
  -D SDLIMAGE_SVG=ON                                     ^
  -D SDLIMAGE_TGA=ON                                     ^
  -D SDLIMAGE_TIF=ON                                     ^
  -D SDLIMAGE_WEBP=ON                                    ^
  -D SDLIMAGE_XCF=ON                                     ^
  -D SDLIMAGE_XPM=ON                                     ^
  -D SDLIMAGE_XV=ON                                      ^
  -D SDLIMAGE_AVIF_SAVE=ON                               ^
  -D SDLIMAGE_JPG_SAVE=ON                                ^
  -D SDLIMAGE_PNG_SAVE=ON                                ^
  || exit /b 1
ninja.exe -C %BUILD%\SDL_image install || exit /b 1

rem
rem SDL_mixer
rem dependencies: libgme, libxmp, mpg123, flac, opusfile, vorbis, wavpack
rem

set SDL3_MIXER_LINK_FLAGS=-LIBPATH:%DEPEND%\lib zlibstatic.lib opus.lib

cmake.exe %CMAKE_COMMON_ARGS%                            ^
  -S %SOURCE%\SDL_mixer                                  ^
  -B %BUILD%\SDL_mixer                                   ^
  -D CMAKE_INSTALL_PREFIX=%OUTPUT%                       ^
  -D CMAKE_PREFIX_PATH=%DEPEND%                          ^
  -D CMAKE_SHARED_LINKER_FLAGS="%SDL3_MIXER_LINK_FLAGS%" ^
  -D BUILD_SHARED_LIBS=ON                                ^
  -D SDL3_ROOT=%OUTPUT%                                  ^
  -D SDLMIXER_DEPS_SHARED=OFF                            ^
  -D SDLMIXER_VENDORED=OFF                               ^
  -D SDLMIXER_WERROR=OFF                                 ^
  -D SDLMIXER_SAMPLES=OFF                                ^
  -D SDLMIXER_CMD=OFF                                    ^
  -D SDLMIXER_SNDFILE=ON                                 ^
  -D SDLMIXER_SNDFILE_SHARED=OFF                         ^
  -D SDLMIXER_FLAC=ON                                    ^
  -D SDLMIXER_FLAC_LIBFLAC=ON                            ^
  -D SDLMIXER_FLAC_LIBFLAC_SHARED=OFF                    ^
  -D SDLMIXER_FLAC_DRFLAC=OFF                            ^
  -D SDLMIXER_GME=ON                                     ^
  -D SDLMIXER_GME_SHARED=OFF                             ^
  -D SDLMIXER_MOD=ON                                     ^
  -D SDLMIXER_MOD_MODPLUG=OFF                            ^
  -D SDLMIXER_MOD_MODPLUG_SHARED=OFF                     ^
  -D SDLMIXER_MOD_XMP=ON                                 ^
  -D SDLMIXER_MOD_XMP_LITE=OFF                           ^
  -D SDLMIXER_MOD_XMP_SHARED=OFF                         ^
  -D SDLMIXER_MP3=ON                                     ^
  -D SDLMIXER_MP3_MINIMP3=OFF                            ^
  -D SDLMIXER_MP3_MPG123=ON                              ^
  -D SDLMIXER_MP3_MPG123_SHARED=OFF                      ^
  -D SDLMIXER_MIDI=ON                                    ^
  -D SDLMIXER_MIDI_FLUIDSYNTH=OFF                        ^
  -D SDLMIXER_MIDI_FLUIDSYNTH_SHARED=OFF                 ^
  -D SDLMIXER_MIDI_NATIVE=ON                             ^
  -D SDLMIXER_MIDI_TIMIDITY=OFF                          ^
  -D SDLMIXER_OPUS=ON                                    ^
  -D SDLMIXER_OPUS_SHARED=OFF                            ^
  -D SDLMIXER_VORBIS="VORBISFILE"                        ^
  -D SDLMIXER_VORBIS_TREMOR_SHARED=OFF                   ^
  -D SDLMIXER_VORBIS_VORBISFILE_SHARED=OFF               ^
  -D SDLMIXER_WAVE=ON                                    ^
  -D SDLMIXER_WAVPACK=ON                                 ^
  -D SDLMIXER_WAVPACK_DSD=ON                             ^
  -D SDLMIXER_WAVPACK_SHARED=OFF                         ^
  || exit /b 1
ninja.exe -C %BUILD%\SDL_mixer install || exit /b 1

rem
rem SDL_ttf
rem dependencies: freetype, harfbuzz
rem

set SDL3_TTF_LINK_FLAGS=-LIBPATH:%DEPEND%\lib brotlicommon.lib brotlidec.lib libbz2.lib zlibstatic.lib libpng16_static.lib

cmake.exe %CMAKE_COMMON_ARGS%                          ^
  -S %SOURCE%\SDL_ttf                                  ^
  -B %BUILD%\SDL_ttf                                   ^
  -D CMAKE_INSTALL_PREFIX=%OUTPUT%                     ^
  -D CMAKE_PREFIX_PATH=%DEPEND%                        ^
  -D CMAKE_SHARED_LINKER_FLAGS="%SDL3_TTF_LINK_FLAGS%" ^
  -D BUILD_SHARED_LIBS=ON                              ^
  -D SDL3_ROOT=%OUTPUT%                                ^
  -D SDLTTF_VENDORED=OFF                               ^
  -D SDLTTF_WERROR=OFF                                 ^
  -D SDLTTF_SAMPLES=OFF                                ^
  -D SDLTTF_FREETYPE=ON                                ^
  -D SDLTTF_HARFBUZZ=ON                                ^
  || exit /b 1
ninja.exe -C %BUILD%\SDL_ttf install || exit /b 1

rem
rem SDL_rtf
rem

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\SDL_rtf              ^
  -B %BUILD%\SDL_rtf               ^
  -D CMAKE_INSTALL_PREFIX=%OUTPUT% ^
  -D CMAKE_PREFIX_PATH=%DEPEND%    ^
  -D BUILD_SHARED_LIBS=ON          ^
  -D SDL3_ROOT=%OUTPUT%            ^
  -D SDLRTF_WERROR=OFF             ^
  -D SDLRTF_SAMPLES=OFF            ^
  || exit /b 1
ninja.exe -C %BUILD%\SDL_rtf install || exit /b 1

rem
rem SDL_net
rem

set CL=-DSDL_ENABLE_OLD_NAMES

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\SDL_net              ^
  -B %BUILD%\SDL_net               ^
  -D CMAKE_INSTALL_PREFIX=%OUTPUT% ^
  -D CMAKE_PREFIX_PATH=%DEPEND%    ^
  -D BUILD_SHARED_LIBS=ON          ^
  -D SDL3_ROOT=%OUTPUT%            ^
  -D SDLNET_WERROR=OFF             ^
  -D SDLNET_SAMPLES=OFF            ^
  || exit /b 1
ninja.exe -C %BUILD%\SDL_net install || exit /b 1

set CL=

rem
rem SDL_shadercross
rem

if "%HOST_ARCH%" neq "%TARGET_ARCH%" (
  set PATH=!OLD_PATH!
  call "!VS!\Common7\Tools\VsDevCmd.bat" -arch=!HOST_ARCH! -host_arch=!HOST_ARCH! -startdir=none -no_logo || exit /b 1

  cmake.exe                                                          ^
    -G Ninja                                                         ^
    -S %SOURCE%\SDL_shadercross\external\DirectXShaderCompiler       ^
    -B %BUILD%\SDL_shadercross\external\DirectXShaderCompiler-native ^
    -D CMAKE_BUILD_TYPE=Release                                      ^
    -D BUILD_SHARED_LIBS=OFF                                         ^
    -D LLVM_TARGETS_TO_BUILD=None                                    ^
    -D LLVM_ENABLE_WARNINGS=OFF                                      ^
    -D LLVM_ENABLE_EH=ON                                             ^
    -D LLVM_ENABLE_RTTI=ON                                           ^
    || exit /b 1
  ninja.exe -C %BUILD%\SDL_shadercross\external\DirectXShaderCompiler-native llvm-tblgen clang-tblgen || exit /b 1

  set PATH=!OLD_PATH!
  call "!VS!\Common7\Tools\VsDevCmd.bat" -arch=!TARGET_ARCH! -host_arch=!HOST_ARCH! -startdir=none -no_logo || exit /b 1
  set PATH=%BUILD%\SDL_shadercross\external\DirectXShaderCompiler-native\bin;!PATH!
)

cmake.exe %CMAKE_COMMON_ARGS%             ^
  -S %SOURCE%\SDL_shadercross             ^
  -B %BUILD%\SDL_shadercross              ^
  -D CMAKE_INSTALL_PREFIX=%OUTPUT%        ^
  -D CMAKE_PREFIX_PATH=%DEPEND%           ^
  -D SDL3_ROOT=%OUTPUT%                   ^
  -D SDLSHADERCROSS_CLI=ON                ^
  -D SDLSHADERCROSS_VENDORED=ON           ^
  -D SDLSHADERCROSS_SHARED=ON             ^
  -D SDLSHADERCROSS_STATIC=OFF            ^
  -D SDLSHADERCROSS_SPIRVCROSS_SHARED=OFF ^
  -D SDLSHADERCROSS_INSTALL=ON            ^
  -D SDLSHADERCROSS_INSTALL_CPACK=OFF     ^
  || exit /b 1
ninja.exe -C %BUILD%\SDL_shadercross install || exit /b 1

rem
rem SDL2_compat
rem

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\SDL2_compat          ^
  -B %BUILD%\SDL2_compat           ^
  -D CMAKE_INSTALL_PREFIX=%OUTPUT% ^
  -D CMAKE_PREFIX_PATH=%DEPEND%    ^
  -D BUILD_SHARED_LIBS=ON          ^
  -D SDL3_ROOT=%OUTPUT%            ^
  -D SDL2COMPAT_TESTS=OFF          ^
  -D SDL2COMPAT_STATIC=OFF         ^
  || exit /b 1
ninja.exe -C %BUILD%\SDL2_compat install || exit /b 1

pushd %BUILD%\SDL2_compat
del SDL2main.lib
cl.exe -c -MT -O2 -Zl -DDLL_EXPORT -DNDEBUG -DWIN32 -I%OUTPUT%\include\SDL2 %SOURCE%\SDL2_compat\src\SDLmain\windows\SDL_windows_main.c || exit /b 1
lib.exe -nologo -out:SDL2main.lib SDL_windows_main.obj || exit /b 1
move /y SDL2main.lib %OUTPUT%\lib\
popd

rem
rem Collect Commit Hashes
rem

set /p SDL_COMMIT=<%SOURCE%\SDL\.git\refs\heads\main
set /p SDL_IMAGE_COMMIT=<%SOURCE%\SDL_image\.git\refs\heads\main
set /p SDL_MIXER_COMMIT=<%SOURCE%\SDL_mixer\.git\refs\heads\main
set /p SDL_TTF_COMMIT=<%SOURCE%\SDL_ttf\.git\refs\heads\main
set /p SDL_RTF_COMMIT=<%SOURCE%\SDL_rtf\.git\refs\heads\main
set /p SDL_NET_COMMIT=<%SOURCE%\SDL_net\.git\refs\heads\main
set /p SDL_SHADERCROSS_COMMIT=<%SOURCE%\SDL_shadercross\.git\refs\heads\main
set /p SDL2_COMPAT_COMMIT=<%SOURCE%\SDL2_compat\.git\refs\heads\main

echo SDL             %SDL_COMMIT%              > %OUTPUT%\commits.txt
echo SDL_image       %SDL_IMAGE_COMMIT%       >> %OUTPUT%\commits.txt
echo SDL_mixer       %SDL_MIXER_COMMIT%       >> %OUTPUT%\commits.txt
echo SDL_ttf         %SDL_TTF_COMMIT%         >> %OUTPUT%\commits.txt
echo SDL_rtf         %SDL_RTF_COMMIT%         >> %OUTPUT%\commits.txt
echo SDL_net         %SDL_NET_COMMIT%         >> %OUTPUT%\commits.txt
echo SDL_shadercross %SDL_SHADERCROSS_COMMIT% >> %OUTPUT%\commits.txt
echo SDL2_compat     %SDL2_COMPAT_COMMIT%     >> %OUTPUT%\commits.txt

for %%F in (SDL3_mixer SDL3_image SDL3_mixer SDL3_net SDL3_rtf SDL3_ttf SDL3_shadercross) do (
  move %OUTPUT%\include\%%F\*.h %OUTPUT%\include\SDL3\ 1>nul 2>nul
  rd /s /q %OUTPUT%\include\%%F 1>nul 2>nul
)

rem
rem GitHub Actions
rem

if "%GITHUB_WORKFLOW%" neq "" (

  for /F "skip=1" %%D in ('WMIC OS GET LocalDateTime') do (set LDATE=%%D & goto :dateok)
  :dateok
  set OUTPUT_DATE=%LDATE:~0,4%-%LDATE:~4,2%-%LDATE:~6,2%

  del /q %OUTPUT%\bin\*.pdb %OUTPUT%\lib\SDL3_test.lib %OUTPUT%\lib\SDL2_test.lib 1>nul 2>nul
  del /q %OUTPUT%\include\SDL3\SDL_test*.h %OUTPUT%\include\SDL2\SDL_test*.h 1>nul 2>nul
  rd /s /q %OUTPUT%\cmake %OUTPUT%\lib\pkgconfig %OUTPUT%\licenses %OUTPUT%\share 1>nul 2>nul

  echo Creating SDL3-%TARGET_ARCH%-!OUTPUT_DATE!.zip
  %SZIP% a -y -r -mx=9 SDL3-%TARGET_ARCH%-!OUTPUT_DATE!.zip SDL3-%TARGET_ARCH% || exit /b 1

  echo OUTPUT_DATE=!OUTPUT_DATE!>>%GITHUB_OUTPUT%

  echo SDL_COMMIT=%SDL_COMMIT%>>%GITHUB_OUTPUT%
  echo SDL_IMAGE_COMMIT=%SDL_IMAGE_COMMIT%>>%GITHUB_OUTPUT%
  echo SDL_MIXER_COMMIT=%SDL_MIXER_COMMIT%>>%GITHUB_OUTPUT%
  echo SDL_TTF_COMMIT=%SDL_TTF_COMMIT%>>%GITHUB_OUTPUT%
  echo SDL_RTF_COMMIT=%SDL_RTF_COMMIT%>>%GITHUB_OUTPUT%
  echo SDL_NET_COMMIT=%SDL_NET_COMMIT%>>%GITHUB_OUTPUT%
  echo SDL_SHADERCROSS_COMMIT=%SDL_SHADERCROSS_COMMIT%>>%GITHUB_OUTPUT%
  echo SDL2_COMPAT_COMMIT=%SDL2_COMPAT_COMMIT%>>%GITHUB_OUTPUT%
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
  pushd %SOURCE%
) else (
  if not exist "%3" mkdir "%3"
  pushd %3
)
if /i "%DNAME:~0,8%" equ "harfbuzz" set SKIP_EXTRA=-xr^^!README
%SZIP% x -bb0 -y %ARCHIVE% -so | %SZIP% x -bb0 -y -ttar -si -aoa -xr^^!*\tools\benchmark\metrics -xr^^!*\tests\cli-tests -xr^^!*\lib\lib.gni !SKIP_EXTRA! 1>nul 2>nul
set SKIP_EXTRA=
if exist pax_global_header del /q pax_global_header
popd
goto :eof

rem
rem call :clone output_folder "https://..."
rem

:clone
pushd %SOURCE%
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
