@echo on
set "PYO3_PYTHON=%PYTHON%"

:: Use CMake on win-64. The cc builder avoids CMake ASM/ClangCL issues
:: in BuildTools-only environments on win-arm64.
:: Ninja, not NMake: on current win-64 images the NMake generator's
:: vs_link_exe manifest is rejected by the SDK rc.exe, which aborts the
:: aws-lc-sys CMake compiler check with
:: "manifest.rc(3) : error RC2136 : missing '=' in EXSTYLE=<flags>".
:: Same generator setup as py-rattler-build-feedstock.
if /I not "%VSCMD_ARG_TGT_ARCH%"=="arm64" (
  set AWS_LC_SYS_CMAKE_BUILDER=1
  set "CMAKE_GENERATOR=Ninja"
)
:: Jitter entropy module requires intrinsics headers not available in the
:: conda build env; safe to disable on Windows where BCryptGenRandom provides
:: OS-level entropy.
set AWS_LC_SYS_NO_JITTER_ENTROPY=1
set CARGO_PROFILE_RELEASE_STRIP=symbols
set CARGO_PROFILE_RELEASE_LTO=fat

if /I "%VSCMD_ARG_TGT_ARCH%"=="arm64" (
  set "CARGO_HOME=C:\cargo"
  :: ring needs clang on PATH for its ARM64 assembly.
  set "PATH=%BUILD_PREFIX%\Library\bin;%PATH%"
  :: Compile aws-lc-sys ARM64 assembly with clang rather than cl.exe.
  set "CC=%BUILD_PREFIX%\Library\bin\clang.exe"
  set "CXX=%BUILD_PREFIX%\Library\bin\clang.exe"
  set "CFLAGS=--target=aarch64-pc-windows-msvc"
  set "CXXFLAGS=--target=aarch64-pc-windows-msvc"
)

maturin build -v --jobs 1 --release --strip --manylinux off --interpreter=%PYTHON% --no-default-features --features=native-tls --locked
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

cd py-rattler

FOR /F "delims=" %%i IN ('dir /s /b target\wheels\*.whl') DO set py_rattler_wheel=%%i
%PYTHON% -m pip install %py_rattler_wheel% -vv --no-deps --no-build-isolation
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

cargo-bundle-licenses --format yaml --output THIRDPARTY.yml
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
