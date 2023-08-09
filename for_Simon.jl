using Pkg
Pkg.activate("./Dashboard/env")

# for App

using Revise
using JSServe
using WGLMakie
using Deno_jll
import JSServe.TailwindDashboard as D
using Observables


# fpr formual exraction
#Pkg.add(PackageSpec(name="PyMNE", version="0.1.2"))
using PyMNE

using Unfold
using UnfoldMakie
using UnfoldSim
using DataFrames
using ColorSchemes
using Random
using Colors
using DataFramesMeta


# data simulation
d1, evts = UnfoldSim.predef_eeg(; return_epoched=true);
dataS = permutedims(repeat(d1, 1, 1, 64), (3, 1, 2));
size(dataS)

# creation of formula
formulaS = @formula(0 ~ 1 + condition + continuous)
formulaS = @formula(0 ~ 1 + continuous)
formulaS = @formula(0 ~ 1 + condition )

function formula_extractor(dataS, formulaS)
    times = range(0, length=size(dataS, 2), step=1 ./ 100)  
    
    m = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times);

    #coefnames
    a = unique(coeftable(m).coefname)[2:3]
    name = [split(i, ":")[1] for i in a]

    # type
    ty = [typeof.(Unfold.formula(m).rhs.terms)[2].name.name
    typeof.(Unfold.formula(m).rhs.terms)[3].name.name]

    #terms
    b = Unfold.formula(m).rhs.terms[2].contrasts.levels
    c = Unfold.formula(m).rhs.terms[3]
    te = (b, (min = c.min, max = c.max, var = c.var, mean = c.mean))

    d = Dict(name .=> zip(ty, te))
    return d
end
fe = formula_extractor(dataS, formulaS)
fe


times = range(0, length=size(dataS, 2), step=1 ./ 100)  
    
    m = Unfold.fit(UnfoldModel, formulaS, evts, dataS, times);

    #coefnames
    a = unique(coeftable(m).coefname)
    a = a[2:length(a)]
    name = [split(i, ":")[1] for i in a]

    # type
    ty = []
    l = length(Unfold.formula(m).rhs.terms)
    for i in 1:2
        append!(ty, typeof.(Unfold.formula(m).rhs.terms)[i].name.name)
    end

    ty = [typeof.(Unfold.formula(m).rhs.terms)[2].name.name
    typeof.(Unfold.formula(m).rhs.terms)[3].name.name]

    #terms
    b = Unfold.formula(m).rhs.terms[2].contrasts.levels
    c = Unfold.formula(m).rhs.terms[3]
    te = (b, (min = c.min, max = c.max, var = c.var, mean = c.mean))

    d = Dict(name .=> zip(ty, te))




display(fe)

using JSServe: @js_str, Session, App, onjs, onload, Button
using JSServe: TextField, Slider, linkjs
using JSServe.DOM


using FFTW
using Random
using Markdown


function find_route(server, target_app)
    for (route, app) in server.routes.table
        app === target_app && return route
    end
    return nothing
end

function link_app(server, app, title=app.title)
    route = find_route(server, app)
    url = online_url(server, route)
    imgname = replace(lowercase(title), " " => "_")
    img_asset = Asset(joinpath(@__DIR__, "$(imgname).png"))
    return DOM.a(DOM.img(src=img_asset, height="200px", style="height: 200px"), href=url)
end

function app_card(app)
    return D.Card(
        D.FlexCol(
            DOM.h2(app.title),
            link_app(server, app)
        )
    )
end

index_app = App() do
    cards = app_card.([volume_app])
    return DOM.div(
        DOM.h1("Bonito Demos:"),
        D.FlexRow(cards...)
    )
end


# Needed to run with `sudo julia` which changes the homedir
# sudo is needed for a process to listen to port `80`



function on_latest(f, session, observable::Observable{T}; update=false) where T
    queue = Channel{T}(64) do channel
        while isopen(channel)
            value = take!(channel)
            if isempty(channel)
                f(value)
            end
        end
    end
    on(session, observable; update=update) do new_value
        put!(queue, new_value)
    end
end

function onany_latest(f, session, args...)
    callback = Observables.OnAny(f, args)
    obsfuncs = ObserverFunction[]
    for observable in args
        if observable isa AbstractObservable
            obsfunc = on_latest(callback, session, observable)
            push!(obsfuncs, obsfunc)
        end
    end
    return obsfuncs
end


volume_app = App(title="Volume") do session::Session
    algorithms = ["mip", "iso", "absorption"]
    algorithm = Observable(first(algorithms))
    algorithm_drop = D.Dropdown("Algorithm", algorithms)
    algorithm = algorithm_drop.value
    N = 100
    data_slider = D.Slider("data param", LinRange(1.0f0, 10.0f0, 100))
    iso_value = D.Slider("iso value", LinRange(0.0f0, 1.0f0, 100))
    slice_idx = D.Slider("slice", 1:N)

    signal = Observable{Array{Float32, 3}}(zeros(Float32, N, N, N))
    on_latest(session, data_slider.value; update=true) do α
        a = -1; b = 2; r = LinRange(-2, 2, N)
        z = ((x, y) -> x + y).(r, r') ./ 5
        me = [z .* sin.(α .* (atan.(y ./ x) .+ z .^ 2 .+ pi .* (x .> 0))) for x = r, y = r, z = r]
        signal[] = me .* (me .> z .* 0.25)
    end

    slice = Observable{Matrix{Float32}}(zeros(Float32, N, N))
    onany_latest(session, signal, slice_idx.value) do x, idx
        slice[] = view(x, :, idx, :)
    end

    fig = Figure()
    cmap = D.Dropdown("Colormap", ["Hiroshige", "Spectral_11", "diverging_bkr_55_10_c35_n256",
        "diverging_cwm_80_100_c22_n256", "diverging_gkr_60_10_c40_n256",
        "diverging_linear_bjr_30_55_c53_n256",
        "diverging_protanopic_deuteranopic_bwy_60_95_c32_n256"])

    vol = volume(fig[1, 1], signal;
        algorithm=map(Symbol, algorithm),
        colormap=cmap.value,
        isovalue=iso_value.value,
        colorrange=(-0.2, 2))

    heat = heatmap(fig[1, 2], slice, colormap=cmap.value, colorrange=(-0.2, 2))

    return D.FlexRow(
        D.Card(D.FlexCol(
            data_slider,
            iso_value,
            slice_idx,
            algorithm_drop,
            cmap,
        )),
        D.Card(fig)
    )
end




display(volume_app)

HTML("""
<iframe src="http://localhost:9384/browser-display" width="80%" height="100%" style="background: #FFFFFF;" allowtransparency="true"></iframe>
""")
