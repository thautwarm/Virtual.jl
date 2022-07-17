using Virtual
using Documenter

DocMeta.setdocmeta!(Virtual, :DocTestSetup, :(using Virtual); recursive=true)

makedocs(;
    modules=[Virtual],
    authors="thautwarm",
    repo="https://github.com/thautwarm/Virtual.jl/blob/{commit}{path}#{line}",
    sitename="Virtual.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://thautwarm.github.io/Virtual.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/thautwarm/Virtual.jl",
    devbranch="main",
)
