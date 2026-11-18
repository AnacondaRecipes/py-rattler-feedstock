@echo on
set "PYO3_PYTHON=%PYTHON%"

:: Use CMake on win-64. The cc builder avoids CMake ASM/ClangCL issues
:: in BuildTools-only environments on win-arm64.
:: Ninja, not NMake: matches py-rattler-build-feedstock (the NMake generator
:: also hits MSVC C1083 on the 8.3 cargo path).
if /I not "%VSCMD_ARG_TGT_ARCH%"=="arm64" (
  set AWS_LC_SYS_CMAKE_BUILDER=1
  set "CMAKE_GENERATOR=Ninja"
)

:: Build outside the deep conda work dir. Under it, aws-lc-sys's CMake scratch
:: path (...\CMakeScratch\TryCompile-*\CMakeFiles\cmTC_*.dir\manifest.rc) runs
:: past ~240 characters, which trips an rc.exe parser bug and fails the CMake
:: compiler check with:
::   manifest.rc(3) : error RC2136 : missing '=' in EXSTYLE=<flags>
:: Keep the target dir short for the same reason, but make it per-user: the PBP
:: Windows pool is multiuser, so a fixed C:\.ct is owned by the account of the
:: first task to run and every later task fails with:
::   error: failed to open: C:\.ct\release\.cargo-build-lock
::   Caused by: Access is denied. (os error 5)
set "CARGO_TARGET_DIR=%USERPROFILE%\.ct"
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

FOR /F "delims=" %%i IN ('dir /s /b %CARGO_TARGET_DIR%\wheels\*.whl') DO set py_rattler_wheel=%%i
%PYTHON% -m pip install %py_rattler_wheel% -vv --no-deps --no-build-isolation
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%

cargo-bundle-licenses --format yaml --output THIRDPARTY.yml
if %ERRORLEVEL% neq 0 exit /b %ERRORLEVEL%
