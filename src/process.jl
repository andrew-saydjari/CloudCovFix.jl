using StatsBase

export proc_continuous
export proc_discrete

"""
    proc_continuous(raw_image, mask_image; Np=33, widx=129, widy=widx, tilex=1, tiley=tilex, seed=2021, ftype::Int=32, ndraw=0) -> out_mean, out_draw

Process an image with a mask, replacing masked pixels with either a mean or draw from a distribution resembling the local pixel-pixel covariance structure in the image.

# Arguments:
- `raw_image`: A 2D array representing the input image.
- `mask_image`: A 2D array representing the mask.

# Keywords:
- `Np`: An optional integer specifying the number of pixels in a side (default: 33).
- `widx`: An optional integer specifying the width of the region used for training the local covariance in the x-direction (default: 129).
- `widy`: An optional integer specifying the width of the region used for training the local covariance in the y-direction (default: widx).
- `tilex`: An optional integer specifying the number of tiles in the x-direction for subdividing the image (default: 1).
- `tiley`: An optional integer specifying the number of tiles in the y-direction for subdividing the image (default: tilex).
- `seed`: An optional integer specifying the random number generator seed (default: 2021).
- `ftype`: An optional integer specifying the floating-point precision type (32 or 64) (default: 32).
- `ndraw`: An optional integer specifying the number of draws of samples from the statistical distribution of possible masked pixel values (default: 0).

# Returns
- If `ndraw` is 0, returns the debiased image as a 2D array.
- If `ndraw` is greater than 0, returns the debiased image as a 2D array and an array of `ndraw` draws.

# Examples
```julia
julia> raw_image = rand(100, 100)
julia> mask_image = rand(Bool, 100, 100)
julia> result = proc_continuous(raw_image, mask_image, Np=33, widx=129, seed=2021)
```
"""
function proc_continuous(raw_image,mask_image;Np=33,widx=129,widy=widx,tilex=1,tiley=tilex,seed=2021,ftype::Int=32,ndraw=0,sym::Bool=false)
    radNp = (Np-1)÷2
    if ftype == 32
        T = Float32
    else
        T = Float64
    end

    # renaming to match conventions
    ref_im = convert(Array{T}, raw_image)
    bmaskd = mask_image
    (sx0, sy0) = size(ref_im)
    
    cartIndx = findall(bmaskd)
    x_stars = map(x->x[1],cartIndx)
    y_stars = map(x->x[2],cartIndx)

    # Calculate distances from image center
    center_x = sx0 ÷ 2
    center_y = sy0 ÷ 2
    dist_from_cen = sqrt.((x_stars .- center_x).^2 + (y_stars .- center_y).^2)

    (Nstars,) = size(x_stars)
    
    testim = ref_im
    bimage = zeros(T,sx0,sy0)
    bimageI = zeros(Int64,sx0,sy0)
    testim2 = zeros(T,sx0,sy0)
    bmaskim2 = zeros(Bool,sx0,sy0)
    goodpix = zeros(Bool,sx0,sy0)

    prelim_infill!(testim,bmaskd,bimage,bimageI,testim2,bmaskim2,goodpix;widx=19,widy=19,ftype=ftype)
    testim .= ref_im #fixes current overwrite for 0 infilling

    ## calculate the star farthest outside the edge of the image in x and y
    cx = round.(Int,x_stars)
    cy = round.(Int,y_stars)
    px0 = outest_bounds(cx,sx0)
    py0 = outest_bounds(cy,sy0)

    ## these have to be allocating to get the noise model right
    Δx = (widx-1)÷2
    Δy = (widy-1)÷2
    padx = Np+Δx+px0
    pady = Np+Δy+py0
    in_image = ImageFiltering.padarray(testim2,ImageFiltering.Pad(:reflect,(padx+2,pady+2)));
    in_image_raw = ImageFiltering.padarray(testim,ImageFiltering.Pad(:reflect,(padx+2,pady+2)));
    in_bmaskd = ImageFiltering.padarray(bmaskd,ImageFiltering.Fill(true,(padx+2,pady+2)));
    out_mean = ImageFiltering.padarray(testim,ImageFiltering.Pad(:reflect,(padx+2,pady+2)));
    out_mean[in_bmaskd].=NaN
    out_draw = if ndraw!=1
        ImageFiltering.padarray(repeat(testim,outer=[1 1 ndraw]),ImageFiltering.Pad(:reflect,(padx+2,pady+2,0)));
    else
        ImageFiltering.padarray(repeat(testim,outer=[1 1]),ImageFiltering.Pad(:reflect,(padx+2,pady+2)));
    end
    for i=1:ndraw
        out_draw[in_bmaskd,i].=NaN
    end
    
    diffim = view(ref_im,1:sx0-1,:).-view(ref_im,2:sx0,:)
    in_sigiqr = sig_iqr(filter(.!isnan,diffim))
    
    add_sky_noise_clean!(in_image,in_bmaskd,in_sigiqr;seed=seed)

    cov = zeros(T,Np*Np,Np*Np)
    μ = zeros(T,Np*Np)

    # some important global sizes for the loop
    cntStar0 = 0
    stepx = (sx0+2) ÷ tilex
    stepy = (sy0+2) ÷ tiley

    # precallocate the image subblocks
    in_subimage = zeros(T,stepx+2*padx,stepy+2*pady)
    ism = zeros(T,stepx+2*padx,stepy+2*pady)
    bimage = zeros(T,stepx+2*padx-2*Δx,stepy+2*pady-2*Δy)
    bism = if sym
        zeros(T,stepx+2*padx-2*Δx,stepy+2*pady-2*Δy,2*Np-1, 2*Np-1);
    else
        zeros(T,stepx+2*padx-2*Δx,stepy+2*pady-2*Δy,2*Np-1, Np);
    end
    rng = MersenneTwister(seed)
    for jx=1:tilex, jy=1:tiley
        xrng, yrng, star_ind = im_subrng(jx,jy,cx,cy,sx0+2,sy0+2,px0,py0,stepx,stepy,padx,pady,tilex,tiley)
        cntStar = length(star_ind)
        cntStarIter = 0
        if cntStar > 0
            in_subimage .= in_image[xrng,yrng]
            if sym
                cov_avg_sym!(bimage, ism, bism, in_subimage, widx=widx, widy=widy,Np=Np)
            else
                cov_avg!(bimage, ism, bism, in_subimage, widx=widx, widy=widy,Np=Np)
            end
            offx = padx-Δx-(jx-1)*stepx
            offy = pady-Δy-(jy-1)*stepy
            # this builds in determinism, infilling from center to edge of global image
            p = sortperm(dist_from_cen[star_ind])
            for i in star_ind[p]
                if in_bmaskd[cx[i],cy[i]]
                    if sym
                        build_cov_sym!(cov,μ,cx[i]+offx,cy[i]+offy,bimage,bism,Np,widx,widy)
                    else
                        build_cov!(cov,μ,cx[i]+offx,cy[i]+offy,bimage,bism,Np,widx,widy)
                    end
                    cov_stamp = cx[i]-radNp:cx[i]+radNp,cy[i]-radNp:cy[i]+radNp
                    
                    kmasked2d = in_bmaskd[cov_stamp[1],cov_stamp[2]]
                    kbad = kmasked2d[:]
                    kgood =  .!kbad

                    sampCov = cov
                    cov_kgood_kgood = Symmetric(sampCov[kgood,kgood])
                    cov_kgood_kbad = sampCov[kgood,kbad];
                    cov_kbad_kbad = sampCov[kbad,kbad];

                    icov_kgood_kgood = try 
                        cholesky(cov_kgood_kgood)
                    catch
                        println("Had to use SVD for icov_kgood_kgood at (x,y) = ($(cx[i]),$(cy[i]))")
                        svd(cov_kgood_kgood)
                    end
                    icovkgoodkgoodCcovkgoodkbad = icov_kgood_kgood\cov_kgood_kbad
                    predcovar = Symmetric(cov_kbad_kbad - (cov_kgood_kbad'*icovkgoodkgoodCcovkgoodkbad))

                    sqrt_cov = try
                        ipcovC = cholesky(predcovar)
                        ipcovC.U
                    catch
                        println("Had to use SVD for sqrt_cov at (x,y) = ($(cx[i]),$(cy[i]))")
                        covsvd = svd(predcovar)
                        covsvd.V*diagm(sqrt.(covsvd.S))*covsvd.Vt
                    end

                    noise = randn(rng,ndraw,size(sqrt_cov)[1])*sqrt_cov;

                    data_in = out_mean[cov_stamp[1],cov_stamp[2]]
                    kstarpredn = (((data_in[kgood]-μ[kgood]))'*icovkgoodkgoodCcovkgoodkbad)'
                    kstarpred = kstarpredn .+ μ[kbad];
                    if any(isnan.(kstarpred))
                        error("You are about to infill a NaN. Things have gone horribly wrong.")
                    end
                    data_in[kbad].=kstarpred
                    out_mean[cov_stamp[1],cov_stamp[2]].=data_in
                    
                    for i = 1:ndraw
                        draw_in = out_draw[cov_stamp[1],cov_stamp[2],i]
                        kstarpredn = (((draw_in[kgood].-μ[kgood]))'*icovkgoodkgoodCcovkgoodkbad)'
                        draw_in[kbad].= kstarpredn .+ μ[kbad] .+ noise[i,:];
                        out_draw[cov_stamp[1],cov_stamp[2],i].=draw_in
                        #precompute the shifted images for the covariances prevents updating the data behind the covariance with e.g. draw 1 value as in the healpix version
                    end

                    # mark infilled pixels as good now
                    kmasked2d[kbad].=false
                    in_bmaskd[cov_stamp[1],cov_stamp[2]].=kmasked2d
                    cntStarIter += 1
                end
            end
        end
        cntStar0 += cntStarIter
        println("Finished $cntStarIter of $cntStar locations in tile ($jx, $jy)")
        flush(stdout)
    end
    if ndraw>0
        return out_mean[1:sx0, 1:sy0], out_draw[1:sx0, 1:sy0, :]
    else
        return out_mean[1:sx0, 1:sy0]
    end
end

"""
    proc_discrete(x_locs, y_locs, raw_image, mask_image; Np=33, widx=129, widy=widx, tilex=1, tiley=tilex, seed=2021, ftype::Int=32, ndraw=0) -> out_mean, out_draw

    
Process an image with a mask, replacing masked pixels with either a mean or draw from a distribution resembling the local pixel-pixel covariance structure in the image.

# Arguments:
- `x_locs`: A 1D array representing the location centers (in the x coordinate) for infilling.
- `y_locs`: A 1D array representing the location centers (in the y coordinate) for infilling.
- `raw_image`: A 2D array representing the input image.
- `mask_image`: A 2D array representing the mask.

# Keywords:
- `Np`: An optional integer specifying the number of pixels in a side (default: 33).
- `widx`: An optional integer specifying the width of the region used for training the local covariance in the x-direction (default: 129).
- `widy`: An optional integer specifying the width of the region used for training the local covariance in the y-direction (default: widx).
- `tilex`: An optional integer specifying the number of tiles in the x-direction for subdividing the image (default: 1).
- `tiley`: An optional integer specifying the number of tiles in the y-direction for subdividing the image (default: tilex).
- `seed`: An optional integer specifying the random number generator seed (default: 2021).
- `ftype`: An optional integer specifying the floating-point precision type (32 or 64) (default: 32).
- `rlim`: Radius limit for the radial mask beyond which pixels are not used for conditioning (units are pixels^2). (default: Inf)
- `ndraw`: An optional integer specifying the number of draws of samples from the statistical distribution of possible masked pixel values (default: 0).

# Returns
- If `ndraw` is 0, returns the debiased image as a 2D array.
- If `ndraw` is greater than 0, returns the debiased image as a 2D array and an array of `ndraw` draws.

# Examples
```julia
julia> raw_image = rand(100, 100)
julia> mask_image = kstar_circle_mask(100,rlim=256)
julia> result = proc_continuous([50],[50],raw_image, mask_image, Np=33, widx=129, seed=2021)
```
    
"""
function proc_discrete(x_locs,y_locs,raw_image,mask_image;Np=33,widx=129,widy=widx,tilex=1,tiley=tilex,seed=2021,ftype::Int=32,rlim=Inf,ndraw=0,sym::Bool=false)
    radNp = (Np-1)÷2
    if ftype == 32
        T = Float32
    else
        T = Float64
    end

    # renaming to match conventions
    ref_im = raw_image
    bmaskd = mask_image
    (sx0, sy0) = size(ref_im)

    x_stars = x_locs
    y_stars = y_locs

    # Calculate distances from image center
    center_x = sx0 ÷ 2
    center_y = sy0 ÷ 2
    dist_from_cen = sqrt.((x_stars .- center_x).^2 + (y_stars .- center_y).^2)

    (Nstars,) = size(x_stars)
 
    testim = ref_im
    bimage = zeros(T,sx0,sy0)
    bimageI = zeros(Int64,sx0,sy0)
    testim2 = zeros(T,sx0,sy0)
    bmaskim2 = zeros(Bool,sx0,sy0)
    goodpix = zeros(Bool,sx0,sy0)

    prelim_infill!(testim,bmaskd,bimage,bimageI,testim2,bmaskim2,goodpix;widx=19,widy=19,ftype=ftype)
    testim .= ref_im #fixes current overwrite for 0 infilling

    ## calculate the star farthest outside the edge of the image in x and y
    cx = round.(Int,x_stars)
    cy = round.(Int,y_stars)
    px0 = outest_bounds(cx,sx0)
    py0 = outest_bounds(cy,sy0)

    ## these have to be allocating to get the noise model right
    Δx = (widx-1)÷2
    Δy = (widy-1)÷2
    padx = Np+Δx+px0
    pady = Np+Δy+py0
    in_image = ImageFiltering.padarray(testim2,ImageFiltering.Pad(:reflect,(padx+2,pady+2)));
    in_image_raw = ImageFiltering.padarray(testim,ImageFiltering.Pad(:reflect,(padx+2,pady+2)));
    in_bmaskd = ImageFiltering.padarray(bmaskd,ImageFiltering.Fill(true,(padx+2,pady+2)));
    out_mean = ImageFiltering.padarray(testim,ImageFiltering.Pad(:reflect,(padx+2,pady+2)));
    out_mean[in_bmaskd].=NaN
    out_draw = if ndraw!=1
        ImageFiltering.padarray(repeat(testim,outer=[1 1 ndraw]),ImageFiltering.Pad(:reflect,(padx+2,pady+2,0)));
    else
        ImageFiltering.padarray(repeat(testim,outer=[1 1]),ImageFiltering.Pad(:reflect,(padx+2,pady+2)));
    end
    for i=1:ndraw
        out_draw[in_bmaskd,i].=NaN
    end

    diffim = view(ref_im,1:sx0-1,:).-view(ref_im,2:sx0,:)
    in_sigiqr = sig_iqr(filter(.!isnan,diffim))
    
    add_sky_noise_clean!(in_image,in_bmaskd,in_sigiqr;seed=seed)

    cov = zeros(T,Np*Np,Np*Np)
    μ = zeros(T,Np*Np)

    # compute a radial mask for reduced num cond pixels
    circmask = kstar_circle_mask(Np,rlim=rlim)

    # some important global sizes for the loop
    cntStar0 = 0
    stepx = (sx0+2) ÷ tilex
    stepy = (sy0+2) ÷ tiley

    # precallocate the image subblocks
    in_subimage = zeros(T,stepx+2*padx,stepy+2*pady)
    ism = zeros(T,stepx+2*padx,stepy+2*pady)
    bimage = zeros(T,stepx+2*padx-2*Δx,stepy+2*pady-2*Δy)
    bism = if sym
        zeros(T,stepx+2*padx-2*Δx,stepy+2*pady-2*Δy,2*Np-1, 2*Np-1);
    else
        zeros(T,stepx+2*padx-2*Δx,stepy+2*pady-2*Δy,2*Np-1, Np);
    end
    rng = MersenneTwister(seed)
    for jx=1:tilex, jy=1:tiley
        xrng, yrng, star_ind = im_subrng(jx,jy,cx,cy,sx0+2,sy0+2,px0,py0,stepx,stepy,padx,pady,tilex,tiley)
        cntStar = length(star_ind)
        if cntStar > 0
            in_subimage .= in_image[xrng,yrng]
            if sym
                cov_avg_sym!(bimage, ism, bism, in_subimage, widx=widx, widy=widy,Np=Np)
            else
                cov_avg!(bimage, ism, bism, in_subimage, widx=widx, widy=widy,Np=Np)
            end
            offx = padx-Δx-(jx-1)*stepx
            offy = pady-Δy-(jy-1)*stepy
            # this builds in determinism, infilling from center to edge of global image
            p = sortperm(dist_from_cen[star_ind])
            for i in star_ind[p]
                if sym
                    build_cov_sym!(cov,μ,cx[i]+offx,cy[i]+offy,bimage,bism,Np,widx,widy)
                else
                    build_cov!(cov,μ,cx[i]+offx,cy[i]+offy,bimage,bism,Np,widx,widy)
                end
                cov_stamp = cx[i]-radNp:cx[i]+radNp,cy[i]-radNp:cy[i]+radNp
                    
                kmasked2d = in_bmaskd[cov_stamp[1],cov_stamp[2]]
                knotuse, kcond = gen_pix_mask_circ(kmasked2d,circmask;Np=Np)
                kgood = .!knotuse
                kbad = kmasked2d[:]

                sampCov = cov
                cov_kgood_kgood = Symmetric(sampCov[kgood,kgood])
                cov_kgood_kbad = sampCov[kgood,kbad];
                cov_kbad_kbad = sampCov[kbad,kbad];

                icov_kgood_kgood = try 
                    cholesky(cov_kgood_kgood)
                catch
                    println("Had to use SVD for icov_kgood_kgood at (x,y) = ($(cx[i]),$(cy[i]))")
                    svd(cov_kgood_kgood)
                end
                icovkgoodkgoodCcovkgoodkbad = icov_kgood_kgood\cov_kgood_kbad
                predcovar = Symmetric(cov_kbad_kbad - (cov_kgood_kbad'*icovkgoodkgoodCcovkgoodkbad))

                sqrt_cov = try
                    ipcovC = cholesky(predcovar)
                    ipcovC.U
                catch
                    println("Had to use SVD for sqrt_cov at (x,y) = ($(cx[i]),$(cy[i]))")
                    covsvd = svd(predcovar)
                    covsvd.V*diagm(sqrt.(covsvd.S))*covsvd.Vt
                end

                noise = randn(rng,ndraw,size(sqrt_cov)[1])*sqrt_cov;

                data_in = in_image_raw[cov_stamp[1],cov_stamp[2]]
                kstarpredn = (((data_in[kgood]-μ[kgood]))'*icovkgoodkgoodCcovkgoodkbad)'
                kstarpred = kstarpredn .+ μ[kbad];
                if any(isnan.(kstarpred))
                    error("You are about to infill a NaN. Things have gone horribly wrong.")
                end
                data_in[kbad].=kstarpred
                out_mean[cov_stamp[1],cov_stamp[2]].=data_in
                in_image_raw[cov_stamp[1],cov_stamp[2]].=data_in

                for i=1:ndraw
                    draw_in = out_draw[cov_stamp[1],cov_stamp[2],i]
                    kstarpredn = (((draw_in[kgood].-μ[kgood]))'*icovkgoodkgoodCcovkgoodkbad)'
                    draw_in[kbad].= kstarpredn .+ μ[kbad] .+ noise[i,:];
                    out_draw[cov_stamp[1],cov_stamp[2],i].=draw_in
                end
                kmasked2d[kbad].=false
                in_bmaskd[cov_stamp[1],cov_stamp[2]].=kmasked2d
                cntStar0 += cntStar
            end
        end
        cntStar0 += cntStar
        println("Finished $cntStar stars in tile ($jx, $jy)")
        flush(stdout)
    end
    if ndraw>0
        return out_mean[1:sx0, 1:sy0], out_draw[1:sx0, 1:sy0, :]
    else
        return out_mean[1:sx0, 1:sy0]
    end
end
