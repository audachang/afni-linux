#!/usr/bin/tcsh -xef

set curdir = `pwd`


cd ../../ #change directory to the project root (~/fmri_course_personal_project)

# Step 1: Install the dataset (skipped if the ds001499 folder is already there)
if (! -d ds001499) then
	datalad install https://github.com/OpenNeuroDatasets/ds001499.git
endif

# Step 2: Navigate to the dataset directory
cd ds001499

# Step 3: Fetch the data
#datalad get derivatives/spm
datalad get derivatives/freesurfer

# Step 4: Verify the data is accessible
ls derivatives/spm

#change back to code directory

cd $curdir 



