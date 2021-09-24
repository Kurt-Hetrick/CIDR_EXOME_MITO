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

	ALIGNMENT_CONTAINER=$1
	CORE_PATH=$2

	PROJECT=$3

	SCRIPT_DIR=$4
	SEND_TO=$5
	SUBMITTER_ID=$6
		PERSON_NAME=`getent passwd | awk 'BEGIN {FS=":"} $1=="'${SUBMITTER_ID}'" {print $5}'`
	THREADS=$7

	SAMPLE_SHEET=$8
		SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)
		SAMPLE_SHEET_FILE_NAME=$(basename ${SAMPLE_SHEET})
	SUBMIT_STAMP=$9

		TIMESTAMP=`date '+%F.%H-%M-%S'`

#################################################################################
# combining all the individual qc reports for the project and adding the header #
#################################################################################

	cat ${CORE_PATH}/${PROJECT}/MT_OUTPUT/QC_REPORT_PREP_MT/*.QC_REPORT_PREP_MT.txt \
		| sort -k 1,1 \
		| awk 'BEGIN {print "SM_TAG",\
			"PROJECT",\
			"PLATFORM_UNIT",\
			"LIBRARY_NAME",\
			"LIBRARY_PLATE",\
			"LIBRARY_WELL",\
			"LIBRARY_ROW",\
			"LIBRARY_COLUMN",\
			"HYB_PLATE",\
			"HYB_WELL",\
			"HYB_ROW",\
			"HYB_COLUMN",\
			"MT_MEAN_TARGET_CVG",\
			"MT_MEDIAN_TARGET_CVG",\
			"MT_MAX_TARGET_CVG",\
			"MT_MIN_TARGET_CVG",\
			"MT_PCT_TARGET_BASES_10X",\
			"MT_PCT_TARGET_BASES_20X",\
			"MT_PCT_TARGET_BASES_30X",\
			"MT_PCT_TARGET_BASES_40X",\
			"MT_PCT_TARGET_BASES_50X",\
			"MT_PCT_TARGET_BASES_100X",\
			"MT_PCT_TARGET_BASES_250X",\
			"MT_PCT_TARGET_BASES_500X",\
			"MT_PCT_TARGET_BASES_1000X",\
			"MT_PCT_TARGET_BASES_2500X",\
			"MT_PCT_TARGET_BASES_5000X",\
			"MT_PCT_TARGET_BASES_10000X",\
			"MT_TOTAL_READS",\
			"MT_PF_UNIQUE_READS",\
			"MT_PCT_PF_UQ_READS",\
			"MT_PF_UQ_READS_ALIGNED",\
			"MT_PCT_PF_UQ_READS_ALIGNED",\
			"MT_PF_BASES",\
			"MT_PF_BASES_ALIGNED",\
			"MT_PF_UQ_BASES_ALIGNED",\
			"MT_ON_TARGET_BASES",\
			"MT_PCT_USABLE_BASES_ON_TARGET",\
			"MT_PCT_EXC_DUPE",\
			"MT_PCT_EXC_ADAPTER",\
			"MT_PCT_EXC_MAPQ",\
			"MT_PCT_EXC_BASEQ",\
			"MT_PCT_EXC_OVERLAP",\
			"MT_MEAN_BAIT_CVG",\
			"MT_PCT_USABLE_BASES_ON_BAIT",\
			"MT_AT_DROPOUT",\
			"MT_GC_DROPOUT",\
			"MT_THEORETICAL_HET_SENSITIVITY",\
			"MT_HET_SNP_Q",\
			"MT_COUNT_PASS_BIALLELIC_SNV",\
			"MT_COUNT_FILTERED_SNV",\
			"MT_PERCENT_PASS_SNV_SNP138",\
			"MT_COUNT_PASS_BIALLELIC_INDEL",\
			"MT_COUNT_FILTERED_INDEL",\
			"MT_PERCENT_PASS_INDEL_SNP138",\
			"MT_COUNT_PASS_MULTIALLELIC_SNV",\
			"MT_COUNT_PASS_MULTIALLELIC_SNV_SNP138",\
			"MT_COUNT_PASS_COMPLEX_INDEL",\
			"MT_COUNT_PASS_COMPLEX_INDEL_SNP138",\
			"MT_PCT_GQ0_VARIANTS",\
			"MT_COUNT_GQ0_VARIANTS",\
			"MT_COUNT_EKLIPSE_DEL"} \
			{print $0}' \
		| sed 's/ /,/g' \
		| sed 's/\t/,/g' \
	>| ${CORE_PATH}/${PROJECT}/MT_OUTPUT/QC_REPORT_MT/${PROJECT}.QC_REPORT_MT.${TIMESTAMP}.csv

###########################################################################
##### Make a QC report for just the samples in this batch per project #####
###########################################################################

	SAMPLE_SHEET_NAME=$(basename ${SAMPLE_SHEET} .csv)

	# For each project in the sample sheet make a qc report containing only those samples in sample sheet.
	# Create the headers for the new files using the header from the all sample sheet.

		head -n 1 ${CORE_PATH}/${PROJECT}/MT_OUTPUT/QC_REPORT_MT/${PROJECT}.QC_REPORT_MT.${TIMESTAMP}.csv \
		>| ${CORE_PATH}/${PROJECT}/MT_OUTPUT/QC_REPORT_MT/${SAMPLE_SHEET_NAME}.QC_REPORT_MT.csv

		CREATE_SAMPLE_ARRAY ()
		{
			SAMPLE_ARRAY=(`awk 1 ${SAMPLE_SHEET} \
				| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' \
				| awk 'BEGIN {FS=","} \
					$8=="'${SM_TAG}'" \
					{print $8}' \
				| sort \
				| uniq`)

			#  8  SM_Tag=sample ID

				SM_TAG=${SAMPLE_ARRAY[0]}
		}

		for SM_TAG in $(awk 'BEGIN {FS=","} \
							$1=="'${PROJECT}'" \
							{print $8}' \
						${SAMPLE_SHEET} \
							| sort \
							| uniq );
		do
			CREATE_SAMPLE_ARRAY

			cat ${CORE_PATH}/${PROJECT}/MT_OUTPUT/QC_REPORT_PREP_MT/${SM_TAG}.QC_REPORT_PREP_MT.txt \
			>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}.QC_REPORT_MT.${TIMESTAMP}.txt
		done

		sed 's/\t/,/g' ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}.QC_REPORT_MT.${TIMESTAMP}.txt \
		>> ${CORE_PATH}/${PROJECT}/MT_OUTPUT/QC_REPORT_MT/${SAMPLE_SHEET_NAME}.QC_REPORT_MT.csv

##############################################################
##### CLEAN-UP OR NOT DEPENDING ON IF JOBS FAILED OR NOT #####
##############################################################

	# CREATE SAMPLE ARRAY, USED DURING PROJECT CLEANUP

		CREATE_SAMPLE_ARRAY_FOR_FILE_CLEANUP ()
		{
			SAMPLE_ARRAY=(`awk 1 ${SAMPLE_SHEET} \
				| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' \
				| awk 'BEGIN {FS=",";OFS="\t"} \
					$1=="'${PROJECT}'"&&$8=="'${SM_TAG}'" \
					{print $1,$8}' \
				| sort \
					-k 1,1 \
					-k 2,2 \
				| uniq`)

				#  1  Project=the Seq Proj folder name

					PROJECT_FILE_CLEANUP=${SAMPLE_ARRAY[0]}

				#  8  SM_Tag=sample ID

					SM_TAG_FILE_CLEANUP=${SAMPLE_ARRAY[1]}
		}

# IF THERE ARE NO FAILED JOBS THEN DELETE TEMP FILES STARTING WITH SM_TAG OR PLATFORM_UNIT
# ELSE; DON'T DELETE ANYTHING BUT SUMMARIZE WHAT FAILED.

	if [[ ! -f ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt ]]
		then
			for SM_TAG in $(awk 'BEGIN {FS=","} \
								$1=="'${PROJECT}'" \
								{print $8}' \
							${SAMPLE_SHEET} \
								| sort \
								| uniq)
			do
				CREATE_SAMPLE_ARRAY_FOR_FILE_CLEANUP

				rm -rf ${CORE_PATH}/${PROJECT_FILE_CLEANUP}/TEMP/${SM_TAG_FILE_CLEANUP}_MT | bash

			done

			printf "\n${PERSON_NAME} Was The Submitter\n\n \
				REPORTS ARE AT:\n ${CORE_PATH}/${PROJECT}/MT_OUTPUT/QC_REPORT_MT\n\n \
				BATCH QC REPORT:\n ${SAMPLE_SHEET_NAME}.QC_REPORT_MT.csv\n\n \
				NO JOBS FAILED: TEMP FILES DELETED" \
				| mail -s "${SAMPLE_SHEET} FOR ${PROJECT} has finished processing SUBMITTER_CIDR_Exome_Mito.sh" \
					${SEND_TO}

		else
			# CONSTRUCT MESSAGE TO BE SENT SUMMARIZING THE FAILED JOBS
				printf "SO BAD THINGS HAPPENED AND THE TEMP FILES WILL NOT BE DELETED FOR:\n" \
					>| ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

				printf "${SAMPLE_SHEET}\n" \
					>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

				printf "FOR PROJECT:\n" \
					>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

				printf "${PROJECT}\n" \
					>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

				printf "SOMEWHAT FULL LISTING OF FAILED JOBS ARE HERE:\n" \
					>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

				printf "${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt\n" \
					>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

				printf "###################################################################\n" \
					>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

				printf "BELOW ARE THE SAMPLES AND THE MINIMUM NUMBER OF JOBS THAT FAILED PER SAMPLE:\n" \
					>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

				printf "###################################################################\n" \
					>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

				egrep -v CONCORDANCE ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt \
					| awk 'BEGIN {OFS="\t"} \
						NF==6 \
						{print $1}' \
					| sort \
					| singularity exec $ALIGNMENT_CONTAINER datamash \
						-g 1 \
						count 1 \
				>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

				printf "###################################################################\n" \
					>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

				printf "FOR THE SAMPLES THAT HAVE FAILED JOBS, THIS IS ROUGHLY THE FIRST JOB THAT FAILED FOR EACH SAMPLE:\n" \
					>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

				printf "###################################################################\n" \
					>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

				printf "SM_TAG NODE JOB_NAME USER EXIT LOG_FILE\n" | sed 's/ /\t/g' \
						>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

			for sample in $(awk 'BEGIN {OFS="\t"} \
								NF==6 \
								{print $1}' \
							${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt \
								| sort \
								| uniq);
			do
				awk '$1=="'${sample}'" \
					{print $0 "\n" "\n"}' \
				${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_ERRORS.txt \
					| head -n 1 \
				>> ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt
			done

			sleep 2s

			mail -s "FAILED JOBS: ${PROJECT}: ${SAMPLE_SHEET_FILE_NAME}" \
			$SEND_TO \
			< ${CORE_PATH}/${PROJECT}/TEMP/${SAMPLE_SHEET_NAME}_${SUBMIT_STAMP}_EMAIL_SUMMARY.txt

	fi

	sleep 2s

####################################################
##### Clean up the Wall Clock minutes tracker. #####
####################################################

	# clean up records that are malformed
	# only keep jobs that ran longer than 3 minutes

		awk 'BEGIN {FS=",";OFS=","} \
			$1~/^[A-Z 0-9]/&&$2!=""&&$3!=""&&$4!=""&&$5!=""&&$6!=""&&$7==""&&$5!~/A-Z/&&$6!~/A-Z/&&($6-$5)>180 \
			{print $1,$2,$3,$4,$5,$6,($6-$5)/60,\
			strftime("%F",$5),\
			strftime("%F",$6),\
			strftime("%F.%H-%M-%S",$5),\
			strftime("%F.%H-%M-%S",$6)}' \
		${CORE_PATH}/${PROJECT}/REPORTS/${PROJECT}.WALL.CLOCK.TIMES.csv \
			| sed 's/_'"${PROJECT}"'/,'"${PROJECT}"'/g' \
			| awk 'BEGIN {print "SAMPLE,PROJECT,TASK_GROUP,TASK,HOST,EPOCH_START,EPOCH_END,WC_MIN,START_DATE,END_DATE,TIMESTAMP_START,TIMESTAMP_END"} \
				{print $0}' \
		>| ${CORE_PATH}/${PROJECT}/REPORTS/${PROJECT}.WALL.CLOCK.TIMES.FIXED.csv

# put a stamp as to when the run was done

	echo MT pipeline finished at `date` >> ${CORE_PATH}/${PROJECT}/REPORTS/PROJECT_START_END_TIMESTAMP.txt

# this is black magic that I don't know if it really helps. was having problems with getting the emails to send so I put a little delay in here.

	sleep 2s
