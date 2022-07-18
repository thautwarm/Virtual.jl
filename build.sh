COMPILE_TIME=true julia -q --project --compile=min --optimize=0 -e \
    'import Pkg;Pkg.add("MLStyle");using Virtual;Pkg.rm("MLStyle");'