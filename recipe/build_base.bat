@echo on
set "PYO3_PYTHON=%PYTHON%"

:: Use CMake to build aws-lc-sys on win-64; on win-arm64 the cc builder avoids
:: CMake ASM/ClangCL issues in BuildTools-only environments.
if /I not "%VSCMD_ARG_TGT_ARCH%"=="arm64" (
  set AWS_LC_SYS_CMAKE_BUILDER=1
  set "CMAKE_GENERATOR=NMake Makefiles"
)
:: Jitter entropy module requires intrinsics headers not available in the
:: conda build env; safe to disable on Windows where BCryptGenRandom provides
:: OS-level entropy.
set AWS_LC_SYS_NO_JITTER_ENTROPY=1
set CARGO_PROFILE_RELEASE_STRIP=symbols
set CARGO_PROFILE_RELEASE_LTO=fat

:: ring on win-arm64 needs clang on PATH for assembly.
if exist "%BUILD_PREFIX%\Library\bin\clang.exe" (
  set "PATH=%BUILD_PREFIX%\Library\bin;%PATH%"
)

if /I "%VSCMD_ARG_TGT_ARCH%"=="arm64" (
  :: aws-lc-sys cc builder must compile ARM .S files with clang, not cl.exe.
  set "CC=%BUILD_PREFIX%\Library\bin\clang.exe"
  set "CXX=%BUILD_PREFIX%\Library\bin\clang.exe"
  set "CFLAGS=--target=aarch64-pc-windows-msvc"
  set "CXXFLAGS=--target=aarch64-pc-windows-msvc"
)

maturin build -v --jobs 1 --release --strip --manylinux off --interpreter=%PYTHON% --no-default-features --features=native-tls || exit 1

cd py-rattler

FOR /F "delims=" %%i IN ('dir /s /b target\wheels\*.whl') DO set py_rattler_wheel=%%i
%PYTHON% -m pip install --ignore-installed --no-deps %py_rattler_wheel% -vv || exit 1

cargo-bundle-licenses --format yaml --output THIRDPARTY.yml || exit 1
