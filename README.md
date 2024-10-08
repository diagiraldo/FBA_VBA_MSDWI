# Fixel- and voxel-based analysis with multi-shell diffusion-weighted MRI
Guide for investigating tissue-specific effects with multi-shell DW-MRI. These are the steps we followed in our paper ["Investigating Tissue-Specific Abnormalities in Alzheimer's Disease with Multi-Shell Diffusion MRI"](https://content.iospress.com/articles/journal-of-alzheimers-disease/jad220551).

<img src="figures/pipeline.png?raw=True" width="800px" style="margin:0px 0px"/>

We performed all steps using [MRtrix3](https://www.mrtrix.org/) (version 3.0.2).

A lot of steps are done for each one of the images in the dataset, so the [`for_each`](https://mrtrix.readthedocs.io/en/dev/reference/commands/for_each.html) is extremely handy.

## Pre-processing

We followed the [MRtrix3 documentation for DW-MRI pre-processing](https://mrtrix.readthedocs.io/en/latest/fixel_based_analysis/mt_fibre_density_cross-section.html#pre-processsing-steps) including:
- Denoising
- Suppression of Gibbs-ringing artifacts
- Correction for head motion and eddy current-induced distortions
- Bias-field correction

**About masks**: We got the brain masks using T1-W MRI and then aligning it with the mean $b=0$ image from DW-MRI. 

After these steps we had our pre-processed MRIs inside a folder `preproc_dwi`:
 ```
$ ls preproc_dwi/
IMG_01.mif
IMG_02.mif
IMG_03.mif
...
IMG_N.mif
```

We up-sampled the images (and masks) to 1.25×1.25×1.25 mm^3 to improve the accuracy of subsequent spatial normalization. However, this is might not be necessary.
```
mkdir preproc_dwi_up masks_up

for_each preproc_dwi/*.mif : mrgrid IN regrid preproc_dwi_up/NAME -voxel 1.25 
for_each masks/*.mif : mrgrid IN regrid masks_up/NAME -voxel 1.25 -interp nearest
```

## Multi-tissue decomposition

Calculate responses per image:
```
mkdir wm_response gm_response csf_response voxels_response

for_each preproc_dwi/*.mif : dwi2response dhollander IN wm_response/PRE.txt gm_response/PRE.txt csf_response/PRE.txt -mask masks/NAME -voxels voxels_response/NAME
```

We had to deal with an scanner upgrade during the acquisition of the data, to account for the different scanners, we calculated separate average responses per scanner.

First we separated the responses per scanner, and then used [`responsemean`](https://mrtrix.readthedocs.io/en/latest/reference/commands/responsemean.html) per folder:
```
mkdir wm_res_scanner1 gm_res_scanner1 csf_res_scanner1

while read -r i
do
  cp wm_response/${i}.txt wm_res_scanner1/${i}.txt
  cp gm_response/${i}.txt gm_res_scanner1/${i}.txt
  cp csf_response/${i}.txt csf_res_scanner1/${i}.txt
done < list_of_imgIDs_scanner1.txt

responsemean wm_res_scanner1/*.txt mean_wm_res_scanner1.txt
responsemean gm_res_scanner1/*.txt mean_gm_res_scanner1.txt
responsemean csf_res_scanner1/*.txt mean_csf_res_scanner1.txt
```

Then, with the mean responses, we performed Multi-shell multi-tissue constrained spherical deconvolution (MSMT-CSD) using [`dwi2fod msmt_csd`](https://mrtrix.readthedocs.io/en/latest/reference/commands/dwi2fod.html) (per scanner):
```
mkdir wm_fodf gm csf

for_each wm_res_scanner1/*.txt : dwi2fod msmt_csd preproc_dwi_up/PRE.mif mean_wm_res_scanner1.txt wm_fodf/PRE.mif mean_gm_res_scanner1.txt gm/PRE.mif mean_csf_res_scanner1.txt csf/PRE.mif -mask masks_up/PRE.mif
```

We did multi-tissue intensity normalization with [`mtnormalise`](https://mrtrix.readthedocs.io/en/latest/reference/commands/mtnormalise.html):
```
mkdir wm_fodf_mt gm_mt csf_mt

for_each wm_fodf/*.mif : mtnormalise IN wm_fodf_mt/NAME gm/NAME gm_mt/NAME csf/NAME csf_mt/NAME -mask masks_up/NAME 
```

## Study-specific template

We built a study-specific template with an unbiased subsample of our study sample.

First, we created folders with the data (symbolic links) that we used for template construction: 
```
mkdir template template/wm_fodfs template/gm template/csf template/masks

while read -r i
do
    ln -sr wm_fodf_mt/${i}.mif template/wm_fodfs/${i}.mif
    ln -sr gm_mt/${i}.mif template/gm/${i}.mif
    ln -sr csf_mt/${i}.mif template/csf/${i}.mif
    ln -sr masks_up/${i}.mif template/masks/${i}.mif
done < list_of_imgIDs_for_template.txt
```
Then, we calculated the multi-channel template with [`population_template`](https://mrtrix.readthedocs.io/en/latest/reference/commands/population_template.html):
```
population_template template/wm_fodfs template/wm_fodf_template.mif template/gm template/gm_template.mif template/csf template/csf_template.mif -mask_dir template/masks -voxel_size 1.25
```
The template is composed of a WM-like fODF (`template/wm_fodf_template.mif`) along with the voxel-wise templates containing the tissue-like contributions for GM (`template/gm_template.mif`) and CSF (`template/csf_template.mif`):
<img src="figures/mc_template.png?raw=True" width="800px" style="margin:0px 0px"/>

We extracted the voxel-wise template for WM-like contribution from the WM-like fODF as the l=0 term of the spherical harmonic expansion, and used it to create a WM voxel mask:
```
mrconvert -coord 3 0 -axes 0,1,2 template/wm_fodf_template.mif template/wm_template.mif

mrthreshold template/wm_template.mif template/wm_voxel_mask.mif
```

At this step, we also created a WM fixel-mask with [`fod2fixel`](https://mrtrix.readthedocs.io/en/latest/reference/commands/fod2fixel.html):
```
fod2fixel -mask template/wm_voxel_mask.mif -fmls_peak_value 0.06 template/wm_fodf_template.mif template/wm_fixel_mask
```

### Generate template tractogram

From the WM fODF template, we generated a tractogram using the iFOD2 algorithm, the default option in [`tckgen`](https://mrtrix.readthedocs.io/en/latest/reference/commands/tckgen.html), and then used [`tcksift`](https://mrtrix.readthedocs.io/en/latest/reference/commands/tcksift.html) to reduce density biases in the tractogram:

```
tckgen -angle 22.5 -maxlen 250 -minlen 10 -power 1.0 -cutoff 0.06 template/wm_fodf_template.mif -seed_dynamic template/wm_fodf_template.mif -mask template/wm_voxel_mask.mif -select 10000000 template/tracto_10_million.tck

tcksift template/tracto_10_million.tck template/wm_fodf_template.mif template/tracto_sift_2_million.tck -term_number 2000000
```

We also created a tractogram with fewer streamlines (lighter to load) for visualization purposes:
```
tckedit template/tracto_sift_2_million.tck -number 200000 template/tracto_sift_200k.tck
```

## Spatial normalisation

We estimated the warp that align each set of `wm_fodf_mt`, `gm_mt`, and `csf_mt` to population template with [`mrregister`](https://mrtrix.readthedocs.io/en/latest/reference/commands/mrregister.html):
```
mkdir warp_sub2temp warp_temp2sub

for_each wm_fodf_mt/*.mif : mrregister IN template/wm_fodf_template.mif gm_mt/NAME template/gm_template.mif csf_mt/NAME template/csf_template.mif -mask1 masks_up/NAME -nl_warp warp_sub2temp/NAME warp_temp2sub/NAME
```

Then, we used those warps from subject to template to spatially normalise each map (in this step we DO NOT reorient fODFs because it is not a trivial calculation, instead we reoriented fixel maps later on):
```
mkdir wm_fodf_intemplate gm_intemplate csf_intemplate 
for_each wm_fodf_mt/*.mif : mrtransform IN -warp warp_sub2temp/NAME -reorient_fod no wm_fodf_intemplate/NAME
for_each gm_mt/*.mif : mrtransform IN -warp warp_sub2temp/NAME gm_intemplate/NAME
for_each csf_mt/*.mif : mrtransform IN -warp warp_sub2temp/NAME csf_intemplate/NAME
```

## Diffusion-derived measures

### Fixel-wise measures

**Tissue constituency**: the integral of a fODF lobe is proportional to the volume of fibers aligned in the corresponding lobe direction; this measure is known as apparent fiber density (AFD).

We first calculated the AFD with [`fod2fixel`](https://mrtrix.readthedocs.io/en/latest/reference/commands/fod2fixel.html):
```
mkdir fixels_intemplate

for_each wm_fodf_template/*.mif : fod2fixel IN -mask template/wm_voxel_mask.mif fixels_intemplate/PRE -afd afd.mif -fmls_peak_value 0.06
```
This step creates a fixel directory per subject/image containinf the files `index.mif`, `directions.mif`, and `afd.mif`.
<img src="figures/fODF_AFD.png?raw=True" width="800px" style="margin:0px 0px"/>

Then, we reoriented each fixel directory according to the warp from subject to template using [`fixelreorient`](https://mrtrix.readthedocs.io/en/latest/reference/commands/fixelreorient.html):
```
for_each fixels_intemplate/* : fixelreorient IN warp_sub2temp/NAME.mif fixels_intemplate/NAME -force
```
Those fixels do not correspond (yet) to the template fixel mask, so we established the correspondence between fixels for each subject/image and the fixel mask (`template/wm_fixel_mask`):
```
for_each fixels_intemplate/* : fixelcorrespondence -angle 30 IN/afd.mif template/wm_fixel_mask template/afd PRE.mif
```

**Local morphology**: The measure that accounts for the effect of spatial normalization in each fiber direction is the change in the area perpendicular to that direction, also known as Fiber Cross-section (FC).

From the warp from subject to template, we calculated the FC and log(FC):
```
for_each warp_sub2temp/* : warp2metric IN -fc template/wm_fixel_mask template/fc NAME

mkdir template/log_fc
cp template/wm_fixel_mask/* template/log_fc/

for_each template/fc/*.mif : mrcalc IN -log template/log_fc/NAME
```
Note that each measure is in a separate fixel folder containing the same `index.mif` and `directions.mif` files as in `template/wm_fixel_mask`.


### Voxel-wise measures

**Tissue constituency**: Spatially normalized tissue-like contributions. Note that after spatial normalisation there might be small negative values, so we set the minimum contribution of each tissue-like component at 1e-8 to avoid numerical errors later on.
```
EPSILON=0.00000001
mkdir wm_tf_intemplate gm_tf_intemplate csf_tf_intemplate

for_each wm_fodf_intemplate/*.mif : mrconvert -coord 3 0 -axes 0,1,2 IN - "|" mrcalc - ${EPSILON} -ge - ${EPSILON} -if wm_tf_intemplate/NAME
for_each gm_intemplate/*.mif : mrconvert -axes 0,1,2 IN - "|" mrcalc - ${EPSILON} -ge - ${EPSILON} -if gm_tf_intemplate/NAME
for_each csf_intemplate/*.mif : mrconvert -axes 0,1,2 IN - "|" mrcalc - ${EPSILON} -ge - ${EPSILON} -if csf_tf_intemplate/NAME
```

**Local morphology**: change induced by the spatial normalization. 
```
mkdir jdet_sub2temp log_jdet_sub2temp

for_each warp_sub2temp/* : warp2metric IN -jdet jdet_sub2temp/NAME 
for_each jdet_sub2temp/*.mif : mrcalc IN -log log_jdet_sub2temp/NAME
```

**From contributions to fractions**: To ensure tissue costituency measures represent true fractions of the signal, we divided the tissue-like contributions and AFD by the sum of the three tissue-like contributions (WM + GM + CSF): 

```
mkdir sum_tf_intemplate

for_each wm_tf_intemplate/*.mif : mrcalc IN gm_tf_intemplate/NAME -add csf_tf_intemplate/NAME -add sum_tf_intemplate/NAME

for_each wm_tf_intemplate/*.mif : mrcalc IN sum_tf_intemplate/NAME -div wm_tf_intemplate/NAME -force
for_each gm_tf_intemplate/*.mif : mrcalc IN sum_tf_intemplate/NAME -div gm_tf_intemplate/NAME -force
for_each csf_tf_intemplate/*.mif : mrcalc IN sum_tf_intemplate/NAME -div csf_tf_intemplate/NAME -force
```

```
mkdir template/sum_tf_infixels template/normafd
cp template/wm_fixel_mask/* template/sum_tf_infixels/.
cp template/wm_fixel_mask/* template/normafd/.

for_each sum_tf_intemplate/*.mif : voxel2fixel IN template/sum_tf_infixels template/sum_tf_infixels NAME
for_each template/afd/*.mif : mrcalc IN template/sum_tf_infixels/NAME -div template/normafd/NAME
```

## Statistical Analyses
We did non-parametric hypothesis testing using [`ficelcfestats`](https://mrtrix.readthedocs.io/en/dev/reference/commands/fixelcfestats.html) and [`mrclusterstats`](https://mrtrix.readthedocs.io/en/dev/reference/commands/mrclusterstats.html). 
Steps: smoothing

### Fixel-based analysis

Fixel connectivity matrix
```
fixelconnectivity template/wm_fixel_mask template/tracto_sift_2_million.tck template/wm_fixel_connectivity
```

Smooth fixel data with [`fixelfilter`](https://mrtrix.readthedocs.io/en/dev/reference/commands/fixelfilter.html)


**Omnibus F-test**

**Posthoc tests**

### Voxel-based analysis

We calculated the isometric log-ratios and smoothed (fwhm=5) them prior statistical analyses
```
mkdir smooth_ilr1 smooth_ilr2

invsqrt6=0.4082483
invsqrt2=0.7071068

for_each wm_tf_intemplate/*.mif : mrcalc gm_tf_intemplate/NAME csf_tf_intemplate/NAME -mult IN 2 -pow -div -log ${invsqrt6} -mult - "|" mrfilter - smooth smooth_ilr1/NAME -fwhm 5
for_each csf_tf_intemplate/*mif : mrcalc IN gm_tf_intemplate/NAME -div -log ${invsqrt2} -mult - "|" mrfilter - smooth smooth_ilr2/NAME -fwhm 5
```

We also smoothed the log(jdet) map
```
mkdir smooth_log_jdet

for_each log_jdet_sub2temp/*mif : mrfilter IN smooth smooth_log_jdet/NAME -fwhm 5
```

**Omnibus F-test**
```
mrclusterstats info4stats/list_ilr_log_jdet_files.txt info4stats/design_ilr_log_jdet.txt info4stats/contrasts_ilr_log_jdet.txt info4stats/omniF_brain_voxel_mask.mif results_omniF_ilr_log_jdet/ -exchange_whole info4stats/ex_whole_ilr_log_jdet.txt -variance info4stats/var_gr_ilr_log_jdet.txt -ftests info4stats/omniF_ilr_log_jdet.txt -fonly -nthreads 20
```

**Posthoc tests**
```
mrthreshold results_omniF_ilr_log_jdet/fwe_1mpvalue.mif -abs 0.95 results_omniF_ilr_log_jdet/sig_mask.mif

mrclusterstats -force info4stats/list_ilr_log_jdet_files.txt info4stats/design_ilr_log_jdet.txt info4stats/contrasts_ilr_log_jdet.txt results_omniF_ilr_log_jdet/sig_mask.mif results_post_ilr_log_jdet/ -exchange_whole info4stats/ex_whole_ilr_log_jdet.txt -variance info4stats/var_gr_ilr_log_jdet.txt -strong -nthreads 20
```

## Citation

If you follow this guide, please consider citing our paper:

```
@article{Giraldo2022,
  doi = {10.3233/jad-220551},
  url = {https://doi.org/10.3233/jad-220551},
  year = {2022},
  month = oct,
  publisher = {{IOS} Press},
  pages = {1--21},
  author = {Diana L. Giraldo and Robert E. Smith and Hanne Struyfs and Ellis Niemantsverdriet and Ellen De Roeck and Maria Bjerke and Sebastiaan Engelborghs and Eduardo Romero and Jan Sijbers and Ben Jeurissen},
  editor = {Konstantinos Arfanakis},
  title = {Investigating Tissue-Specific Abnormalities in {A}lzheimer's Disease with Multi-Shell Diffusion {MRI}},
  journal = {Journal of Alzheimer's Disease}
}
```

## Contact

Diana L. Giraldo Franco [@diagiraldo](https://github.com/diagiraldo)