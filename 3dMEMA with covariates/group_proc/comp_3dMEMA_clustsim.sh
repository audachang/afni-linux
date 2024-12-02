#!/usr/bin/tcsh -ef
if ( $#argv < 4 || $#argv > 5 ) then
    echo "usage: ./comp_3dMEMA_clustsim.sh <model> <condition> <group_names> [<cov_name>] <subf>"
    echo
    echo "when there is covariate:"
    echo "example: ./comp_3dMEMA_clustsim.sh BLOCK sentences HC_AVH+ CovFile_age_iq_clean sub_HC-AVH+.txt"
    echo
    echo "When there is no covariate:"
    echo "example: ./comp_3dMEMA_clustsim.sh BLOCK sentences HC_AVH+ sub_HC-AVH+.txt"
    echo
    echo "adapted from https://afni.nimh.nih.gov/pub/dist/doc/htmldoc/codex/main_det_2018_TaylorE>"
    exit 0
endif

# ================ Set up paths and many params ======================
set model = $1
set condstr = $2
set group_names = $3

# Handle optional cov_name
if ( $#argv == 5 ) then
    set cov_name = $4
    set sublist = (`cat $5`)
    set nv = (`cat $5 | wc -l`)
    set odir = derivatives/group_glm/test.${model}.3dMEMA_N=$nv.${condstr}.${group_names}.${cov_name}.results
else
    set cov_name = ""
    set sublist = (`cat $4`)
    set nv = (`cat $4 | wc -l`)
    set odir = derivatives/group_glm/test.${model}.3dMEMA_N=$nv.${condstr}.${group_names}.results
endif

# Echoing inputs for debugging
echo "Model: $model"
echo "Condition string: $condstr"
echo "Group names: $group_names"
if ( "$cov_name" != "" ) then
    echo "Covariate name: $cov_name"
else
    echo "No covariate provided."
endif
echo "Subject list file: $sublist"
echo "Number of subjects: $nv"


set here        = $PWD
set p_0         = /media/data1/fmri_course/fmri2401/yun/My_proj
set path_main   = ${p_0}/derivatives/afni
#set path_proc   = ${path_main}/data_proc_nimh

set path_mema   = ${path_main}/${odir}

# parameters related to 3dMEMA
# not running 3dMEMA here; its done in create_3dMEMA_test.sh
#set script_mema = do_group_level_nimh.tcsh # generated command file name
set omema       = stats.mema+tlrc.HEAD      # output effect+stats filename
set omema_mskd  = stats.mema_mskd # masked, stats in brain

# Cluster parameters
set csim_NN     = "NN1"    # neighborhood; could be NN1, NN2, NN3
set csim_sided  = "2sided" # could be 1sided, 2sided or bisided
set csim_pthr   = 0.01     # voxelwise thr in 3dClustSim
set csim_alpha  = 0.05     # nominal FWE


cd $path_mema


echo "removing all clust_t*"
if (-f clust_tpos_table.1D) then
	rm clust*
endif
#echo clust_t*


# ====================== Make group mask ==========================

# Make a group level mask for reporting results.  This also determines
# the volume over which multiple comparisons corrections for voxelwise
# stats are done.
#3dmask_tool                                             \
#    -prefix mask.nii.gz                                 \
#    -input `ls ${p_0}/subj.sub*/sub????.${model}/mask_epi_anat.*.HEAD` \
#    -frac 1.0
3dcopy -overwrite \
  ${path_main}/derivatives/group_glm/mask_intersection_up2date+tlrc.HEAD \
  ./mask.nii.gz
# ==================== Calc average smoothness =======================

# Get the line from each blur estimate file that has our desired
# parameters; we are running REML here and using the ACF smoothness
# estimation, so the gpattern variable reflects both.  For N subjects,
# the output *1D file contains N rows of the 3 ACF parameters.

echo "computing group average ACF params...."
set gpattern = 'err_reml ACF'
grep -h "$gpattern" ${path_main}/sub*/blur_est*   \
    | cut -d\  -f1-3                              \
    > group_ACF_ests.1D

# Get the group average ACF parameters.
set blur_est = ( `3dTstat -mean -prefix - group_ACF_ests.1D\'` )
echo "++ The group average ACF params are: $blur_est"

# ==================== Cluster simulations =======================

# Simulations for FWE corrected cluster-size inference
echo "Simulating FWE corrected clsuter-size inference...."
3dClustSim                                       \
    -both                                        \
    -mask   mask.nii.gz                          \
    -acf    $blur_est                            \
    -prefix ClustSim

# Get the volume threshold value from the ClustSim results, based on
# user's choice of parameters as set above.  The "-verb 0" means that
# just the threshold number of voxels is returned, so we can save that
# as a variable.

if (! -d files_ClustSim) then

  mkdir files_ClustSim
  mv ClustSim* files_ClustSim

endif

#cp ${p_0}/3dClustSim.ACF.cmd .
cp 3dClustSim.cmd 3dClustSim.ACF.cmd

set clust_thrvol = `1d_tool.py -verb 0                                \
                        -infile ClustSim.${csim_NN}_${csim_sided}.1D  \
                        -csim_pthr   $csim_pthr                       \
                        -csim_alpha "$csim_alpha"`

# Get the statistic value equivalent to the desired voxelwise p-value,
# for thresholding purposes.  Using the same p-value and sidedness
# that were selected in the ClustSim results.  This program also gets
# the number of degrees of freedom (DOF) from the header of the volume
# containing the statistic. The "-quiet" means that only the
# associated statistic value is returned, so we can save it to a
# variable.
set insetstr = "[${group_names}:t]"

echo "${omema}${insetstr}"
3dinfo -label ${omema}


set voxstat_thr = `p2dsetstat -quiet                    \
                    -pval $csim_pthr                    \
                    "-${csim_sided}"                    \
                    -inset ${omema}"[${group_names}:t]"`
                    #-inset ${omema}${insetstr}`
echo $voxstat_thr

echo "++ The final cluster volume threshold is:  $clust_thrvol"
echo "++ The voxelwise stat value threshold is:  $voxstat_thr"

# ================== Make cluster maps =====================

# Apply WB mask to the statistics results, so we only find clusters
# that lie within the mask of interest.
3dcalc                              \
    -a ${omema}                     \
    -b mask.nii.gz                  \
    -expr 'a*b'                     \
    -prefix ${omema_mskd}           \
    -overwrite

# Following the previous paper, these commands extract the "positive"
# and "negative" cluster info, respectively, into separate files.
# Each applies clustering parameters above and makes: a *map* of
# cluster ROIs (regions numbered 1, 2, 3, ...); a map of the effect
# estimate (EE) values within those clusters; and a table report of
# the clusters.
# Technical note: '-1tindex 1' means that the threshold is applied to
# the [1]st volume of the input dset, which here holds the statistic
# values; '-1dindex 0' means that data values saved in '-prefix ...'
# come from the [0]th volume of the input dset, which here holds the
# EE values.
set csim_pref = "clust_tpos"
#3dclust
#    -1Dformat -nosum -1tindex 1 -1dindex 0                     \
#    -2thresh -1e+09 $voxstat_thr  -dxyz=1                      \
#    -savemask ${csim_pref}_map.nii.gz                          \
#    -prefix   ${csim_pref}_EE.nii.gz                           \
#    1.01 ${clust_thrvol} ${omema_mskd}+tlrc > ${csim_pref}_table.1D

3dClusterize -inset ${omema_mskd}+tlrc \
    -idat 0 -ithr 1 \
    -clust_nvox ${clust_thrvol} -NN 1 \
    -bisided -1e+09 $voxstat_thr \
    -mask ${omema_mskd}+tlrc \
    -out_mask ${csim_pref}_map.nii.gz \
    -pref_dat ${csim_pref}_EE.nii.gz > ${csim_pref}_table.1D




# Also make a mask of t-stats (not necessary, but matching previous
# work)
3dcalc \
    -a ${csim_pref}_map.nii.gz                \
    -b ${omema}'[1]'                          \
    -expr "step(a)*b"                         \
    -prefix ${csim_pref}_t.nii.gz             \
    -float

set csim_pref = "clust_tneg"
3dclust                                                        \
    -1Dformat -nosum -1tindex 1 -1dindex 0                     \
    -2thresh -$voxstat_thr 1e+09 -dxyz=1                       \
    -savemask ${csim_pref}_map.nii.gz                          \
    -prefix   ${csim_pref}_EE.nii.gz                           \
    1.01 ${clust_thrvol} ${omema_mskd}+tlrc > ${csim_pref}_table.1D


    # run 3drefit to attach 3dClustSim results to stats
    set cmd = ( `cat 3dClustSim.ACF.cmd` )
    $cmd stats.mema+tlrc

cd $here

# ===================================================================

echo "\n++ DONE with group level stats + clustering!\n"

time ; exit 0
