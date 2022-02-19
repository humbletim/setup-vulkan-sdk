# helper to create a wrapper that provides _temporary_ visual studio dev tools prompt
# (ie: vsdevcmd.bat for the lifetime of the sub command executed)
# example if create_msvc_wrapper msvc-amd64 amd64 => ~/bin/msvc-amd64
#   msvc-amd64 which cl.exe # outputs path to devtools cl.exe compiler
#   msvc-amd64 cmake ... # invoke cmake in devtools prompt environment

function create_msvc_wrapper() {
  local name=$1 arch=$2 bin_dir=$3
  test -d $bin_dir || mkdir -pv $bin_dir
  
  local vsdevcmd=$(cygpath -ms /c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/*/*/Common7/Tools/vsdevcmd.bat|sort -r|head -1)
  
  # helper function for "perfect" arguments forwarding
  # (ie: bash context => cmd.exe vsdevcmd.bat => bash context w/env [commands/arguments])
  function vsdevenv() {
      local tmpfile=$(mktemp -p $PWD);
      echo "#!/bin/bash" > $tmpfile
      for x in "$@" ; do echo -n "\"""$x""\" " >> $tmpfile; done
      echo >> $tmpfile
      cmd //q //c "$vsdevcmd -no_logo -arch=$arch -host_arch=amd64 && bash $tmpfile";
      rm $tmpfile
  }
  local ASM=$(cygpath -ms /c/Program\ Files\ \(x86\)/Microsoft\ Visual\ Studio/*/*/VC/Tools/MSVC/*/bin/Hostx64/*/ml.exe|sort -r|head -1)
  local ASM_PATH=$(dirname $(cygpath $ASM))
  # bash script wrapper
  cat <<-EOF > $bin_dir/$name
#!/bin/bash
vsdevcmd=$vsdevcmd
# ASM_PATH=$ASM_PATH
export PATH=$ASM_PATH:\$PATH
$(declare -f vsdevenv)
vsdevenv "\$@"
EOF
  # batch file wrapper (that delegates back to bash script...)
  cat <<-EOF > $bin_dir/$name.bat
@echo off
SETLOCAL DisableDelayedExpansion

SETLOCAL
for %%a in (1) do (
set "prompt=$_"
echo on
for %%b in (1) do rem * #%*#
@echo off
) > argv.txt
ENDLOCAL

for /F "delims=" %%L in (argv.txt) do (
set "argv=%%L"
)
SETLOCAL EnableDelayedExpansion
set "argv=!argv:*#=!"
set "argv=!argv:~0,-2!"
REM argv now contains the unmodified content of %* .

bash $bin_dir/$name !argv!
EOF
}
