
## Hosting documentation locally
```julia
[~/projects/2022/ERMA/RDMREopt]
nlaws-> julia --project=./docs/

   _       _ _(_)_     |  Documentation: https://docs.julialang.org
  (_)     | (_) (_)    |
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.7.2 (2022-02-06)
 _/ |\__'_|_|_|\__'_|  |  Official https://julialang.org/ release
|__/                   |

(docs) pkg> dev .
```
You must `Pkg.dev(".")` in the docs Project for the docs to update using the following method. The server does not pick up on changes dynamically so the process below must be repeated to show changes.
```
[~/projects/2022/ERMA/RDMREopt/docs]
nlaws-> julia --project=. make.jl 
[ Info: SetupBuildDirectory: setting up build directory.
[ Info: Doctest: running doctests.
[ Info: ExpandTemplates: expanding markdown templates.
[ Info: CrossReferences: building cross-references.
[ Info: CheckDocument: running document checks.
[ Info: Populate: populating indices.
[ Info: RenderDocument: rendering document.
[ Info: HTMLWriter: rendering HTML pages.
```

Now you can use `LiveServer.jl` to host the documentation locally:
```
[~/projects/2022/ERMA/RDMREopt/docs]
nlaws-> julia --project=.
```
```julia
               _
   _       _ _(_)_     |  Documentation: https://docs.julialang.org
  (_)     | (_) (_)    |
   _ _   _| |_  __ _   |  Type "?" for help, "]?" for Pkg help.
  | | | | | | |/ _` |  |
  | | |_| | | | (_| |  |  Version 1.7.2 (2022-02-06)
 _/ |\__'_|_|_|\__'_|  |  Official https://julialang.org/ release
|__/                   |

julia> cd("build/")

julia> using LiveServer

julia> serve()
✓ LiveServer listening on http://localhost:8000/ ...
  (use CTRL+C to shut down)
```
In VSCode you can CMD/CTRL click on `http://localhost:8000/` to open your default browser.

To reload changes:
```julia

cd("..")

include("make.jl")

cd("build/")

serve()
```