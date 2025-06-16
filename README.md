# CloudCovFix.jl <img src="docs/src/assets/logo.png" alt="CloudCovFix Logo" width="100" align="right"/>

[![][docs-dev-img]][docs-dev-url]
[![][action-img]][action-url]
[![][codecov-img]][codecov-url]
[![][arxiv-img]][arxiv-url]

Pipeline for debiasing and improving error bar estimates for photometry on top of structured/filamentary background. The procedure first estimates the covariance matrix of the residuals from a previous photometric model and then computes corrections to the estimated flux and flux uncertainties.

## Installation

Currently development version only. Install directly from the GitHub

```julia
import Pkg
Pkg.add(url="https://github.com/andrew-saydjari/CloudCovFix.jl")
```

## Contributing and Questions

This is an actively maintained piece of software. [Filing an
issue](https://github.com/andrew-saydjari/CloudCovFix.jl/issues/new) to report a
bug or request a feature is extremely valuable in helping us prioritize what to work on, so don't hesitate.

<!-- URLS -->
[action-img]: https://github.com/andrew-saydjari/CloudCovFix.jl/workflows/Unit%20test/badge.svg
[action-url]: https://github.com/andrew-saydjari/CloudCovFix.jl/actions

[docs-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[docs-dev-url]: https://andrew-saydjari.github.io/CloudCovFix.jl/dev/

[codecov-img]: https://codecov.io/github/andrew-saydjari/CloudCovFix.jl/coverage.svg?branch=main
[codecov-url]: https://codecov.io/github/andrew-saydjari/CloudCovFix.jl?branch=main

[arxiv-img]: https://img.shields.io/badge/arXiv-2201.07246-00cc00.svg
[arxiv-url]: https://arxiv.org/abs/2201.07246
