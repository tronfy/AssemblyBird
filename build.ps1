New-Item -ItemType Directory -Force -Path "build"
Copy-Item "main.asm" -Destination "build"
Copy-Item "rsrc.rc" -Destination "build"
Copy-Item -Path ".\res\*" -Destination "build"

cd build

bldall main
rc rsrc

Remove-Item "main.asm"
Remove-Item "rsrc.rc"

cd ..
