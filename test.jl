using Pkg
Pkg.activate("../Dashboard/env")
using Colors
using TopoPlots
using StatsBase # mean/std
using Pipe
using ColorSchemes
using LinearAlgebra
using Makie
using WGLMakie


Pkg.status()

data, pos = TopoPlots.example_data()

function ft_topo_axis(f, sensornum, times, data;
    time=nothing, topo_slice=nothing,  width_height = 175, labels=nothing,
    mark_color=nothing, markersize = 1, interpolation=ClaughTochter(), colormap = Reverse(:RdBu), label_text=false)

    N = 1:sensornum
    topo_axis = Axis(f, width = width_height, height = width_height, aspect = DataAspect())
    if time == nothing
        topo = eeg_topoplot!(topo_axis, topo_slice, mark_color, N, labels;
        positions=pos[1:sensornum], 
        enlarge=1,
        interpolation=interpolation,
        colormap = colormap,
        label_scatter=(markersize=markersize, strokewidth=0.5) 
    )
    else
        topo_slice = lift((t, data) -> mean(data[1:sensornum, indexin(t, times), :], dims=2)[:,1], time, data)
       
        topo = eeg_topoplot!(topo_axis, topo_slice, N; 
        positions=pos[1:sensornum], 
        enlarge=1,
        interpolation=interpolation,
        colormap = colormap,
        label_scatter=(markersize=markersize, strokewidth=0.5) 
        ) 
end
    hidedecorations!(topo_axis)
    hidespines!(topo_axis)
    return topo_axis
end

let 
    data, pos = TopoPlots.example_data()
    f = Figure(resolution = (1000, 900))
    xs = range(-0.3, length=size(data, 2), step=1 ./ 128) 

    topo_axis = Axis(f[1, 1], aspect = DataAspect())
    topo_slice = data[:,120,1]
    topo_axis = ft_topo_axis(f[1, 1], length(pos), xs, data; 
        time=nothing, topo_slice=topo_slice,  width_height=900, markersize = 10, label_text=false)

    f
end

function slider_topoplot(data, pos; 
    title="Interactive topoplot", 
    interpolation=ClaughTochter()) 
    f = Figure(resolution = (900, 600))
    N = 1:length(pos)
    xs = range(0, length=size(data, 2), step=1 ./ 100) 
    sg = SliderGrid(f[2, 1],
        (label = "time", range = xs, format = "{:.3f} ms", startvalue = 0),
    )
    time = sg.sliders[1].value

    topo_axis = ft_topo_axis(f[1, 1], length(pos), xs, data; 
    time=time, width_height=500, markersize = 1)
    # decrement/increment slider with left/right keys
    on(events(f).keyboardbutton) do btn
        if btn.action in (Keyboard.press, Keyboard.repeat)
            if btn.key == Keyboard.left
                set_close_to!(sg.sliders[1], time[] - 1)
            elseif btn.key == Keyboard.right
                set_close_to!(sg.sliders[1], time[] + 1)
            end
        end
    end
    str = lift(t -> "[$(round(t, digits = 3)) ms]", time)
    text!(topo_axis, 1, 1, text = str,  align = (:center, :center))
    
    f
end

slider_topoplot(data, pos)

function click_butterfly_topoplot(data, pos; title="Interactive topoplot", interpolation=ClaughTochter(),
    sensornum=64, startpoint=-0.2, steps=100)  

    N = 1:sensornum
    onset = 0.0
    steps = 1 ./ steps
    times = range(startpoint, length=size(data, 2), step=steps)  
    endpoint = times[end]

    f = Figure(backgroundcolor = RGBf(0.98, 0.98, 0.98), resolution = (1500, 700))
    ax = Axis(f[1:3, 1], xlabel = "Time [s]", ylabel = "Voltage amplitude [µV]")

    hidespines!(ax, :t, :r) 
    xlims!(startpoint, endpoint)
    hlines!(0, color = :gray, linewidth = 1)
    vlines!(0, color = :gray, linewidth = 1)
    
    datl = [mean(data[i,:,:], dims=2)[:,1] for i = 1:sensornum]
    datl2 = reduce(hcat, datl)'
    datl2 = datl2 .- mean(datl2[:,times .< onset], dims=2) # basline correction

    i = Observable(15)
    begin
        tmp1 = repeat([0], sensornum)
        mark_color = @lift begin
            tmp1[1:end] .= 0
            if $i != 0
                tmp1[$i] = 1
            end
            return tmp1

        end
        red_line = @lift begin
            datl3 = datl2'
            tmp2 = datl3[:, 1]  
                if $i != 0
                    tmp2 = datl3[:, $i]
                end
                return tmp2
        end
    end

    series!(ax, times, datl2, solid_color="#4d4d4d")

    cmap = collect(ColorScheme(range(colorant"black", colorant"red", length=2)))
    mark_size = repeat([21], sensornum)
    topo_axis = ft_topo_axis(f[2:3, 2], sensornum, times, data; mark_color=mark_color, colormap = cmap, 
    interpolation=NullInterpolator(), time=nothing, width_height=345, 
    markersize = mark_size)
    
    labels = ["s$i" for i in 1:sensornum]
    str = lift((i, labels) -> "$(labels[i])", i, labels)
    Label(f[1, 2], str,
        fontsize =36, font = :bold, padding = (0, 0, 0, 50), halign = :center)

    lc = nothing
    on(events(f).mousebutton, priority = 2) do event
        if event.button == Mouse.left && event.action == Mouse.press

            plt, p = pick(topo_axis)
            i[] = p
            if lc != nothing
                lc.color  = "#4d4d4d"
                lc.linewidth  = 1.5
            end
            lc = lines!(ax, times, red_line[], color = "red", linewidth = 5)

        end
    end
    hidedecorations!(ax, label = false, ticks = false, ticklabels = false) 
    f
end

click_butterfly_topoplot(data, pos)

function menu_butterfly_topoplot(data, pos; title="Interactive topoplot", interpolation=ClaughTochter(),
    sensornum=64, startpoint=-0.2, steps=100) 
    N = 1:sensornum
    onset = 0.0
    steps = 1 ./ steps
    times = range(startpoint, length=size(data, 2), step=steps)  
    endpoint = times[end]
    
    f = Figure(backgroundcolor = RGBf(0.98, 0.98, 0.98), resolution = (1500, 700))
    ax = Axis(f[1:3, 1], xlabel = "Time [s]", ylabel = "Voltage amplitude [µV]")

    N = 1:length(pos)
    hidespines!(ax, :t, :r) 
    xlims!(startpoint, endpoint)
    hlines!(0, color = :gray, linewidth = 1)
    vlines!(0, color = :gray, linewidth = 1)
    
    datl = [mean(data[i,:,:],dims=2)[:,1] for i = 1:sensornum]
    datl2 = reduce(hcat, datl)'
    datl2 = datl2 .- mean(datl2[:,times .< onset], dims=2) # basline correction

    num = Observable(0)

    begin
        tmp1 = repeat([0], sensornum)
        mark_color = @lift begin
            tmp1[1:end] .= 0
            if $num != 0
                tmp1[$num] = 1
            end
            return tmp1
        end
        red_line = @lift begin
            datl3 = datl2'
            tmp2 = datl3[:, 1]  
                if $num != 0
                    tmp2 = datl3[:, $num]
                end
                return tmp2
        end
    end

    series!(ax, times, datl2, solid_color="#4d4d4d")

    hidedecorations!(ax, label = false, ticks = false, ticklabels = false) 
    cmap = collect(ColorScheme(range(colorant"black", colorant"red", length=2)))
    
    mark_size = repeat([21], sensornum)
    labels = ["s$i" for i in 1:sensornum]
    menu = Menu(f[3, 2], options = labels, default = nothing)

    topo_axis = ft_topo_axis(f[1:2, 2], sensornum, mark_color=mark_color, labels=labels, colormap = cmap, 
        interpolation=NullInterpolator(), time=nothing, times, data, width_height=345, markersize = mark_size)

    lc = nothing
        on(menu.selection) do selected
        if selected != nothing
            if lc != nothing
                lc.color  = "#4d4d4d"
                lc.linewidth  = 1.5
            end
            num[] = findfirst(x->x==menu.selection[], labels)
            lc = lines!(ax, times, red_line[], color = "red", linewidth = 5)
            notify(mark_color)
            notify(red_line)   
        end
    end
    notify(menu.selection) 
    hidedecorations!(topo_axis)
    hidespines!(topo_axis)
    f

end

menu_butterfly_topoplot(data, pos)

function slider_butterfly_topoplot(data, pos; 
    title="Interactive topoplot", 
    interpolation=ClaughTochter(),
    sensornum=64, startpoint=-0.2, steps=100) 
N = 1:sensornum
onset = 0.0
steps = 1 ./ steps
times = range(startpoint, length=size(data, 2), step=steps)  
endpoint = times[end]
f = Figure(backgroundcolor = RGBf(0.98, 0.98, 0.98), resolution = (1500, 700))

# interaction

sg = SliderGrid(f[4, 1:3],
    (label="time", range=times, format = "{:.3f} ms", startvalue = 0),
)
time = sg.sliders[1].value
str = lift(t -> "$(round(t, digits = 3)) ms", time)

specialColors = ColorScheme(vcat(RGB(1,1,1.),[posToColorRomaO(pos) for pos in pos[N]]...))

# butterfly plot
ax = Axis(f[2:3, 1:3], xlabel = "Time [s]", ylabel = "Voltage amplitude [µV]")

hidespines!(ax, :t, :r) 
xlims!(startpoint, endpoint)
hlines!(0, color = :gray, linewidth = 1)
vlines!(onset, color = :gray, linewidth = 1)


datl = [mean(data[i,:,:],dims=2)[:,1] for i = 1:sensornum]
datl2 = reduce(hcat, datl)'
datl2 = datl2 .- mean(datl2[:,times .< onset], dims=2)
series!(ax, times, datl2, color = specialColors[2:sensornum+1])

hidedecorations!(ax, label = false, ticks = false, ticklabels = false) 
vlines!(time, color = :red, linewidth = 1)

ft_topo_axis(f[1, 2], sensornum, time=time, times, data, width_height=175, markersize = 1)


Label(f[1, 2], str,
    fontsize =36, font = :bold, padding = (40, 500, 0, 0), halign = :right)

hidedecorations!(current_axis())
hidespines!(current_axis())
f
end

slider_butterfly_topoplot(data, pos)



function posToColorRomaO(pos)
    rx = 0.5 - pos[1]
    ry = 0.5 - pos[2]

    θ,r =  cart2pol.(rx,ry)
    # circular colormap 2D
    colorwheel = get(ColorSchemes.romaO,θ)
    return colorwheel
end


function cart2pol(x,y)
θ = atan(x,y) ./(2*π)+0.5
r = sqrt(x^2 + y^2)
    return θ, r
end