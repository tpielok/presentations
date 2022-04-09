### A Pluto.jl notebook ###
# v0.18.4

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 9402df7c-4c3d-11eb-0f04-670058576045
using Plots, PlutoUI

# ╔═╡ 053ab307-de40-48d6-9687-0bd9a3d88e3b
begin
	import Distributions: Normal, pdf, logpdf, MvNormal
	import ForwardDiff
	import Random
	using Statistics
	using KernelFunctions
	using LinearAlgebra
end

# ╔═╡ 99fb7628-502a-11eb-1d23-7d3a143cd5d3
gr();

# ╔═╡ 032c42f2-5103-11eb-0dce-e7ec59924648
html"<button onclick='present()'>present</button>"

# ╔═╡ 0bb068de-512d-11eb-14e3-8f3de757910d
struct TwoColumn{A, B}
	left::A
	right::B
end

# ╔═╡ 827fbc3a-512d-11eb-209e-cd74ddc17bae
function Base.show(io, mime::MIME"text/html", tc::TwoColumn)
	write(io,
		"""
		<div style="display: flex;">
			<div style="flex: 50%;">
		""")
	show(io, mime, tc.left)
	write(io,
		"""
			</div>
			<div style="flex: 50%;">
		""")
	show(io, mime, tc.right)
	write(io,
		"""
			</div>
		</div>
	""")
end

# ╔═╡ 6382a73e-5102-11eb-1cfb-f192df63435a
md"""
# Stein variational gradient descent
**Tobias Pielok, April 9, 2022**

based on \
*Stein Variational Gradient Descent: A General Purpose Bayesian Inference Algorithm* by Q. Liu *et. al.* and \
*A Kernelized Stein Discrepancy for Goodness-of-fit Tests and 
Model Evaluation* by Q. Liu *et. al.*


*Bayes Club LMU*
"""

# ╔═╡ 6118fcf2-5103-11eb-0adc-1749ac4663a3
md"""
## Starting point

- Bayesian Experiment with smooth prior density ``p_0(\boldsymbol{\theta})`` with ``\boldsymbol{\theta} \in \Theta \subset \mathbb{R}^d`` and data ``X \in \mathcal{X}``
- Likelihood function ``p(X|\; \boldsymbol{\theta})``
- Assuming smooth true posterior density ``p(\boldsymbol{\theta})`` exists
- ``\Rightarrow \exists C \in \mathbb{R}_+ : p(\boldsymbol{\theta}) = p_0(\boldsymbol{\theta})p(X|\; \boldsymbol{\theta})/C``
- ``\iff \log p(\boldsymbol{\theta}) = \log p_0(\boldsymbol{\theta}) + \log p(X|\; \boldsymbol{\theta}) - \log C``
"""

# ╔═╡ 0e1e4b5c-e05c-4fe6-9e69-c2032dd5837b
@bind log_C Slider(-2:0.2:2, default=0)

# ╔═╡ abf59f44-fecf-448f-a004-9720e04a4c0e
begin
	θ = 0:0.02:3;
	
	p(θ, log_C) = (0.3 * pdf(Normal(1, 0.2), θ) + 0.7 * pdf(Normal(2, 0.3), θ))/exp(log_C)
	log_p(θ, log_C) = log(p(θ, log_C))
	
	pl1 = plot(θ, p.(θ, log_C), ylims = (0, 2), legend=nothing, title="p(θ) / C")
	pl2 = plot(θ, log_p.(θ, log_C), ylims = (-15, 2), legend=nothing, title="log (p(θ) / C)")
	
	plot(pl1, pl2, layout = (1, 2), legend = false, size =(800, 200))
end

# ╔═╡ 1d8dec13-1649-49cb-9b2f-f68a67c82daf
md""" ``\log C = `` **$(log_C)**""" 

# ╔═╡ 6ca88b96-ad19-474b-955f-5583c54fad2c


# ╔═╡ 2724e0db-5c07-4b66-8370-19e44e72a6f5
md"""
## What is the score?
- Let ``q(\boldsymbol{\theta})`` be a smooth density with ``\boldsymbol{\theta} \in \Theta``
> Score: $\boldsymbol{s}_q(\boldsymbol{\theta}) = \nabla_\boldsymbol{\theta} \log q(\boldsymbol{\theta})$
- ``\Rightarrow \nabla_\boldsymbol{\theta} \log (p(\boldsymbol{\theta}) /C) = \nabla_\boldsymbol{\theta} \log p(\boldsymbol{\theta}) - \nabla_\boldsymbol{\theta} \log C = \nabla_\boldsymbol{\theta} \log p(\boldsymbol{\theta}) = \boldsymbol{s}_p(\boldsymbol{\theta})``

"""

# ╔═╡ f6b9bce6-886f-4120-b6f4-f49c72d80c7e
@bind log_C2 Slider(-0.25:0.05:0.5, default=0)

# ╔═╡ 71a8b19f-7b77-483e-bced-3c207ed38b20
begin
	θ2 = 0:0.02:3;
	
	p1(θ, log_C) = (0.3 * pdf(Normal(1, 0.2), θ) + 0.7 * pdf(Normal(2, 0.3), θ))/exp(log_C)
	log_p1(θ, log_C) = log(p1(θ, log_C))
	
	p3 = plot(θ2, ForwardDiff.derivative.(θ -> p1(θ, log_C2), θ), ylims = (-2, 2), legend=nothing, title="∇p(θ) / C ")
		
	p4 = plot(θ2, ForwardDiff.derivative.(θ -> log_p1(θ, log_C2), θ), ylims = (-15, 15), legend=nothing, title="∇log (p(θ) / C)")
		
	plot(p3, p4, layout = (1, 2), legend = false, size = (800, 200))

end

# ╔═╡ 4b63c782-bf37-408e-a988-08672561ef12
md"""``\log C`` = $(log_C2)"""

# ╔═╡ 78a1a674-8e6b-4439-a889-63334c6bb38c
md"""
## Minibatch score

- For i.i.d. observations, i.e., ``p(X|\;\boldsymbol{\theta}) = \prod^n_{i=1}p(x_i|\; \boldsymbol{\theta}):`` 
- ``\nabla_\boldsymbol{\theta} \log p(\boldsymbol{\theta}) = \nabla_\boldsymbol{\theta} \log p_0(\boldsymbol{\theta}) + \sum^n_{i=1} \nabla_\boldsymbol{\theta}\log p(x_i|\; \boldsymbol{\theta})``
- for which the minibatch score, i.e., ``\nabla_\boldsymbol{\theta} \log p_0(\boldsymbol{\theta}) + \frac{n}{\vert \Omega \vert}\sum_{x \in \Omega} \nabla_\boldsymbol{\theta}\log p(x|\; \boldsymbol{\theta})`` is an **unbiased** estimator
"""

# ╔═╡ 771a73ea-c16f-4f30-a979-726e2794d236
md"""
## Basic Idea

- If $q$ is a smooth density and $\nabla_\boldsymbol{\theta} \log q(\boldsymbol{\theta}) = \nabla_\boldsymbol{\theta} \log p(\boldsymbol{\theta})\quad \forall \boldsymbol{\theta} \in \Theta$
- ``\Rightarrow q = p``
- Therefore we represent $q$ as an empirical distribution consisting of $\boldsymbol{\theta}_1,\dots, \boldsymbol{\theta}_m$ particles
- and update these particles locations with a smooth transformation $T$ trying to match the scores
- ``\Rightarrow`` easy to evaluate ``\mathbb{E}_{\boldsymbol{\theta} \sim q} g(\boldsymbol{\theta})`` for a suitable function ``g`` 
"""

# ╔═╡ a04656c9-f510-441e-902c-f1c56f4fd287
md"""
## Comparing densities based on their scores
"""

# ╔═╡ 4324e812-05c6-487d-9c0c-cc5694c6c83c
md"""``\mu_q`` $(@bind μq Slider(1:0.05:2, default=0)) ``\quad \sigma_q`` $(@bind σq Slider(0.2:0.005:0.3, default=0.2))"""


# ╔═╡ 5e73d3a6-22b2-4765-8e5e-23c22596edca
TwoColumn(md"""
- Let ``\boldsymbol{\delta}_{p,q}(\boldsymbol{\theta}) = \nabla_\boldsymbol{\theta} \log p(\boldsymbol{\theta}) - \nabla_\boldsymbol{\theta} \log q(\boldsymbol{\theta})``
- First idea: ``\mathbb{E}_{\boldsymbol{\theta} \sim q} \boldsymbol{\delta}_{ p,q}(\boldsymbol{\theta})^\top \boldsymbol{\delta}_{ p,q}(\boldsymbol{\theta})``
- Problem: We do not know ``\nabla_\boldsymbol{\theta} \log q(\boldsymbol{\theta})``
""",
begin
	Q = Normal(μq, σq)
	P = Normal(2, 0.3)
	
	θs = 0:0.02:3

	plot(θs, pdf.(Q, θs), label="q(θ)")
	p5 = plot!(θs, pdf.(P, θs), label="p(θ)")
	p6 = plot(θs, pdf.(Q, θs) .* (ForwardDiff.derivative.(θ -> logpdf(P, θ), θs) .-  ForwardDiff.derivative.(θ -> logpdf(Q, θ), θs)).^2, label="q(θ)δ(θ)²")
	plot(p5, p6, layout = (2, 1), size = (300, 250))
end
)

# ╔═╡ e33bbc20-1f70-4eef-85a3-4c1edee5f7df
begin
	Random.seed!(1)
	qs = rand(Q, 100)
	S = round(mean((ForwardDiff.derivative.(θ -> logpdf(P, θ), qs) .-  ForwardDiff.derivative.(θ -> logpdf(Q, θ), qs)).^2), digits = 3)
	md"""
	``\mathbb{E}_{\boldsymbol{\theta} \sim q} \boldsymbol{\delta}_{p,q}(\boldsymbol{\theta})^\top \boldsymbol{\delta}_{p,q}(\boldsymbol{\theta}) \approx`` $(S)
	"""
end

# ╔═╡ c3b9e518-3fd9-4d5e-9be5-955c46150622
md"""
## Stein gradient ``\nabla_\boldsymbol{\theta} \log q(\boldsymbol{\theta})``

- Observe that for any smooth function ``\phi:\boldsymbol{\theta} \rightarrow \mathbb{R}: ``
> $\mathbb{E}_{\boldsymbol{\theta}\sim q}\nabla_\boldsymbol{\theta} \log q(\boldsymbol{\theta}) \phi(\boldsymbol{\theta}) = \int_\boldsymbol{\theta} q(\boldsymbol{\theta})\frac{\nabla_\boldsymbol{\theta} q(\boldsymbol{\theta})}{q(\boldsymbol{\theta})} \phi(\boldsymbol{\theta})\mathrm{d}\boldsymbol{\theta} = q(\boldsymbol{\theta})\phi(\boldsymbol{\theta})\vert_{\partial\boldsymbol{\theta}} - \underbrace{\int_\boldsymbol{\theta} q(\boldsymbol{\theta}) \nabla_\boldsymbol{\theta} \phi(\boldsymbol{\theta})\mathrm{d}\boldsymbol{\theta}}_{=\mathbb{E}_{\boldsymbol{\theta}\sim q}\nabla_\boldsymbol{\theta} \phi(\boldsymbol{\theta})}$
- A function $\phi$ is said to be in the Stein class of $q$ iff $q(\boldsymbol{\theta})\phi(\boldsymbol{\theta})\vert_{\partial\boldsymbol{\theta}} = 0$
- For example for a positive definite kernel $k(\cdot, \cdot)$ and a fixed $\boldsymbol{\theta}': k(\cdot, \boldsymbol{\theta}')$ is in general in the Stein class of $q$ if $\boldsymbol{\theta} = \mathbb{R}^d$
- Stein's operator: $\mathcal{A}_q\phi(\boldsymbol{\theta}) = \boldsymbol{s}_q(\boldsymbol{\theta})\phi(\boldsymbol{\theta}) + \nabla_\boldsymbol{\theta}\phi(\boldsymbol{\theta})$; if $\phi$ is in the Stein class of $q:$ $\mathbb{E}_{\boldsymbol{\theta}\sim q}\mathcal{A}_q \phi = 0$
- For ``\boldsymbol{\phi}: \boldsymbol{\theta} \rightarrow \mathbb{R}^{d'},\quad \mathcal{A}_q\boldsymbol{\phi}(\boldsymbol{\theta}) = \boldsymbol{s}_q(\boldsymbol{\theta})\boldsymbol{\phi}(\boldsymbol{\theta})^\top + \nabla_\boldsymbol{\theta}\boldsymbol{\phi}(\boldsymbol{\theta})``
"""

# ╔═╡ d086cfb1-a4ff-41e7-94cb-882b9d28b182
md"""
## Kernelized Stein Divergence

- For a positive definite kernel ``k(\boldsymbol{\theta}, \boldsymbol{\theta}')``
> Kernelized Stein divergence (KSD): ``\mathbb{S}(q, p) = \mathbb{E}_{\boldsymbol{\theta}, \boldsymbol{\theta}' \sim q}\boldsymbol{\delta}_{ p,q}(\boldsymbol{\theta})^\top k(\boldsymbol{\theta}, \boldsymbol{\theta}')\boldsymbol{\delta}_{ p,q}(\boldsymbol{\theta}') \geq 0`` and ``\mathbb{S}(q, p) = 0`` only if ``p = q`` (under mild conditions)

"""

# ╔═╡ 43ff918f-5c39-45ea-b7c9-6f59e56b528d
md"""``\mu_q`` $(@bind μq2 Slider(1:0.05:2, default=0)) ``\quad \sigma_q`` $(@bind σq2 Slider(0.2:0.005:0.3, default=0.2))"""

# ╔═╡ 859434b4-c1e8-4d03-b88a-ec19164fc92d
begin
	Q2 = Normal(μq2, σq2)
	P2 = Normal(2, 0.3)

	θs2 = 0:0.01:3
    θw = 0:0.07:3

	k = GibbsKernel(;lengthscale=x -> 2.0)

	s_q2(θ) = ForwardDiff.derivative(θ -> logpdf(Q2, θ), θ) 
	s_p2(θ) = ForwardDiff.derivative(θ -> logpdf(P2, θ), θ)
	#∇_θ1_k(θ1, θ2) =
	
	plot(θs2, pdf.(Q2, θs2), label="q(θ)")
	p7 = plot!(θs2, pdf.(P2, θs2), label="p(θ| X)")
	p8 = wireframe(θw, θw, (θ1,θ2) -> pdf(Q2, θ1)*pdf(Q2, θ2)*(s_p2(θ1) .-  s_q2(θ1)) * k(θ1, θ2) * (s_p2(θ2) .-  s_q2(θ2)))
	
	plot(p7, p8, layout = (1, 2), size = (800, 200))
end

# ╔═╡ 7cc345fb-a383-4eac-8691-0581c4208b49
md"""
## Kernelized Stein Divergence 

Let ``\mathcal{H}`` be the RKHS induced by a positive definite kernel ``k``

Applying
1) the reproducing property of $k: k(\boldsymbol{\theta}, \boldsymbol{\theta}') = \langle k(\boldsymbol{\theta}, \cdot), k(\boldsymbol{\theta}', \cdot)\rangle$
2) ``\mathbb{E}_{\boldsymbol{\theta}\sim q}\mathcal{A}_p k(\boldsymbol{\theta}, \cdot) = \mathbb{E}_{\boldsymbol{\theta}\sim q}\left[\mathcal{A}_p k(\boldsymbol{\theta}, \cdot) - \mathcal{A}_q k(\boldsymbol{\theta}, \cdot)\right] = \mathbb{E}_{\boldsymbol{\theta}\sim q} (\boldsymbol{s}_p(\boldsymbol{\theta}) - \boldsymbol{s}_q(\boldsymbol{\theta}))k(\boldsymbol{\theta}, \cdot)``
to ``\mathbb{S}(q,p)`` yields
> ``\mathbb{S}(q,p) = \Vert\boldsymbol{\phi}^*(\boldsymbol{\theta})\Vert^2_{\mathcal{H}^d}`` where ``\boldsymbol{\phi}^*(\boldsymbol{\theta}) = \mathbb{E}_{\boldsymbol{\theta}'\sim q}\mathcal{A}_p k(\boldsymbol{\theta}', \boldsymbol{\theta})`` 
"""

# ╔═╡ af9b5d4e-0543-4e56-aa50-7ac3443e4899
md"""
## Kernelized Stein Divergence 

> ``\mathbb{S}(q,p) = \Vert\boldsymbol{\phi}^*(\boldsymbol{\theta})\Vert^2_{\mathcal{H}^d}`` where ``\boldsymbol{\phi}^*(\boldsymbol{\theta}) = \mathbb{E}_{\boldsymbol{\theta}'\sim q}\mathcal{A}_p k(\boldsymbol{\theta}', \boldsymbol{\theta})`` 
"""

# ╔═╡ bbe477a6-9609-42c3-8006-ef6b2fe48bdd

md"""angle $(@bind τ Slider(0:pi/8:2*pi, default=0))"""


# ╔═╡ 0a7e747a-1240-4254-9f21-46a4660fe6df
TwoColumn(
	md"""
	⇒ ``\sqrt{\mathbb{S}(q,p)} = \max_{\boldsymbol{\phi} \in \mathcal{H}^d}\left\{\langle\boldsymbol{\phi}^*, \boldsymbol{\phi} \rangle| \; \Vert \phi\Vert_{\mathcal{H}^d} \leq 1\right\}`` where the maximum is achieved when $\boldsymbol{\phi}(\boldsymbol{\theta}) = \frac{\boldsymbol{\phi}^*(\boldsymbol{\theta})}{\Vert\boldsymbol{\phi}^*(\boldsymbol{\theta})\Vert_{\mathcal{H}^d}}$
	""",
begin
	xₜ(t) = sin(t)
	yₜ(t) = cos(t)

	κ = ([-sqrt(2), sqrt(2)] ⋅ [cos(τ), sin(τ)] / 2)
	
	plot(xₜ, yₜ, 0, 2π, leg=true, size=(300,300), label="H")
	plot!([0,sqrt(2)],[0, -sqrt(2)],ls=:dash, color=:grey, linewidth=2,label="")
	plot!([0,-sqrt(2)],[0, sqrt(2)],arrow=true,color=:black,linewidth=2,label="ϕ*"),
	plot!([0, cos(τ)],[0, sin(τ)],arrow=true,color=:red,linewidth=2,label="ϕ")
	plot!([0,-sqrt(2)] .* κ,[0, sqrt(2)] .* κ,color=:red, ls=:dash,linewidth=2,label="<ϕ*,ϕ>", marker=:vline, size = (260,260))
end
)

# ╔═╡ c64c949e-09ed-4f11-872d-f34ba4ed3101
md"""``\langle\boldsymbol{\phi}^*, \boldsymbol{\phi} \rangle`` = $(round([-sqrt(2), sqrt(2)] ⋅ [cos(τ), sin(τ)]/2, digits=3)) ``\sqrt{\mathbb{S}}``
"""

# ╔═╡ ce24ac30-b7d3-4827-b9fb-2aadd2933dc7
md"""
## Kernelized Stein Divergence 

- Also we can show that ``\langle\boldsymbol{\phi}^*, \boldsymbol{\phi} \rangle = \mathrm{trace}({\mathbb{E}_{\boldsymbol{\theta} \sim q}}\mathcal{A}_p\boldsymbol{\phi}) = \mathbb{E}_{\boldsymbol{\theta} \sim q}[\underbrace{(\boldsymbol{s}_p(\boldsymbol{\theta}) - \boldsymbol{s}_q(\boldsymbol{\theta})}_{=\boldsymbol{\delta}_{p,q}(\boldsymbol{\theta})})^\top\boldsymbol{\phi}(\boldsymbol{\theta}) ]``
- Let $\mathcal{F}_q$ be a function space of square integrable functions projecting from $\mathbb{R}^d$ to $\mathbb{R}^d$ with $\langle \boldsymbol{f},\boldsymbol{g}\rangle_{\mathcal{F}_q} = \mathbb{E}_{\boldsymbol{\theta}\sim q}\boldsymbol{f}(\boldsymbol{\theta})^\top \boldsymbol{g}(\boldsymbol{\theta})$ where ``\boldsymbol{f}, \boldsymbol{g} \in \mathcal{F}_q`` 
- Then ``\mathcal{H}^d \subset \mathcal{F}_q`` and
> $\sqrt{\mathbb{S}(q,p)} = \max_{\boldsymbol{\phi} \in \mathcal{H}^d}\left\{\mathrm{trace}({\mathbb{E}_{\boldsymbol{\theta} \sim q}}\mathcal{A}_p\boldsymbol{\phi})| \; \Vert \phi\Vert_{\mathcal{H}^d} \leq 1\right\} = \max_{\boldsymbol{\phi} \in \mathcal{H}^d}\left\{\langle \boldsymbol{\delta}_{p,q},\boldsymbol{\phi}\rangle_{\mathcal{F}_q}| \; \Vert \phi\Vert_{\mathcal{H}^d} \leq 1\right\}$
"""

# ╔═╡ 6bed22b8-e369-4fc9-8fac-d1cd26ddaa40
md"""
## Kernelized Stein Divergence 

> ``\sqrt{\mathbb{S}(q,p)} = \max_{\boldsymbol{\phi} \in \mathcal{H}^d}\left\{\langle \boldsymbol{\delta}_{p,q},\boldsymbol{\phi}\rangle_{\mathcal{F}_q}| \; \Vert \phi\Vert_{\mathcal{H}^d} \leq 1\right\}``
"""

# ╔═╡ ac29dae1-2f4e-48ed-b960-d9b34f32ce6d
TwoColumn(
	md"""``\Rightarrow \boldsymbol{\phi}^*`` is the orthogonal projection of ``\boldsymbol{\delta}_{p,q}`` onto ``\mathcal{H}^d`` w.r.t. ``\mathcal{F}_q``""",
	begin
		X(r,phi) = r * sin(phi)
		Y(r,phi) = r * cos(phi)
		Z(r,phi) = 0
		
		phis   = range(0, stop=2*pi, length=50)
		
		xs = [X(r, phi) for r in range(0,1, length=50), phi in phis] 
		ys = [Y(r, phi) for r in range(0,1, length=50), phi in phis]
		zs = [Z(r, phi) for r in range(0,1, length=50), phi in phis]
		
		surface(xs, ys, zs, color=:blue, legend = false, size=(300,300))
		plot!([0,-sqrt(1.5)], [0,-sqrt(1.5)], [0,sqrt(1.5)], color=:black, arrow=true)
		plot!([0,-sqrt(1.5)], [0,-sqrt(1.5)], [0,0], color=:red, arrow=true)
		plot!([-sqrt(1.5),-sqrt(1.5)], [-sqrt(1.5),-sqrt(1.5)], [0,sqrt(1.5)], color=:black, ls=:dash)

	end
)

# ╔═╡ 67dce6de-8ba7-4db9-9f64-1d1328d0d448
md"""
## Variational Inference 

- For a diffeomorhpism ``T:\mathbb{R}^d \rightarrow \mathbb{R}^d``, ``\boldsymbol{\theta} \sim q`` we get that $T(\boldsymbol{\theta}) \sim \underbrace{q(T^{-1}(\boldsymbol{\theta}))\vert\det\nabla_{\boldsymbol{\theta}}T^{-1}(\boldsymbol{\theta})\vert}_{=q_{[T]}}$
- Let ``T(\boldsymbol{\theta}) = \boldsymbol{\theta} + \epsilon\boldsymbol{\phi}(\boldsymbol{\theta})`` with a smooth bounded pertubation function ``\boldsymbol{\phi}:\mathbb{R}^d\rightarrow\mathbb{R}^d``
- If ``\vert\epsilon\vert`` is sufficiently small (close to identity function), ``T`` becomes a diffeomorphism
"""

# ╔═╡ ed3579e2-5075-4c22-93e3-9a92e7e934aa

md"""``\epsilon`` $(@bind ϵ Slider(0:0.1:1, default=1))
"""

# ╔═╡ 12e16145-2853-4793-9d43-0f4ead1b4127
begin
	pert(x) = exp(-(x-1)^2/0.05) - exp(-(x-2)^2/0.05)
	pl_p = plot(0:0.01:3, pert, label="ϕ")
	pl_T = plot(0:0.01:3, x -> x + ϵ*pert(x), legend=:bottom, label="θ + " * string(ϵ) * "⋅ϕ(θ)")
	plot(pl_p, pl_T, layout=(1,2), size=(800,250))
end

# ╔═╡ dca9526c-74d4-4e60-ace0-dab5d42b73fe
md"""
## The KL divergence

- (Famous) distance measure between smooth densities, often used in VI
- ``\mathrm{KL}(q,p) = \int q(\boldsymbol{\theta}) \log\left(\frac{q(\boldsymbol{\theta})}{p(\boldsymbol{\theta})}\right)\mathrm{d}\boldsymbol{\theta}``
- $\begin{aligned}\mathrm{KL}(q_{[T^{-1}]},p_{[T^{-1}]}) &= \int q(T(\boldsymbol{\theta})) \log\left(\frac{q(T(\boldsymbol{\theta}))\vert\det\nabla_\boldsymbol{\theta}T\vert}{p(T(\boldsymbol{\theta}))\vert\det\nabla_\boldsymbol{\theta}T\vert}\right)\vert\det\nabla_\boldsymbol{\theta}T\vert\mathrm{d}\boldsymbol{\theta} \\&= \int q(\tilde{\boldsymbol{\theta}}) \log\left(\frac{q(\tilde{\boldsymbol{\theta}})}{p(\tilde{\boldsymbol{\theta}})}\right)\mathrm{d}\tilde{\boldsymbol{\theta}} = \mathrm{KL}(q,p)\end{aligned}$
- For ``T(\boldsymbol{\theta}) = \boldsymbol{\theta} + \epsilon\boldsymbol{\phi}`` using ``\mathrm{KL}(q_{[T]},p) = \mathrm{KL}(q_{[T^{-1}\circ T]},p_{[T^{-1}]}) = \mathrm{KL}(q,p_{[T^{-1}]})`` and ``\nabla_\epsilon\det(A(\epsilon)) = \det(A(\epsilon))\mathrm{trace}(A(\epsilon)^{-1}\nabla_\epsilon A(\epsilon))`` we get 
> ``\nabla_\epsilon\mathrm{KL}(q_{[T]},p)\vert_{\epsilon=0} = -\mathrm{trace}({\mathbb{E}_{\boldsymbol{\theta} \sim q}}\mathcal{A}_p\boldsymbol{\phi})``
"""

# ╔═╡ 3ad6dc3b-447d-408a-a702-80c187dec0c9
md"""``\Rightarrow \boldsymbol{\phi}^*`` gives the steepest descent on the $\mathrm{KL}$ divergence in zero-centered balls of $\mathcal{H}^d$
"""

# ╔═╡ 4ad573dc-b9ad-4f50-b3a0-a7436e064f02
md"""
## The algorithm

1) Start with particles ``\boldsymbol{\theta}^{[0]}_1,\dots,\boldsymbol{\theta}^{[0]}_m \sim q_0``
2) Repeat until convergence:
> $\boldsymbol{\theta}^{[t+1]}_i = \boldsymbol{\theta}^{[t]}_i + \epsilon\cdot\left( \sum^m_{j=1}\underbrace{\boldsymbol{s}_p(\boldsymbol{\theta}^{[t]}_j)k(\boldsymbol{\theta}^{[t]}_i,\boldsymbol{\theta}^{[t]}_j)}_{\#1}+\underbrace{\nabla_{\boldsymbol{\theta}^{[t]}_j}k(\boldsymbol{\theta}^{[t]}_i,\boldsymbol{\theta}^{[t]}_j)}_{\#2}\right)$
"""

# ╔═╡ a4f311bb-5ab7-44bc-8f93-d1ef497c5222
md"""
- #1: force driving the particles to high probability regions
- #2: repulsive force between particles
"""

# ╔═╡ bbde8540-ad4e-407a-a954-113fab7158a9
begin
	P_mv1 = MvNormal([2,0], [0.5 -0.1; -0.1 0.5])
	P_mv2 = MvNormal([0,2], [0.5 0.2; 0.2 0.5])

	Q_mv = MvNormal([-1, -1], [0.2 0; 0 0.2])
	
	c1 = 0.3
	c2 = 0.7
	
	p_mv(x) = c1 * pdf(P_mv1, x) + c2 * pdf(P_mv2, x)
	log_p_mv(x) = log(p_mv(x))
	s_mv(x) = ForwardDiff.gradient(log_p_mv, x)

	k1 = GibbsKernel(;lengthscale=x -> 1.0)
	d_k(k, x_1, x_2) = ForwardDiff.gradient(x -> k(x, x_2), x_1)

	n = 50
	ε = 0.02
	
	Random.seed!(1)
	particles = rand(Q_mv, n)
	dparticles = zeros(size(particles)...)
	
	md"""
	## Toy example
	"""
end

# ╔═╡ 949a7d08-d06b-4a14-8cf8-8383c3a47417
md"$(@bind svgd Button(\"SVGD step\")) $(@bind reset Button(\"reset\")) force driving to high probability $(@bind sp CheckBox(default=true)) repulsive force $(@bind rep CheckBox(default=true))"

# ╔═╡ 87e3f12c-0345-44cf-a63b-e0347ee00e32
# grid initialization for gradient field

begin
	meshgrid(x, y) = (repeat(x, outer=length(y)), repeat(y, inner=length(x)))
	mx, my = meshgrid(-1.8:0.6221:3.8, -1.8:0.6221:3.8)
	M = hcat(mx, my)'
	dM = zeros(size(M)...)
	m = size(M, 2)
	md""
end

# ╔═╡ f00bb6bb-d3ec-4a75-b09a-acf6669932b5
begin
	svgd

	# Update particles
	
	for i in 1:n
		for j in 1:n
			if sp
				dparticles[:, i] += s_mv(particles[:, j]) * k1(particles[:, i], particles[:, j]) 
			end
			if rep
				dparticles[:, i] += d_k(k1, particles[:, j], particles[:, i])
			end
		end
	end

	particles .+= ε .* dparticles
	dparticles .= 0

	# Compute gradient field
	dM .= 0
	for i in 1:m
		for j in 1:n
			if sp
				dM[:, i] += ε .* s_mv(particles[:, j]) * k1(M[:, i], particles[:, j]) 
			end
			if rep
				dM[:, i] += ε .* d_k(k1, particles[:, j], M[:, i])
			end
		end
	end	

	c = 1
	
	md""
end

# ╔═╡ 2e330d55-9f28-40f9-bb61-91f75f093721
begin 
	reset

	Random.seed!(1)
	particles .= rand(Q_mv, n)
	dparticles .= 0

	# compute initial gradient field
	dM .= 0
	for i in 1:m
		for j in 1:n
			if sp
				dM[:, i] += ε .* s_mv(particles[:, j]) * k1(M[:, i], particles[:, j]) 
			end
			if rep
				dM[:, i] += ε .* d_k(k1, particles[:, j], M[:, i])
			end
		end
	end	
	
	r = 0
	md""
end

# ╔═╡ 84ac60c1-d84c-4b22-a393-f973adc7dcce
begin
	c, r
	x = -2:0.1:4
	contour(x, x, (x,y) -> p_mv([x, y]), size = (800,280))
	toy_pl1 = scatter!(particles[1,:], particles[2,:], label = "θ")
	contour(x, x, (x,y) -> p_mv([x, y]), size = (800,280))
	toy_pl2 = quiver!(mx, my, quiver=(dM[1,:], dM[2,:]))
	plot(toy_pl1, toy_pl2, layout=(1,2))
end

# ╔═╡ 95e1a562-5360-11eb-19d4-a72985938bd7
md"## "

# ╔═╡ c2c900fa-5360-11eb-3597-e9db443f74c1
md"## "

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
KernelFunctions = "ec8451be-7e33-11e9-00cf-bbf324bd1392"
LinearAlgebra = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
Distributions = "~0.25.52"
ForwardDiff = "~0.10.25"
KernelFunctions = "~0.10.33"
Plots = "~1.27.2"
PlutoUI = "~0.7.37"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

[[AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "af92965fb30777147966f58acb05da51c5616b5f"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.3"

[[ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "9950387274246d08af38f6eef8cb5480862a435f"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.14.0"

[[ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "bf98fa45a0a4cee295de98d4c1462be26345b9a1"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.2"

[[ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "12fc73e5e0af68ad3137b886e3f7c1eacfca2640"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.17.1"

[[ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "96b0bc6c52df76506efc8a441c6cf1adcb1babc4"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.42.0"

[[CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[CompositionsBase]]
git-tree-sha1 = "455419f7e328a1a2493cabc6428d79e951349769"
uuid = "a33af91c-f02d-484b-be07-31d278c5ca2b"
version = "0.1.1"

[[Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "3daef5523dd2e769dad2365274f760ff5f282c7d"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.11"

[[DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[DiffResults]]
deps = ["StaticArrays"]
git-tree-sha1 = "c18e98cba888c6c25d1c3b048e4b3380ca956805"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.0.3"

[[DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "dd933c4ef7b4c270aacd4eb88fa64c147492acf0"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.10.0"

[[Distances]]
deps = ["LinearAlgebra", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "3258d0659f812acde79e8a74b11f17ac06d0ca04"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.7"

[[Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "c43e992f186abaf9965cc45e372f4693b7754b22"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.52"

[[DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ae13fcbc7ab8f16b0856729b050ef0c446aa3492"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.4.4+0"

[[FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "246621d23d1f43e3b9c368bf3b72b2331a27c286"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.13.2"

[[FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "1bd6fc0c344fc0cbee1f42f8d2e7ec8253dda2d2"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.25"

[[FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[Functors]]
git-tree-sha1 = "223fffa49ca0ff9ce4f875be001ffe173b2b7de4"
uuid = "d9f16b24-f501-4c13-a1f2-28368ffc5196"
version = "0.2.8"

[[GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "51d2dfe8e590fbd74e7a842cf6d13d8a2f45dc01"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.6+0"

[[GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "RelocatableFolders", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "9f836fb62492f4b0f0d3b06f55983f2704ed0883"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.64.0"

[[GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "a6c850d77ad5118ad3be4bd188919ce97fffac47"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.64.0+0"

[[GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "83ea630384a13fc4f002b77690bc0afeb4255ac9"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.2"

[[Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "a32d672ac2c967f3deb8a81d828afc739c838a06"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+2"

[[Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "0fa77022fe4b511826b39c894c90daf5fce3334a"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.17"

[[HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[HypergeometricFunctions]]
deps = ["DualNumbers", "LinearAlgebra", "SpecialFunctions", "Test"]
git-tree-sha1 = "65e4589030ef3c44d3b90bdc5aac462b4bb05567"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.8"

[[Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[HypertextLiteral]]
git-tree-sha1 = "2b078b5a615c6c0396c77810d92ee8c6f470d238"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.3"

[[IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[IniFile]]
git-tree-sha1 = "f550e6e32074c939295eb5ea6de31849ac2c9625"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.1"

[[InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "91b5dcf362c5add98049e6c29ee756910b03051d"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.3"

[[IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b53380851c6e6664204efb2e62cd24fa5c47e4ba"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.2+0"

[[KernelFunctions]]
deps = ["ChainRulesCore", "Compat", "CompositionsBase", "Distances", "FillArrays", "Functors", "IrrationalConstants", "LinearAlgebra", "LogExpFunctions", "Random", "Requires", "SpecialFunctions", "StatsBase", "TensorCore", "Test", "ZygoteRules"]
git-tree-sha1 = "69ab57d45a70ae2bbd7d47908563096d41327271"
uuid = "ec8451be-7e33-11e9-00cf-bbf324bd1392"
version = "0.10.33"

[[LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "4f00cc36fede3c04b8acf9b2e2763decfdcecfa6"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.13"

[[LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "7739f837d6447403596a75d19ed01fd08d6f56bf"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.3.0+3"

[[Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "c9551dd26e31ab17b86cbd00c2ede019c08758eb"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+1"

[[Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[LinearAlgebra]]
deps = ["Libdl"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "58f25e56b706f95125dcb796f39e1fb01d913a71"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.10"

[[Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[NaNMath]]
git-tree-sha1 = "b086b7ea07f8e38cf122f5016af580881ac914fe"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.7"

[[NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ab05aa4cc89736e95915b01e7279e61b1bfe33b8"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.14+0"

[[OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "e8185b83b9fc56eb6456200e873ce598ebc7f262"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.7"

[[Parsers]]
deps = ["Dates"]
git-tree-sha1 = "85b5da0fa43588c75bb1ff986493443f821c70b7"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.2.3"

[[Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "bb16469fd5224100e422f0b027d26c5a25de1200"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.2.0"

[[Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun", "Unzip"]
git-tree-sha1 = "90021b03a38f1ae9dbd7bf4dc5e3dcb7676d302c"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.27.2"

[[PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "bf0a1121af131d9974241ba53f601211e9303a9e"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.37"

[[Preferences]]
deps = ["TOML"]
git-tree-sha1 = "d3538e7f8a790dc8903519090857ef8e1283eecd"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.5"

[[Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "ad368663a5e20dbb8d6dc2fddeefe4dae0781ae8"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+0"

[[QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "78aadffb3efd2155af139781b8a8df1ef279ea39"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.2"

[[REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[Random]]
deps = ["Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[RecipesBase]]
git-tree-sha1 = "6bf3f380ff52ce0832ddd3a2a7b9538ed1bcca7d"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.2.1"

[[RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "dc1e451e15d90347a7decc4221842a022b011714"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.5.2"

[[Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "cdbd3b1338c72ce29d9584fdbe9e9b70eeb5adca"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "0.1.3"

[[Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "5ba658aeecaaf96923dce0da9e703bd1fe7666f9"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.1.4"

[[StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "4f6ec5d99a28e1a749559ef7dd518663c5eca3d5"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.4.3"

[[Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "c3d8ba7f3fa0625b062b82853a7d5229cb728b6b"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.2.1"

[[StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "8977b17906b0a1cc74ab2e3a05faa16cf08a8291"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.16"

[[StatsFuns]]
deps = ["ChainRulesCore", "HypergeometricFunctions", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "25405d7016a47cf2bd6cd91e66f4de437fd54a07"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.16"

[[StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "57617b34fa34f91d536eb265df67c2d4519b8b98"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.5"

[[SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "5ce79ce186cc678bbb5c5681ca3379d1ddae11a1"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.7.0"

[[Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[Unzip]]
git-tree-sha1 = "34db80951901073501137bdbc3d5a8e7bbd06670"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.1.2"

[[Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "3e61f0b86f90dacb0bc0e73a0c5a83f6a8636e23"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.19.0+0"

[[Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4528479aa01ee1b3b4cd0e6faef0e04cf16466da"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.25.0+0"

[[XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e45044cd873ded54b6a5bac0eb5c971392cf1927"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.2+0"

[[ZygoteRules]]
deps = ["MacroTools"]
git-tree-sha1 = "8c1a8e4dfacb1fd631745552c8db35d0deb09ea0"
uuid = "700de1a5-db45-46bc-99cf-38207098b444"
version = "0.2.2"

[[libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╟─9402df7c-4c3d-11eb-0f04-670058576045
# ╟─99fb7628-502a-11eb-1d23-7d3a143cd5d3
# ╟─032c42f2-5103-11eb-0dce-e7ec59924648
# ╟─0bb068de-512d-11eb-14e3-8f3de757910d
# ╟─827fbc3a-512d-11eb-209e-cd74ddc17bae
# ╟─6382a73e-5102-11eb-1cfb-f192df63435a
# ╟─053ab307-de40-48d6-9687-0bd9a3d88e3b
# ╟─6118fcf2-5103-11eb-0adc-1749ac4663a3
# ╟─abf59f44-fecf-448f-a004-9720e04a4c0e
# ╟─1d8dec13-1649-49cb-9b2f-f68a67c82daf
# ╟─0e1e4b5c-e05c-4fe6-9e69-c2032dd5837b
# ╟─6ca88b96-ad19-474b-955f-5583c54fad2c
# ╟─2724e0db-5c07-4b66-8370-19e44e72a6f5
# ╟─71a8b19f-7b77-483e-bced-3c207ed38b20
# ╟─4b63c782-bf37-408e-a988-08672561ef12
# ╟─f6b9bce6-886f-4120-b6f4-f49c72d80c7e
# ╟─78a1a674-8e6b-4439-a889-63334c6bb38c
# ╟─771a73ea-c16f-4f30-a979-726e2794d236
# ╟─a04656c9-f510-441e-902c-f1c56f4fd287
# ╟─5e73d3a6-22b2-4765-8e5e-23c22596edca
# ╟─e33bbc20-1f70-4eef-85a3-4c1edee5f7df
# ╟─4324e812-05c6-487d-9c0c-cc5694c6c83c
# ╟─c3b9e518-3fd9-4d5e-9be5-955c46150622
# ╟─d086cfb1-a4ff-41e7-94cb-882b9d28b182
# ╟─859434b4-c1e8-4d03-b88a-ec19164fc92d
# ╟─43ff918f-5c39-45ea-b7c9-6f59e56b528d
# ╟─7cc345fb-a383-4eac-8691-0581c4208b49
# ╟─af9b5d4e-0543-4e56-aa50-7ac3443e4899
# ╟─0a7e747a-1240-4254-9f21-46a4660fe6df
# ╟─c64c949e-09ed-4f11-872d-f34ba4ed3101
# ╟─bbe477a6-9609-42c3-8006-ef6b2fe48bdd
# ╟─ce24ac30-b7d3-4827-b9fb-2aadd2933dc7
# ╟─6bed22b8-e369-4fc9-8fac-d1cd26ddaa40
# ╟─ac29dae1-2f4e-48ed-b960-d9b34f32ce6d
# ╟─67dce6de-8ba7-4db9-9f64-1d1328d0d448
# ╟─12e16145-2853-4793-9d43-0f4ead1b4127
# ╟─ed3579e2-5075-4c22-93e3-9a92e7e934aa
# ╟─dca9526c-74d4-4e60-ace0-dab5d42b73fe
# ╟─3ad6dc3b-447d-408a-a702-80c187dec0c9
# ╟─4ad573dc-b9ad-4f50-b3a0-a7436e064f02
# ╟─a4f311bb-5ab7-44bc-8f93-d1ef497c5222
# ╟─bbde8540-ad4e-407a-a954-113fab7158a9
# ╟─84ac60c1-d84c-4b22-a393-f973adc7dcce
# ╟─949a7d08-d06b-4a14-8cf8-8383c3a47417
# ╟─f00bb6bb-d3ec-4a75-b09a-acf6669932b5
# ╟─87e3f12c-0345-44cf-a63b-e0347ee00e32
# ╟─2e330d55-9f28-40f9-bb61-91f75f093721
# ╟─95e1a562-5360-11eb-19d4-a72985938bd7
# ╟─c2c900fa-5360-11eb-3597-e9db443f74c1
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
