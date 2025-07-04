# Contributing

Contributions to `CloudCovFix.jl` are welcome. The most likely direction for collaboration is a user trying to apply `CloudCovFix.jl` to a different photometric survey. In the function docstrings and release paper, we have tried to make clear how the code could be easily adapted and what functions would need new versions. This is basically just creating analogous files to `decaps2.jl` and `decam.jl` that can be found in the original `CloudCovErr.jl` repository. Feel free to make a imperfect PR or open up an issue with feature requests to discuss.

### Developer Wish List:
- save updated source model images and sky background models for each CCD
- implement flexible stationary kernel fitting (and compare performance to current pixelwise covariance)
