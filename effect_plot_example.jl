### A Pluto.jl notebook ###
# v0.19.12

using Markdown
using InteractiveUtils

# ╔═╡ ec41b2d6-07ac-11ed-2efb-6b0914609b45
begin
	using Pkg
	Pkg.activate("/../../store/users/skukies/Projects/ECVP/")
	p = "ShiftedArrays"
	Pkg.add(p)
	Pkg.build(p)	
	using Unfold
	using PyMNE
	using UnfoldMakie
	using AlgebraOfGraphics
	using CairoMakie
	using DataFrames
	using DataFramesMeta
	using CSV
	using ShiftedArrays
	using StatsModels
	
	using StatsBase
end

# ╔═╡ e95794ae-e192-4e34-b684-4d455a160a5c
begin
	Pkg.status()
end

# ╔═╡ 915abb0a-7860-4c96-9ea6-2b86a75074ce


# ╔═╡ fda9fbbc-79b8-4b94-bcf6-e2ace0278c5c


# ╔═╡ cc3ed0ee-0167-43e2-92ae-b7d184515b03


# ╔═╡ 82823958-7bb8-4090-a60c-7804d2a942a9


# ╔═╡ feffcf10-7b91-4cd9-b19f-ecd86190c762
begin
	sub = 45
	path_subject = "/store/data/WLFO/derivatives/preproc_agert/sub-$(sub)/eeg/"
	raw = PyMNE.io.read_raw_eeglab(path_subject*"sub-$(sub)_task-WLFO_eeg.set")
end

# ╔═╡ a92ba7e9-d944-4096-860d-fa1292d33056
sfreq = raw.info["sfreq"];

# ╔═╡ 1317b0f7-a249-425f-bd1c-42b0cd14a58b
begin
	events = CSV.read(path_subject*"sub-$(sub)_task-WLFO_events.tsv",DataFrame, 	delim="\t")
	# add latency (event onsets in samples)
	events[!,:latency] .= events.onset .* sfreq;
end

# ╔═╡ af5cb0f9-3033-4096-8b40-38fa982603bf
events

# ╔═╡ a5230aaf-c810-47bd-a2c8-3e9d09c1c33e
begin
	tmp = events
	tmp = tmp[tmp.type .== "fixation",:]
	f = Figure()
	axes = Axis(f[1, 1])
	density!(tmp.duration, color = (:red, 0.3),
    strokecolor = :red, strokewidth = 3)
	axes.xticks = 0:0.2:1.6
	f
end

# ╔═╡ cf799d27-df5c-4124-88af-d9d8bb1bf4da
begin
	f2 = Figure()
	axes2 = Axis(f2[1, 1])
	hist!(tmp.duration, bins = 30, strokecolor = :blue, strokewidth = 2) #, color = (:red, 0.3),
    #strokecolor = :red, strokewidth = 3)
	axes2.xticks = 0:0.2:1.6
	f2
end


# ╔═╡ 35e67f2b-45e4-4571-b5bb-b74496012cda
events

# ╔═╡ d7961760-5297-44a2-8619-dd726c3eb6a9
unique(events.fix_type)

# ╔═╡ 0c209f78-a52d-4f76-9cb9-fcc6eba9f938
begin
	#channel = "Oz" #Index 31;
	# @Anmol Note: you probably want all channels here, just remove the picks=... part
	channel_list = ["Oz"]
	data = raw.get_data(picks=channel_list).*10^6;
end

# ╔═╡ a74fcfb5-25b5-4414-bee6-74f7b02c3b9a
design = Dict(
"fixation"=>(
	@formula(0~1+spl(duration,5)),
	firbasis(τ=(-0.2,1),sfreq=sfreq,name="fixation")),
"stimulus"=>(
	@formula(0~1),
	firbasis(τ=(-0.2,1),sfreq=sfreq,name="stimulus")),
);

# ╔═╡ f8c47c03-6516-41fd-821d-a298a9c9ef41
uf = fit(UnfoldModel,design,events,data,eventcolumn="type")

# ╔═╡ 47fb221d-adc1-4046-970b-59fd96b91e22
result = coeftable(uf)

# ╔═╡ 384a2d93-d5cb-4430-9056-59baa165c893
plot_results(result)

# ╔═╡ 128eb895-df03-4e26-9dd5-312f892b2ca6
begin
	predict(uf,DataFrame("duration"=>0.1:0.2:1.0))
	eff = Unfold.effects(Dict(:duration=>0.1:0.1:1.0),uf)
	plot_results(@subset(eff,:basisname .=="fixation"),color=:duration)
end

# ╔═╡ aa6010c5-480f-494b-9a03-7b769f4ce742
eff

# ╔═╡ 7145d87b-4ec0-46ac-90b2-60274aa9c0c3
uf

# ╔═╡ Cell order:
# ╠═ec41b2d6-07ac-11ed-2efb-6b0914609b45
# ╠═e95794ae-e192-4e34-b684-4d455a160a5c
# ╠═915abb0a-7860-4c96-9ea6-2b86a75074ce
# ╠═fda9fbbc-79b8-4b94-bcf6-e2ace0278c5c
# ╠═cc3ed0ee-0167-43e2-92ae-b7d184515b03
# ╠═82823958-7bb8-4090-a60c-7804d2a942a9
# ╠═feffcf10-7b91-4cd9-b19f-ecd86190c762
# ╠═a92ba7e9-d944-4096-860d-fa1292d33056
# ╠═1317b0f7-a249-425f-bd1c-42b0cd14a58b
# ╠═af5cb0f9-3033-4096-8b40-38fa982603bf
# ╠═a5230aaf-c810-47bd-a2c8-3e9d09c1c33e
# ╠═cf799d27-df5c-4124-88af-d9d8bb1bf4da
# ╠═35e67f2b-45e4-4571-b5bb-b74496012cda
# ╠═d7961760-5297-44a2-8619-dd726c3eb6a9
# ╠═0c209f78-a52d-4f76-9cb9-fcc6eba9f938
# ╠═a74fcfb5-25b5-4414-bee6-74f7b02c3b9a
# ╠═f8c47c03-6516-41fd-821d-a298a9c9ef41
# ╠═47fb221d-adc1-4046-970b-59fd96b91e22
# ╠═384a2d93-d5cb-4430-9056-59baa165c893
# ╠═128eb895-df03-4e26-9dd5-312f892b2ca6
# ╠═aa6010c5-480f-494b-9a03-7b769f4ce742
# ╠═7145d87b-4ec0-46ac-90b2-60274aa9c0c3
