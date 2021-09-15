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

	CORE_PATH=$1

	PROJECT=$2
	SM_TAG=$3

	SAMPLE_SHEET=$4
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
	SUBMIT_STAMP=$5

## replace generic annovar headers with descritive headers

START_FIX_ANNOVAR=`date '+%s'` # capture time process starts for wall clock tracking purposes.

	# construct command line

		CMD="sed -i -e '1s/vcf3/gnomAD_v3.1/'"
		CMD=${CMD}" -e '1s/vcf2/GB_Freq.MMdisease/'"
			CMD=${CMD}" -e '1s/vcf/GB_Freq.MMpolymorphisms/'"
			CMD=${CMD}" -e '1s/Otherinfo13/${SAMPLE_ID}/'"
			CMD=${CMD}" -e '1s/Otherinfo12/VCF_FORMAT/'"
			CMD=${CMD}" -e '1s/Otherinfo11/VCF_INFO/'"
			CMD=${CMD}" -e '1s/Otherinfo10/VCF_FILTER/'"
			CMD=${CMD}" -e '1s/Otherinfo9/VCF_QUAL/'"
			CMD=${CMD}" -e '1s/Otherinfo8/VCF_ALT/'"
			CMD=${CMD}" -e '1s/Otherinfo7/VCF_REF/'"
			CMD=${CMD}" -e '1s/Otherinfo6/VCF_ID/'"
			CMD=${CMD}" -e '1s/Otherinfo5/VCF_POS/'"
			CMD=${CMD}" -e '1s/Otherinfo4/VCF_CHROM/'"
			CMD=${CMD}" -e '1s/Otherinfo3/VCF_CUMULATIVE_AD/'"
			CMD=${CMD}" ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}/ANNOVAR_MT/${SM_TAG}.GRCh37_MT_multianno.txt"
		CMD=${CMD}" &&"
			CMD=${CMD}" mv -v ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}/ANNOVAR_MT/${SM_TAG}.GRCh37_MT_multianno*"
			CMD=${CMD}" ${CORE_PATH}/${PROJECT}/MT_OUTPUT/ANNOVAR_MT/"

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

END_FIX_ANNOVAR=`date '+%s'` # capture time process starts for wall clock tracking purposes.

# write out timing metrics to file

	echo ${SM_TAG}_${PROJECT},F01,FIX_ANNOVAR,${HOSTNAME},${START_FIX_ANNOVAR},${END_FIX_ANNOVAR} \
	>> ${CORE_PATH}/${PROJECT}/REPORTS/${PROJECT}.WALL.CLOCK.TIMES.csv

# exit with the signal from samtools bam to cram

	exit ${SCRIPT_STATUS}
