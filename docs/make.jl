using Documenter, PowerModelsAnalytics

makedocs(
    modules = [PowerModelsAnalytics],
    format = Documenter.HTML(analytics = "", mathengine = Documenter.MathJax()),
    sitename = "PowerModelsAnalytics",
    authors = "David M Fobes, Carleton Coffrin, and contributors.",
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "Getting Started" => "quickguide.md"
        ],
        "Library" => [
            "Functions" => "library.md",
            # "Graphs" => "graphs.md",
            # "Plots" => "plots.md",
            # "Layouts" => "layouts.md"
        ],
        "Developer" => [
            "Developer" => "developer.md"
        ],
    ]
)

deploydocs(
    repo = "github.com/lanl-ansi/PowerModelsAnalytics.jl.git",
)
