# CloudCovErr.jl

[![GitHub](https://img.shields.io/badge/Code-GitHub-black.svg)](https://github.com/andrew-saydjari/CloudCovFix.jl)
[![Build Status](https://github.com/andrew-saydjari/CloudCovFix.jl/workflows/Unit%20test/badge.svg)](https://github.com/andrew-saydjari/CloudCovFix.jl/actions)
[![Coverage Status](https://codecov.io/github/andrew-saydjari/CloudCovFix.jl/coverage.svg?branch=main)](https://codecov.io/github/andrew-saydjari/CloudCovFix.jl?branch=main)

A [Julia](http://julialang.org) package for debiasing and improving error bar estimates for photometry on top of structured/filamentary background.

## Installation

Currently development version only. Install directly from the GitHub

```julia
import Pkg
Pkg.add(url="https://github.com/andrew-saydjari/CloudCovFix.jl")
```

## Usage

To start, load the `CloudCovErr.jl` package:

```julia
using CloudCovErr
```

For now, please refer to examples in the release paper and its accompanying Zenodo repository. An end-to-end demonstration of this code applied to the DECaPS2 survey begins with calling the `decaps2.jl` found in the original `CloudCovErr.jl` repository.

Use of individual functions is documented here in the API Reference page.

## Outputs

### Quality Flag

The `dnt:Int8` flag from **CloudCovErr** indicates the following:

| Value         | Bit         | Meaning     |
| ----------- | ----------- | ----------- |
| 0     | -     | No problems       |
| 1     | 0     | Few "good" pixels, used pixels beyond radial mask |
| 2     | 1     | Few "good" pixels, force outermost row/column of pixels "good" |
| 4     | 2     | [Not Used] |
| 8     | 3     | Any pixel in PSF model for a source is (even infinitesimally) negative |
| 16    | 4     | Min/Max PSF < -1e-3 |
| 32    | 5     | Min/Max PSF < -1e-1 |
| 64    | 6     | [Not Used] |

A more detailed description of the flag can be found in the release paper. Bit 0 is always thrown if Bit 1 is set since Bit 1 is a more severe fall back to solve the same problem.

## Table of Contents

```@contents
Pages = ["index.md","api.md","contrib.md"]
```
