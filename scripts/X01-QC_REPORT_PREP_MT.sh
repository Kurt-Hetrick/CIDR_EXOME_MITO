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
	SM_TAG=$4

# next script will cat everything together and add the header.
# dirty validations count NF, if not X, then say haha you suck try again and don't write to cat file.

######################################################################################
##### Grabbing the BAM/CRAM header (for RG ID,PU,LB,etc) #############################
######################################################################################
######################################################################################
##### THIS IS THE HEADER #############################################################
##### "SM_TAG","PROJECT","PLATFORM_UNIT","LIBRARY_NAME" ##############################
##### "LIBRARY_PLATE","LIBRARY_WELL","LIBRARY_ROW","LIBRARY_COLUMN" ##################
##### "HYB_PLATE","HYB_WELL","HYB_ROW","HYB_COLUMN" ##################################
######################################################################################

	if [ -f ${CORE_PATH}/${PROJECT}/REPORTS/RG_HEADER/${SM_TAG}.RG_HEADER.txt ]
		then
			cat ${CORE_PATH}/${PROJECT}/REPORTS/RG_HEADER/${SM_TAG}.RG_HEADER.txt \
				| singularity exec ${ALIGNMENT_CONTAINER} datamash \
					-s \
					-g 2,1 \
					collapse 3 \
					unique 4 \
					unique 5 \
					unique 6 \
					unique 7 \
					unique 8 \
					unique 9 \
					unique 10 \
					unique 11 \
					unique 12 \
				| sed 's/,/;/g' \
				| singularity exec ${ALIGNMENT_CONTAINER} datamash \
					transpose \
			>| ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}_MT/${SM_TAG}.QC_REPORT_TEMP_MT.txt

		elif [[ ! -f ${CORE_PATH}/${PROJECT}/REPORTS/RG_HEADER/${SM_TAG}.RG_HEADER.txt && \
			-f ${CORE_PATH}/${PROJECT}/CRAM/${SM_TAG}.cram ]];
			then

			# grab field number for SM_TAG

				SM_FIELD=(`singularity exec ${ALIGNMENT_CONTAINER} samtools \
					view -H \
				${CORE_PATH}/${PROJECT}/CRAM/${SM_TAG}.cram \
					| grep -m 1 ^@RG \
					| sed 's/\t/\n/g' \
					| cat -n \
					| sed 's/^ *//g' \
					| awk '$2~/^SM:/ {print $1}'`)

			# grab field number for PLATFORM_UNIT_TAG

				PU_FIELD=(`singularity exec ${ALIGNMENT_CONTAINER} samtools \
					view -H \
				${CORE_PATH}/${PROJECT}/CRAM/${SM_TAG}.cram \
					| grep -m 1 ^@RG \
					| sed 's/\t/\n/g' \
					| cat -n \
					| sed 's/^ *//g' \
					| awk '$2~/^PU:/ {print $1}'`)

			# grab field number for LIBRARY_TAG

				LB_FIELD=(`singularity exec ${ALIGNMENT_CONTAINER} samtools \
					view -H \
				${CORE_PATH}/${PROJECT}/CRAM/${SM_TAG}.cram \
					| grep -m 1 ^@RG \
					| sed 's/\t/\n/g' \
					| cat -n \
					| sed 's/^ *//g' \
					| awk '$2~/^LB:/ {print $1}'`)

			# # grab field number for PROGRAM_TAG

				# 	PG_FIELD=(`singularity exec ${ALIGNMENT_CONTAINER} samtools \
				# 		view -H \
				# 	${CORE_PATH}/${PROJECT}/CRAM/${SM_TAG}.cram \
				# 		| grep -m 1 ^@RG \
				# 		| sed 's/\t/\n/g' \
				# 		| cat -n \
				# 		| sed 's/^ *//g' \
				# 		| awk '$2~/^PG:/ {print $1}'`)

			# Now grab the header and format
				# fill in empty fields with NA thing (for loop in awk) is a lifesaver
				# https://unix.stackexchange.com/questions/53448/replacing-missing-value-blank-space-with-zero

				singularity exec ${ALIGNMENT_CONTAINER} samtools \
					view -H \
				${CORE_PATH}/${PROJECT}/CRAM/${SM_TAG}.cram \
					| grep ^@RG \
					| awk \
						-v SM_FIELD="$SM_FIELD" \
						-v PU_FIELD="$PU_FIELD" \
						-v LB_FIELD="$LB_FIELD" \
						'BEGIN {OFS="\t"} {split($SM_FIELD,SMtag,":"); split($PU_FIELD,PU,":"); split($LB_FIELD,Library,":"); split(Library[2],Library_Unit,"_"); \
						print "'$PROJECT'",SMtag[2],PU[2],Library[2],Library_Unit[1],Library_Unit[2],substr(Library_Unit[2],1,1),substr(Library_Unit[2],2,2),\
						Library_Unit[3],Library_Unit[4],substr(Library_Unit[4],1,1),substr(Library_Unit[4],2,2)}' \
					| awk 'BEGIN { FS = OFS = "\t" } { for(i=1; i<=NF; i++) if($i ~ /^ *$/) $i = "NA" }; 1' \
					| singularity exec ${ALIGNMENT_CONTAINER} datamash \
						-s \
						-g 2,1 \
						collapse 3 \
						unique 4 \
						unique 5 \
						unique 6 \
						unique 7 \
						unique 8 \
						unique 9 \
						unique 10 \
						unique 11 \
						unique 12 \
					| sed 's/,/;/g' \
					| singularity exec ${ALIGNMENT_CONTAINER} datamash \
						transpose \
				>| ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}_MT/${SM_TAG}.QC_REPORT_TEMP_MT.txt
		else
			echo -e "$PROJECT\t$SM_TAG\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA\tNA" \
				| singularity exec ${ALIGNMENT_CONTAINER} datamash \
					transpose \
			>| ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}_MT/${SM_TAG}.QC_REPORT_TEMP_MT.txt
	fi

########################################################################################################
##### HYBRIDIZATION SELECTION REPORT ###################################################################
########################################################################################################
##### THIS IS THE HEADER ###############################################################################
##### "MT_MEAN_TARGET_CVG","MT_MEDIAN_TARGET_CVG","MT_MAX_TARGET_CVG","MT_MIN_TARGET_CVG" ##############
##### "MT_PCT_TARGET_BASES_10X","MT_PCT_TARGET_BASES_20X","MT_PCT_TARGET_BASES_30X" ####################
##### "MT_PCT_TARGET_BASES_40X","MT_PCT_TARGET_BASES_50X","MT_PCT_TARGET_BASES_100X" ###################
##### "PCT_TARGET_BASES_250X","PCT_TARGET_BASES_500X","PCT_TARGET_BASES_1000X" #########################
##### "PCT_TARGET_BASES_2500X","PCT_TARGET_BASES_5000X","PCT_TARGET_BASES_10000X" ######################
##### "MT_TOTAL_READS","MT_PF_UNIQUE_READS","MT_PCT_PF_UQ_READS","MT_PF_UQ_READS_ALIGNED" ##############
##### "MT_PCT_PF_UQ_READS_ALIGNED","MT_PF_BASES","MT_PF_BASES_ALIGNED","MT_PF_UQ_BASES_ALIGNED" ########
##### "MT_ON_TARGET_BASES","MT_PCT_USABLE_BASES_ON_TARGET" #############################################
##### "MT_PCT_EXC_DUPE","MT_PCT_EXC_ADAPTER","MT_PCT_EXC_MAPQ","MT_PCT_EXC_BASEQ","MT_PCT_EXC_OVERLAP" #
##### "MT_MEAN_BAIT_CVG,"MT_PCT_USABLE_BASES_ON_BAIT" ##################################################
##### "MT_AT_DROPOUT","MT_GC_DROPOUT","MT_THEORETICAL_HET_SENSITIVITY","MT_HET_SNP_Q" ##################
########################################################################################################

	# this will take when there are no reads in the file...but i don't think that it will handle when there are reads, but none fall on target
	# the next time i that happens i'll fix this to handle it.

		if [[ ! -f ${CORE_PATH}/${PROJECT}/MT_OUTPUT/COLLECTHSMETRICS_MT/${SM_TAG}.output.metrics ]]
		then
			echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				transpose \
			>> ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}_MT/${SM_TAG}.QC_REPORT_TEMP_MT.txt

		else

			awk 'BEGIN {FS="\t";OFS="\t"} \
				NR==8 \
				{print $34,$35,$36,$37,\
					$48*100,$49*100,$50*100,$51*100,$52*100,$53*100,\
					$54*100,$55*100,$56*100,$57*100,$58*100,$59*100,\
					$23,$26,$32*100,$27,$33*100,$25,$28,$29,$30,$12,\
					$39*100,$40*100,$41*100,$42*100,$43*100,\
					$10,$11*100,$63,$64,$65*100,$66}' \
			${CORE_PATH}/${PROJECT}/MT_OUTPUT/COLLECTHSMETRICS_MT/${SM_TAG}.output.metrics \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				transpose \
			>> ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}_MT/${SM_TAG}.QC_REPORT_TEMP_MT.txt

			## CODE BELOW WAS FOR NORMAL EXOMES, WITH EXCEPTIONS FOR BAD DATA...
			## NOT SURE WHAT IS GOING TO HAPPEN WHEN RUNNING WITH MT ONLY DATA AT THE MOMENT.
			## SO KEEPING THIS COMMENTED OUT CODE HERE FOR REFERENCE JUST IN CASE FOR THE TIME BEING.

				# awk 'BEGIN {FS="\t";OFS="\t"} \
				# 	NR==8 \
				# 	{if ($12=="?"&&$44=="") \
				# 		print $2,$1,$3,$4,"NaN",($14/1000000000),"NaN","NaN",$22,$23,$24,$25,"NaN",$29,"NaN","NaN","NaN","NaN",$39,$40,$41,$42,$51,$52,$53,$54 ; \
				# 	else if ($12!="?"&&$44=="") \
				# 		print $2,$1,$3,$4,$12*100,($14/1000000000),$19*100,$21,$22,$23,$24,$25,$26*100,$29*100,$31*100,$32*100,$33*100,$34*100,$39*100,$40*100,$41*100,$42*100,$51,$52,$53,$54 ; \
				# 	else print $2,$1,$3,$4,$12*100,($14/1000000000),$19*100,$21,$22,$23,$24,$25,$26*100,$29*100,$31*100,$32*100,$33*100,$34*100,$39*100,$40*100,$41*100,$42*100,$51,$52,$53,$54}' \
				# ${CORE_PATH}/${PROJECT}/REPORTS/HYB_SELECTION/${SM_TAG}_hybridization_selection_metrics.txt \
				# | singularity exec ${ALIGNMENT_CONTAINER} datamash \
				# 	transpose \
				# >> ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}_MT/${SM_TAG}.QC_REPORT_TEMP_MT.txt
			fi

#######################################################################################################
##### GRAB VCF METRICS MUTECT2 MT VCF AFTER FILTERING AND MASKING #####################################
#######################################################################################################
##### THIS IS THE HEADER ##############################################################################
##### MT_COUNT_PASS_BIALLELIC_SNV,MT_COUNT_FILTERED_SNV,MT_PERCENT_PASS_SNV_SNP138 ####################
##### MT_COUNT_PASS_BIALLELIC_INDEL,MT_COUNT_FILTERED_INDEL,MT_PERCENT_PASS_INDEL_SNP138 ##############
##### MT_COUNT_PASS_MULTIALLELIC_SNV,MT_COUNT_PASS_MULTIALLELIC_SNV_SNP138 ############################
##### MT_COUNT_PASS_COMPLEX_INDEL,MT_COUNT_PASS_COMPLEX_INDEL_SNP138 ##################################
##### MT_SNP_REFERENCE_BIAS,MT_PCT_GQ0_VARIANTS,MT_COUNT_GQ0_VARIANTS #################################
#######################################################################################################

	# since I don't have have any examples of what failures look like, I can't really build that in

	if [[ ! -f ${CORE_PATH}/${PROJECT}/MT_OUTPUT/VCF_METRICS_MT/${SM_TAG}_MUTECT2_MT.variant_calling_detail_metrics.txt ]]
		then
			echo -e NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN'\t'NaN \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				transpose \
			>> ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}_MT/${SM_TAG}.QC_REPORT_TEMP_MT.txt

		else
			awk 'BEGIN {FS="\t";OFS="\t"} \
				NR==8 \
				{print $6,$9,$10*100,$13,$15,$16*100,$20,$21,$22,$23,$24,$3,$4}' \
			${CORE_PATH}/${PROJECT}/MT_OUTPUT/VCF_METRICS_MT/${SM_TAG}_MUTECT2_MT.variant_calling_detail_metrics.txt \
			| singularity exec ${ALIGNMENT_CONTAINER} datamash \
				transpose \
			>> ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}_MT/${SM_TAG}.QC_REPORT_TEMP_MT.txt
	fi

#########################################################
##### COUNT HOW MANY DELETIONS DETECTED BY EKLIPLSE #####
#########################################################
##### THIS IS THE HEADER ################################
##### MT_COUNT_EKLIPSE_DEL ##############################
#########################################################

	if [[ ! -f $CORE_PATH/$PROJECT/MT_OUTPUT/EKLIPSE/${SM_TAG}_eKLIPse_deletions.tsv ]]
		then
			echo -e NaN \
			>> ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}_MT/${SM_TAG}.QC_REPORT_TEMP_MT.txt

		else
			awk 'BEGIN {OFS="\t"} END {print NR-1}' \
				$CORE_PATH/$PROJECT/MT_OUTPUT/EKLIPSE/${SM_TAG}_eKLIPse_deletions.tsv
			>> ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}_MT/${SM_TAG}.QC_REPORT_TEMP_MT.txt
	fi

##############################
# tranpose from rows to list #
##############################

	cat ${CORE_PATH}/${PROJECT}/TEMP/${SM_TAG}_MT/${SM_TAG}.QC_REPORT_TEMP_MT.txt \
		| singularity exec ${ALIGNMENT_CONTAINER} datamash \
			transpose \
	>| ${CORE_PATH}/${PROJECT}/MT_OUTPUT/QC_REPORT_PREP_MT/${SM_TAG}.QC_REPORT_PREP_MT.txt

#######################################
# check the exit signal at this point #
#######################################

	SCRIPT_STATUS=`echo $?`
