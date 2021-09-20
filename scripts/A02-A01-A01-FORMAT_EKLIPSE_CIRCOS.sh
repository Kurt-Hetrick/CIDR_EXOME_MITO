# ---qsub parameter settings---
# --these can be overrode at qsub invocation--

# tell sge to execute in bash
#$ -S /bin/bash

# tell sge that you are in the users current working directory
#$ -cwd

# tell sge to export the users environment variables
#$ -V

# tell sge to submit at this priority setting
#$ -p -10

# tell sge to output both stderr and stdout to the same file
#$ -j y

# export all variables, useful to find out what compute node the program was executed on

	set

	echo

# INPUT VARIABLES

	MITO_MAGICK_CONTAINER=$1
	CORE_PATH=$2

	PROJECT=$3
	SM_TAG=$4
	EKLIPSE_FORMAT_CIRCOS_PLOT_R_SCRIPT=$5
	EKLIPSE_CIRCOS_LEGEND=$6

	SAMPLE_SHEET=$7
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
	SUBMIT_STAMP=$8

## run alex's r script to generate plot for mt genome coverage

START_FIX_EKLIPSE_CIRCOS_PLOT=`date '+%s'` # capture time process starts for wall clock tracking purposes.

	# EKLIPSE WRITES AN OUTPUT FOLDER APPENDING A RANDOM HASH TO FOLDER NAME.
	# CREATE A VARIABLE CONTAINING THE FULL PATH FOR THE LATEST EKLIPSE RUN

		LATEST_EKLIPSE_OUTPUT_DIR=$(ls -trd ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}_MT/EKLIPSE/* | tail -n 1)

	# construct command line

		# fix/format eklipse textual output
		CMD="sed -e 's/,/\./g' -e 's/\"//g' -e 's/;/\t/g'"
			CMD=${CMD}" ${LATEST_EKLIPSE_OUTPUT_DIR}/eKLIPse_deletions.csv"
		CMD=${CMD}"  >| ${LATEST_EKLIPSE_OUTPUT_DIR}/${SM_TAG}_eKLIPse_deletions.tsv"
		CMD=${CMD}" &&"
		CMD=${CMD}" sed -e '1s/,/;/' -e 's/\"//g' -e 's/;/\t/g' -e 's/,/\./g'"
			CMD=${CMD}" ${LATEST_EKLIPSE_OUTPUT_DIR}/eKLIPse_genes.csv"
		CMD=${CMD}"  >| ${LATEST_EKLIPSE_OUTPUT_DIR}/${SM_TAG}_eKLIPse_genes.tsv"
		CMD=${CMD}" &&"
		# run alex wilson's r script to embed circos plot legend into eklipse circos plot
		CMD=${CMD}"singularity exec ${MITO_MAGICK_CONTAINER} Rscript"
			CMD=${CMD}" ${EKLIPSE_FORMAT_CIRCOS_PLOT_R_SCRIPT}"
			# eklipse circos plot legend
			CMD=${CMD}" ${EKLIPSE_CIRCOS_LEGEND}"
			# input file
			CMD=${CMD}" ${LATEST_EKLIPSE_OUTPUT_DIR}/eKLIPse_${SM_TAG}.png"
			# sample name
			CMD=${CMD}" ${SM_TAG}"
		# output directory
		CMD=${CMD}" ${LATEST_EKLIPSE_OUTPUT_DIR}"
		# remove original eklipse output files
		CMD=${CMD}" &&"
			CMD=${CMD}" rm -rvf ${LATEST_EKLIPSE_OUTPUT_DIR}/eKLIPse_${SM_TAG}.png"
			CMD=${CMD}" ${LATEST_EKLIPSE_OUTPUT_DIR}/eKLIPse_deletions.csv"
			CMD=${CMD}" ${LATEST_EKLIPSE_OUTPUT_DIR}/eKLIPse_genes.csv"
		# move fixed files to project level directory
		CMD=${CMD}" &&"
			CMD=${CMD}" mv -v ${LATEST_EKLIPSE_OUTPUT_DIR}/{${SM_TAG}_eKLIPse_deletions.tsv,${SM_TAG}_eKLIPse_genes.tsv,${SM_TAG}_circos.png}"
			CMD=${CMD}" ${CORE_PATH}/${PROJECT}/MT_OUTPUT/EKLIPSE"

	# write command line to file and execute the command line

		echo ${CMD} >> ${CORE_PATH}/${PROJECT}/COMMAND_LINES/${SM_TAG}_command_lines.txt
		echo >> ${CORE_PATH}/${PROJECT}/COMMAND_LINES/${SM_TAG}_command_lines.txt
		echo ${CMD} | bash

	# check the exit signal at this point.

		SCRIPT_STATUS=`echo $?`

		# if exit does not equal 0 then exit with whatever the exit signal is at the end.
		# also write to file that this job failed

			if [ "${SCRIPT_STATUS}" -ne 0 ]
				then
					echo ${SM_TAG} ${HOSTNAME} ${JOB_NAME} ${USER} ${SCRIPT_STATUS} ${SGE_STDERR_PATH} \
					>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt
					exit ${SCRIPT_STATUS}
			fi

END_FIX_EKLIPSE_CIRCOS_PLOT=`date '+%s'` # capture time process starts for wall clock tracking purposes.

# write out timing metrics to file

	echo ${SM_TAG}_${PROJECT},C01,FIX_EKLIPSE_CIRCOS_PLOT,${HOSTNAME},${START_FIX_EKLIPSE_CIRCOS_PLOT},${END_FIX_EKLIPSE_CIRCOS_PLOT} \
	>> ${CORE_PATH}/${PROJECT}/REPORTS/${PROJECT}.WALL.CLOCK.TIMES.csv

# exit with the signal

	exit ${SCRIPT_STATUS}
