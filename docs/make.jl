using CloudCovFix
using Documenter

makedocs(
    modules = [CloudCovFix],
    clean=true,
    highlightsig = true,
    sitename= "CloudCovFix.jl",
    format = Documenter.HTML(
        assets = ["assets/favicon.ico"],
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    pages    = [
        "Introduction" => "index.md",
        "API Reference" => "api.md",
        "Contributing" => "contrib.md"
    ]
)

deploydocs(
    repo = "github.com/andrew-saydjari/CloudCovFix.jl.git",
    branch = "gh-pages",
    devbranch = "main"
)
