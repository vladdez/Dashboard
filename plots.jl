using Pkg
#Pkg.activate("./Dashboard/env")
temp_dir = mktempdir()

# Activate a new project environment in the temporary directory
Pkg.activate(temp_dir)

using Unfold
using UnfoldMakie
using Revise
using DataFrames
using CairoMakie


results_plot = UnfoldMakie.example_data()
first(results_plot,6)

plot_parallelcoordinates(results_plot, [5,3,2];
    setMappingValues = (category=:coefname, y=:estimate),
    setLayoutValues = (legendPosition=:bottom,))

    # We choose to put the legend at the bottom instead of to the rightst