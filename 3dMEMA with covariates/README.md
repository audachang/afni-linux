### create_3dMEMA_test_cov.sh Script Explanation

This script is designed to perform a group analysis using 3dMEMA (Mixed-Effects Multilevel Analysis) in AFNI with covariates. Below is a detailed explanation of the script's syntax and contents.

#### Usage
```
create_3dMEMA_test.sh <model> <contrast> <subfn> <covfn>
```
- `<model>`: The model name for the analysis.
- `<contrast>`: The contrast of interest.
- `<subfn>`: A file containing a list of subjects to be included in the group analysis.
- `<covfn>`: The covariate file containing subject IDs and de-meaned covariates.

#### Example
```
create_3dMEMA_test.sh BLOCK words participants_AVH+.txt Cov_psyrats_AVH+.tsv
```

#### Script Breakdown
1. **Input Validation**:
   ```
   if ( $#argv != 4 ) then
       echo "usage: create_3dMEMA_test.sh <model> <contrast> <subfn> <covfn>"
       echo "example: create_3dMEMA_test.sh BLOCK words participants_AVH+.txt Cov_psyrats_AVH+.tsv"
       exit 0
   endif
   ```
   Checks if the correct number of arguments is provided.

2. **Read Subject List**:
   ```
   cat $3 | grep "^[^#]" > tmp
   set sublist = (`cat tmp`)
   rm tmp
   ```
   Reads the list of subjects from the provided file, ignoring comments.

3. **Set Variables**:
   ```
   set model = $1
   set condstr = $2
   set covfn = $4
   set cov = `echo $covfn:r`
   ```
   Sets the model, contrast, and covariate variables.

4. **Directory Paths**:
   ```
   set ddir = ../../afni
   set output_dir = ../../afni/derivatives/group_glm
   ```
   Defines relative paths for data and output directories.

5. **Create Subject Data List**:
   ```
   foreach sub ($sublist)
       echo $ddir/{$sub}.results/stats.${sub}_REML+tlrc.HEAD >> tmp
   end
   ```
   Creates a list of subject data files.

6. **Calculate Number of Subjects**:
   ```
   set nv = (`cat tmp | wc -l`)
   ```
   Counts the number of subjects.

7. **Set Analysis Parameters**:
   ```
   set mask_dset = $output_dir/mask_intersection_up2date+tlrc
   set beta_A = `3dinfo -label2index "${condstr}#0_Coef" $ddir/${sub}.results/stats.${sub}_REML+tlrc.HEAD`
   set tstat_A = `3dinfo -label2index "${condstr}#0_Tstat" $ddir/${sub}.results/stats.${sub}_REML+tlrc.HEAD`
   ```
   Sets the mask dataset and retrieves beta and t-stat indices.

8. **Calculate Mean Covariate**:
   ```
   set mean_psyrats = `awk '{sum += $2; count++} END {if (count > 0) print int((sum / count) + 0.5)}' $covfn`
   ```
   Calculates the mean of the covariate.

9. **Create Results Directory**:
   ```
   set results_dir = $output_dir/test.${model}.3dMEMA_N=$nv.${condstr}.${cov}.results
   if ( ! -d $results_dir ) then
       mkdir $results_dir
   else
       rm -R $results_dir
   endif
   ```
   Creates a directory for the results, removing any existing directory with the same name.

10. **Run 3dMEMA**:
    ```
    uber_ttest.py -no_gui -save_script cmd.$model.MEMA.${condstr}.$cov \
        -program 3dMEMA \
        -mask $mask_dset \
        -set_name_A $condstr \
        -dsets_A $fn \
        -beta_A $beta_A -tstat_A $tstat_A \
        -results_dir $results_dir \
        -sids_A $sublist \
        -MM_options -jobs 20 \
            -max_zeros 0.25 \
            -covariates $covfn \
            -covariates_center psyrats = ${mean_psyrats} \
            -covariates_model center=different slope=same
    ```
    Executes the 3dMEMA command with the specified options and covariates.

#### Notes
- Ensure the paths to data directories are correct and adjusted if the script is moved.
- The covariate file should be formatted correctly with subject IDs and de-meaned covariates.






```markdown

### create_3dMEMA_test_bygroup_cov.sh Script Explanation

This script is designed to perform a group analysis using 3dMEMA (Mixed-Effects Multilevel Analysis) in AFNI with covariates. Below is a detailed explanation of the script's syntax and contents.

#### Usage
```
create_3dMEMA_test_bygroup_cov.sh <model> <contrast> <subfn1> <subfn2> <covfn>
```
- `<model>`: The HRF model used for this analysis.
- `<contrast>`: The condition or contrast of this analysis.
- `<subfn1>`: File containing list of subjects to be included in group 1.
- `<subfn2>`: File containing list of subjects to be included in group 2.
- `<covfn>`: Covariate file.

#### Example
```
create_3dMEMA_test_bygroup_cov.sh BLOCK words subject_list1.txt subject_list2.txt covariates.txt
```

#### Script Breakdown
1. **Input Validation**:
   ```
   if ( $#argv != 5 ) then
       echo "usage: $0 <model> <contrast> <subfn1> <subfn2> <covfn>"
       echo "example: $0 BLOCK words subject_list1.txt subject_list2.txt covariates.txt"
       exit 0
   endif
   ```
   Checks if the correct number of arguments is provided.

2. **Set Variables**:
   ```
   set model = $1
   set condstr = $2
   set sublistA = (`cat $3`)
   set sublistB = (`cat $4`)
   set ddir = ../../afni
   set output_dir = ../../afni/derivatives/group_glm
   set covfn = $5
   set cov = `echo $covfn:r`
   set gA = `echo $3 | sed 's/participants_\(.*\)\.txt/\1/'`
   set gB = `echo $4 | sed 's/participants_\(.*\)\.txt/\1/'`
   ```
   Sets the model, contrast, subject lists, data directories, and covariate variables.

3. **Create Subject Data Lists**:
   ```
   foreach sub ($sublistA)
       echo $ddir/{$sub}.results/stats.${sub}_REML+tlrc.HEAD >> tmpA
   end
   foreach sub ($sublistB)
       echo $ddir/{$sub}.results/stats.${sub}_REML+tlrc.HEAD >> tmpB
   end
   ```
   Creates lists of data files for subjects in both groups.

4. **Calculate Number of Subjects**:
   ```
   set nvA = (`cat tmpA | wc -l`)
   set nvB = (`cat tmpB | wc -l`)
   @ nvtotal = $nvA + $nvB
   ```
   Counts the number of subjects in each group and calculates the total number.

5. **Set Analysis Parameters**:
   ```
   set mask_dset = $output_dir/mask_intersection_up2date+tlrc
   set beta_A = `3dinfo -label2index "${condstr}#0_Coef" $ddir/${sub}.results/stats.${sub}_REML+tlrc.HEAD`
   set tstat_A = `3dinfo -label2index "${condstr}#0_Tstat" $ddir/${sub}.results/stats.${sub}_REML+tlrc.HEAD`
   set beta_B = `3dinfo -label2index "${condstr}#0_Coef" $ddir/${sub}.results/stats.${sub}_REML+tlrc.HEAD`
   set tstat_B = `3dinfo -label2index "${condstr}#0_Tstat" $ddir/${sub}.results/stats.${sub}_REML+tlrc.HEAD`
   ```
   Sets the mask dataset and retrieves beta and t-stat indices for both groups.

6. **Calculate Mean Covariates**:
   ```
   set ageA = `awk 'NR==FNR{a[$1]; next} ($1 in a) && ($2 != "n/a") {sum += $2; count++} END {if (count > 0) print sum/count; else print "n/a"}' $3 $covfn`
   set iqA = `awk 'NR==FNR{a[$1]; next} ($1 in a) && ($3 != "n/a") {sum += $3; count++} END {if (count > 0) print sum/count; else print "n/a"}' $3 $covfn`
   set ageB = `awk 'NR==FNR{a[$1]; next} ($1 in a) && ($2 != "n/a") {sum += $2; count++} END {if (count > 0) print sum/count; else print "n/a"}' $4 $covfn`
   set iqB = `awk 'NR==FNR{a[$1]; next} ($1 in a) && ($3 != "n/a") {sum += $3; count++} END {if (count > 0) print sum/count; else print "n/a"}' $4 $covfn`
   ```
   Calculates the mean age and IQ for subjects in both groups, ignoring 'n/a' values.

7. **Create Results Directory**:
   ```
   set results_dir = $output_dir/test.${model}.3dMEMA_N=${nvtotal}.${condstr}.$gB-$gA.$cov.results
   if ( ! -d $results_dir ) then
       mkdir $results_dir
   else
       rm -R $results_dir
   endif
   ```
   Creates a directory for the results, removing any existing directory with the same name.

8. **Run 3dMEMA**:
   ```
   uber_ttest.py -no_gui -save_script cmd.$model.MEMA.${condstr}.$cov.$gB-$gA \
       -program 3dMEMA \
       -mask $mask_dset \
       -set_name_A $gA \
       -dsets_A $fnA \
       -beta_A $beta_A -tstat_A $tstat_A \
       -sids_A $sublistA \
       -set_name_B $gB \
       -dsets_B $fnB \
       -beta_B $beta_A -tstat_B $tstat_A \
       -sids_B $sublistB \
       -results_dir $results_dir \
       -MM_options -jobs 20 \
           -max_zeros 0.25 \
       -covariates $covfn \
       -covariates_center age = $ageA $ageB iq = $iqA $iqB \
       -covariates_model center=different slope=same
   ```
   Executes the 3dMEMA command with the specified options and covariates.

#### Notes
- Ensure the paths to data directories are correct and adjusted if the script is moved.
- The covariate file should be formatted correctly with subject IDs and de-meaned covariates.
```

