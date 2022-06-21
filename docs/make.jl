using Revise
using Documenter, DocumenterLaTeX
using RDMREopt
using Distributions

makedocs(
    sitename = "RDMREopt Robust Decision Making with REopt",
    # format = LaTeX(platform = "docker"), #lots of blank pages, ghost sections
    modules = [RDMREopt],
    workdir = joinpath(@__DIR__, ".."),
    pages = [
        "Home" => "index.md",
    ],
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.
deploydocs(
    repo = "github.com/NREL/RDMREopt.jl.git"
)
