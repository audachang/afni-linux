#!/bin/tcsh

# Input variables
set sub = $1
set sesid = $2

# Directories
set mask_dir = ../../ds001499/derivatives/spm/$sub
set data_dir = ../afni/${sub}_${sesid}.results
set output_dir = $data_dir/masks_in_template_space

# Ensure output directory exists
mkdir -p $output_dir

# Paths for transformation files
set affine_transform = $data_dir/anat.un.aff.Xat.1D
set nl_warp = $data_dir/anat.un.aff.qw_WARP.nii
set template_space_anat = $data_dir/sub-CSI2_T1w_preproc_ns+tlrc.HEAD

# List symbolic links in the mask directory
set masks = (`ls -1 $mask_dir/*.nii.gz`)

# Loop through each mask file
foreach mask_link ($masks)
    set mask_link2 = `echo $mask_link | sed 's/@$//'`
    echo $mask_link2
    # Resolve symbolic link to get actual file path
    set mask_file = `readlink -f $mask_link | sed 's/@$//'`


    # Extract the base name (e.g., sub-CSI1_mask-LHEarlyVis)
    set mask_base = `basename $mask_link2 .nii.gz`
    echo $mask_base
   

    # Step 1: Copy the resolved mask to AFNI format in the output directory
    3dcopy $mask_file $output_dir/${mask_base}+orig -overwrite

    # Step 2: Apply affine transformation
    3dAllineate -master $template_space_anat \
                -1Dmatrix_apply $affine_transform \
                -input $output_dir/${mask_base}+orig \
                -prefix $output_dir/${mask_base}_affine

    # Step 3: Apply non-linear warp to bring mask to template space
    3dNwarpApply -master $template_space_anat \
                 -nwarp "$nl_warp" \
                 -source $output_dir/${mask_base}_affine+tlrc \
                 -prefix $output_dir/${mask_base}_template
end

# Cleanup intermediate files (optional)
rm $output_dir/*_affine+*

echo "All masks have been processed and saved in template space at $output_dir."
