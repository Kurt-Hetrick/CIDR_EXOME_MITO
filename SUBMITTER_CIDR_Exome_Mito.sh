#!/usr/bin/env bash

module load sge

###################
# INPUT VARIABLES #
###################

	SAMPLE_SHEET=$1

	PRIORITY=$2 # optional. how high you want the tasks to have when submitting.
		# if no 3rd argument present then the default is -9.

			if [[ ! ${PRIORITY} ]]
				then
				PRIORITY="-16"
			fi

	QUEUE_LIST=$3 # optional. the queues that you want to submit to.
		# if you want to set this then you need to set the 3rd argument as well (even to the default)
		# if no 4th argument present then the default is everything except the following
		## all.q|cgc.q|rhel7.q|qtest.q|bigdata.q|uhoh.q|prod.q|rnd.q

			if [[ ! ${QUEUE_LIST} ]]
				then
				QUEUE_LIST=$(qstat -f -s r \
					| egrep -v "^[0-9]|^-|^queue|^ " \
					| cut -d @ -f 1 \
					| sort \
					| uniq \
					| egrep -v "all.q|cgc.q|rhel7.q|qtest.q|bigdata.q|uhoh.q|prod.q|rnd.q" \
					| datamash collapse 1 \
					| awk '{print $1}')
			fi

	THREADS=$4 # optional. how many cpu processors you want to use for programs that are multi-threaded
		# if you want to set this then you need to set the 4th argument as well (even to the default)
		# if no 5th argument present then the default is 6

			if [[ ! ${THREADS} ]]
				then
				THREADS="4"
			fi

########################################################################
# CHANGE SCRIPT DIR TO WHERE YOU HAVE HAVE THE SCRIPTS BEING SUBMITTED #
########################################################################

	SUBMITTER_SCRIPT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

	SCRIPT_DIR="${SUBMITTER_SCRIPT_PATH}/scripts"

##################
# CORE VARIABLES #
##################

	## This will always put the current working directory in front of any directory for PATH
	## added /bin for RHEL6

		export PATH=".:${PATH}:/bin"

	# where the input/output sequencing data will be located.

		CORE_PATH="/mnt/research/active"

	# Directory where NovaSeqa runs are located.

		NOVASEQ_REPO="/mnt/instrument_files/novaseq"

	# used for tracking in the read group header of the cram file

		PIPELINE_VERSION=`git --git-dir=${SCRIPT_DIR}/../.git --work-tree=${SCRIPT_DIR}/.. log --pretty=format:'%h' -n 1`

	# load gcc for programs like verifyBamID
	## this will get pushed out to all of the compute nodes since I specify env var to pushed out with qsub

		module load gcc/7.2.0

	# explicitly setting this b/c not everybody has had the $HOME directory transferred and I'm not going to through
	# and figure out who does and does not have this set correctly

		umask 0007

	# SUBMIT TIMESTAMP

		SUBMIT_STAMP=`date '+%s'`

	# SUBMITTER_ID

		SUBMITTER_ID=`whoami`

	# grab email addy

		SEND_TO=$(cat ${SCRIPT_DIR}/../email_lists.txt)

	# grab submitter's name

		PERSON_NAME=`getent passwd | awk 'BEGIN {FS=":"} $1=="'${SUBMITTER_ID}'" {print $5}'`

	# bind the host file system /mnt to the singularity container. in case I use it in the submitter.

		export SINGULARITY_BINDPATH="/mnt:/mnt"

	# QSUB ARGUMENTS LIST
		# set shell on compute node
		# start in current working directory
		# transfer submit node env to compute node
		# set SINGULARITY BINDPATH
		# set queues to submit to
		# set priority
		# combine stdout and stderr logging to same output file

			QSUB_ARGS="-S /bin/bash" \
				QSUB_ARGS=${QSUB_ARGS}" -cwd" \
				QSUB_ARGS=${QSUB_ARGS}" -V" \
				QSUB_ARGS=${QSUB_ARGS}" -v SINGULARITY_BINDPATH=/mnt:/mnt" \
				QSUB_ARGS=${QSUB_ARGS}" -p ${PRIORITY}" \
				QSUB_ARGS=${QSUB_ARGS}" -j y"

		# ${QSUB_ARGS} WILL BE A GENERAL BLOCK APPLIED TO ALL JOBS
		# BELOW ARE TIMES WHEN WHEN A QSUB ARGUMENT IS ADDED OR CHANGED.

			# qsub args for magick package in R (imgmagick_merge.r)
			# image packages will use all cpu threads by default.
			# to configure set env variable to desired thread count.

				IMGMAGICK_QSUB_ARGS=${QSUB_ARGS}" -v MAGICK_THREAD_LIMIT=${THREADS}"

			# DEFINE STANDARD LIST OF SERVERS TO SUBMIT TO.
			# THIS IS DEFINED AS AN INPUT ARGUMENT VARIABLE TO THE PIPELINE
				# DEFAULT: everything excluding all.q|cgc.q|rhel7.q|qtest.q|bigdata.q|uhoh.q|prod.q|rnd.q

				STANDARD_QUEUE_QSUB_ARG=" -q ${QUEUE_LIST}"

#####################
# PIPELINE PROGRAMS #
#####################

	ALIGNMENT_CONTAINER="/mnt/research/tools/LINUX/00_GIT_REPO_KURT/CIDR_EXOME_MITO/containers/ddl_ce_control_align-0.0.4.simg" # just used for the end tasks wrap up (datamash,parallel).
		# contains the following software and is on Ubuntu 16.04.5 LTS
			# gatk 4.0.11.0 (base image). also contains the following.
				# Python 3.6.2 :: Continuum Analytics, Inc.
					# samtools 0.1.19
					# bcftools 0.1.19
					# bedtools v2.25.0
					# bgzip 1.2.1
					# tabix 1.2.1
					# samtools, bcftools, bgzip and tabix will be replaced with newer versions.
					# R 3.2.5
						# dependencies = c("gplots","digest", "gtable", "MASS", "plyr", "reshape2", "scales", "tibble", "lazyeval")    # for ggplot2
						# getopt_1.20.0.tar.gz
						# optparse_1.3.2.tar.gz
						# data.table_1.10.4-2.tar.gz
						# gsalib_2.1.tar.gz
						# ggplot2_2.2.1.tar.gz
					# openjdk version "1.8.0_181"
					# /gatk/gatk.jar -> /gatk/gatk-package-4.0.11.0-local.jar
			# added
				# picard.jar 2.17.0 (as /gatk/picard.jar)
				# samblaster-v.0.1.24
				# sambamba-0.6.8
				# bwa-0.7.15
				# datamash-1.6
				# verifyBamID v1.1.3
				# samtools 1.10
				# bgzip 1.10
				# tabix 1.10
				# bcftools 1.10.2
				# parallel 20161222

	MITO_MUTECT2_CONTAINER="/mnt/research/tools/LINUX/00_GIT_REPO_KURT/CIDR_EXOME_MITO/containers/mito_mutect2-4.1.3.0.0.simg"
		# uses broadinstitute/gatk:4.1.3.0 as the base image (as /gatk/gatk.jar)
			# added
				# bcftools-1.10.2
				# haplogrep-2.1.20.jar (as /jars/haplogrep-2.1.20.jar)
				# annovar

	MITO_EKLIPSE_CONTAINER="/mnt/research/tools/LINUX/00_GIT_REPO_KURT/CIDR_EXOME_MITO/containers/mito_eklipse-master-c25931b.0.simg"
		# https://github.com/dooguypapua/eKLIPse AND all of its dependencies

	MITO_MAGICK_CONTAINER="/mnt/research/tools/LINUX/00_GIT_REPO_KURT/CIDR_EXOME_MITO/containers/mito_magick-6.8.9.9.0.simg"
		# magick package for R. see dockerfile for details.

	GATK_CONTAINER_4_2_2_0="/mnt/research/tools/LINUX/00_GIT_REPO_KURT/CIDR_EXOME_MITO/containers/gatk-4.2.2.0.simg"

	EKLIPSE_CIRCOS_LEGEND="${SCRIPT_DIR}/circos_legend.png"

	EKLIPSE_FORMAT_CIRCOS_PLOT_R_SCRIPT="${SCRIPT_DIR}/imgmagick_merge.r"

	MT_COVERAGE_R_SCRIPT="${SCRIPT_DIR}/mito_coverage_graph.r"

##################
# PIPELINE FILES #
##################

	MT_PICARD_INTERVAL_LIST="/mnt/research/tools/LINUX/00_GIT_REPO_KURT/CIDR_EXOME_MITO/resources/MT.interval_list"

	MT_MASK="/mnt/research/tools/LINUX/00_GIT_REPO_KURT/CIDR_EXOME_MITO/resources/hg37_MT_blacklist_sites.hg37.MT.bed"

	GNOMAD_MT="/mnt/research/tools/LINUX/00_GIT_REPO_KURT/CIDR_EXOME_MITO/resources/GRCh37_MT_gnomAD.vcf.gz"

	ANNOVAR_MT_DB_DIR="/mnt/research/tools/LINUX/00_GIT_REPO_KURT/CIDR_EXOME_MITO/resources/annovar_db/2021_02_02/annovar/humandb"

	MT_GENBANK="/mnt/research/tools/LINUX/00_GIT_REPO_KURT/CIDR_EXOME_MITO/resources/NC_012920.1.gb"

#################################
##### MAKE A DIRECTORY TREE #####
#################################

#############################################################
### CREATE_PROJECT_ARRAY for each PROJECT in sample sheet ###
#############################################################
	# add a end of file is not present
	# remove carriage returns if not present 
	# remove blank lines if present
	# remove lines that only have whitespace

		CREATE_PROJECT_ARRAY ()
		{
			PROJECT_ARRAY=(`awk 1 ${SAMPLE_SHEET} \
				| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' \
				| awk 'BEGIN {FS=","} \
					$1=="'${PROJECT_NAME}'" \
					{print $1}' \
				| sort \
				| uniq`)

			# 1: Project=the Seq Proj folder name
			
				SEQ_PROJECT=${PROJECT_ARRAY[0]}
		}

######################################
### project directory tree creator ###
######################################

	MAKE_PROJ_DIR_TREE ()
	{
		mkdir -p \
		${CORE_PATH}/${SEQ_PROJECT}/{LOGS,TEMP,COMMAND_LINES,REPORTS} \
		${CORE_PATH}/${SEQ_PROJECT}/MT_OUTPUT/{ANNOVAR_MT,COLLECTHSMETRICS_MT,EKLIPSE,HAPLOGROUPS,MUTECT2_MT,QC_REPORT_PREP_MT,QC_REPORT_MT,VCF_METRICS_MT}
	}

####################################################################
### combine steps into on function which is probably superfluous ###
####################################################################

	SETUP_PROJECT ()
	{
		CREATE_PROJECT_ARRAY
		MAKE_PROJ_DIR_TREE
		echo MT pipeline started at `date` >| ${CORE_PATH}/${SEQ_PROJECT}/REPORTS/PROJECT_START_END_TIMESTAMP.txt
	}

##################################
# RUN STEPS TO DO PROJECT SET UP #
##################################

	for PROJECT_NAME in $(awk 1 ${SAMPLE_SHEET} \
			| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' \
			| awk 'BEGIN {FS=","} \
				NR>1 \
				{print $1}' \
			| sort \
			| uniq);
	do
		SETUP_PROJECT
	done

#########################################
##### MUTECT2 IN MITO MODE WORKFLOW #####
##### WORKS ON FULL BAM FILE ############
#########################################

####################################################################
### CREATE_SAMPLE_ARRAY to populate aggregated sample variables. ###
####################################################################

	CREATE_SAMPLE_ARRAY ()
	{
			SAMPLE_ARRAY=(`awk 1 ${SAMPLE_SHEET} \
				| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d' \
				| awk 'BEGIN {FS=","} $8=="'${SM_TAG}'" \
					{print $1,$8,$12,$18}' \
				| sort \
				| uniq`)

			# 1 Project=the Seq Proj folder name

				PROJECT=${SAMPLE_ARRAY[0]}

				################################################################################
				# 2 SKIP : FCID=flowcell that sample read group was performed on ###############
				# 3 SKIP : Lane=lane of flowcell that sample read group was performed on] ######
				# 4 SKIP : Index=sample barcode ################################################
				# 5 SKIP : Platform=type of sequencing chemistry matching SAM specification ####
				# 6 SKIP : Library_Name=library group of the sample read group #################
				# 7 SKIP : Date=should be the run set up date to match the seq run folder name #
				################################################################################

			# 8 SM_Tag=sample ID

				SM_TAG=${SAMPLE_ARRAY[1]}

					# If there is an @ in the qsub or holdId name it breaks

						SGE_SM_TAG=$(echo ${SM_TAG} | sed 's/@/_/g') 

				###########################################################################################
				# 9 SKIP : Center=the center/funding mechanism ############################################
				# 10 SKIP : Description=Generally we use to denote the sequencer setting (e.g. rapid run) #
				# 11 SKIP : Seq_Exp_ID ####################################################################
				###########################################################################################

			# 12 Genome_Ref=the reference genome used in the analysis pipeline

				REF_GENOME=${SAMPLE_ARRAY[2]}

					# REFERENCE DICTIONARY IS A SUMMARY OF EACH CONTIG. PAIRED WITH REF GENOME

						REF_DICT=$(echo ${REF_GENOME} | sed 's/fasta$/dict/g; s/fa$/dict/g')

				##########################################################################################
				# 13 SKIP: Operator ######################################################################
				# 14 SKIP: Extra_VCF_Filter_Params #######################################################
				# 15 SKIP: TS_TV_BED_File=where ucsc coding exons overlap with bait and target bed files #
				# 16 SKIP: Baits_BED_File=a super bed file ###############################################
				##### incorporating bait, target, padding and overlap with ucsc coding exons. ############
				##### used for regions to perform base call quality score recalibration. #################
				##### used for generate gvcf regions #####################################################
				# 17 SKIP: Targets_BED_File=bed file acquired from manufacturer of their targets. ########
				##########################################################################################

			# 18 KNOWN_SITES_VCF=used to annotate ID field in VCF file.
				# used for masking in base call quality score recalibration.

					DBSNP=${SAMPLE_ARRAY[3]}

				####################################################
				# 19 SKIP: KNOWN_INDEL_FILES=used for BQSR masking #
				####################################################
	}

##################################################
### make sample sub-directories in TEMP folder ###
##################################################

	MAKE_SAMPLE_DIR_TREE ()
	{
		mkdir -p \
		${CORE_PATH}/${SEQ_PROJECT}/TEMP/${SM_TAG}_MT/{ANNOVAR_MT,EKLIPSE} \
		${CORE_PATH}/${SEQ_PROJECT}/LOGS/${SM_TAG}
	}

###########################################
### MUTECT2 IN MITO MODE WORKFLOW STEPS ###
###########################################

	###########################################
	# CONVERT FULL CRAM FILE TO FULL BAM FILE #
	###########################################

		CRAM_TO_BAM ()
		{
				echo \
				qsub \
					${QSUB_ARGS} \
					${STANDARD_QUEUE_QSUB_ARG} \
				-N A01-CRAM_TO_BAM_${SGE_SM_TAG}_${PROJECT} \
					-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-CRAM_TO_BAM.log \
				${SCRIPT_DIR}/A01-CRAM_TO_BAM.sh \
					${MITO_EKLIPSE_CONTAINER} \
					${CORE_PATH} \
					${PROJECT} \
					${SM_TAG} \
					${REF_GENOME} \
					${THREADS} \
					${SAMPLE_SHEET} \
					${SUBMIT_STAMP}
		}

	#####################################################
	# run mutect2 in mitochondria mode on full bam file #
	# this runs MUCH slower on non-avx machines #########
	#####################################################

		MUTECT2_MT ()
		{
				echo \
				qsub \
					${QSUB_ARGS} \
					${STANDARD_QUEUE_QSUB_ARG} \
				-N B01-MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
					-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-MUTECT2_MT.log \
				-hold_jid A01-CRAM_TO_BAM_${SGE_SM_TAG}_${PROJECT} \
				${SCRIPT_DIR}/B01-MUTECT2_MT.sh \
					${MITO_MUTECT2_CONTAINER} \
					${CORE_PATH} \
					${PROJECT} \
					${SM_TAG} \
					${REF_GENOME} \
					${SAMPLE_SHEET} \
					${SUBMIT_STAMP}
		}

	#######################################
	# apply filters to mutect2 vcf output #
	#######################################

		FILTER_MUTECT2_MT ()
		{
				echo \
				qsub \
					${QSUB_ARGS} \
					${STANDARD_QUEUE_QSUB_ARG} \
				-N B01-A01-FILTER_MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
					-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-FILTER_MUTECT2_MT.log \
				-hold_jid B01-MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
				${SCRIPT_DIR}/B01-A01-FILTER_MUTECT2_MT.sh \
					${MITO_MUTECT2_CONTAINER} \
					${CORE_PATH} \
					${PROJECT} \
					${SM_TAG} \
					${REF_GENOME} \
					${SAMPLE_SHEET} \
					${SUBMIT_STAMP}
		}

	###################################################
	# apply masks to mutect2 mito filtered vcf output #
	###################################################

		MASK_MUTECT2_MT ()
		{
				echo \
				qsub \
					${QSUB_ARGS} \
					${STANDARD_QUEUE_QSUB_ARG} \
				-N B01-A01-A01-MASK_MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
					-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-MASK_MUTECT2_MT.log \
				-hold_jid B01-A01-FILTER_MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
				${SCRIPT_DIR}/B01-A01-A01-MASK_MUTECT2_MT.sh \
					${MITO_MUTECT2_CONTAINER} \
					${CORE_PATH} \
					${PROJECT} \
					${SM_TAG} \
					${MT_MASK} \
					${SAMPLE_SHEET} \
					${SUBMIT_STAMP}
		}

	#############################################
	# run haplogrep2 on mutect2 mito vcf output #
	#############################################

		HAPLOGREP2_MUTECT2_MT ()
		{
				echo \
				qsub \
					${QSUB_ARGS} \
					${STANDARD_QUEUE_QSUB_ARG} \
				-N B01-A01-A01-A01-HAPLOGREP2_MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
					-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-HAPLOGREP2_MUTECT2_MT.log \
					-hold_jid B01-A01-A01-MASK_MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
				${SCRIPT_DIR}/B01-A01-A01-A01-HAPLOGREP2_MUTECT2_MT.sh \
					${MITO_MUTECT2_CONTAINER} \
					${CORE_PATH} \
					${PROJECT} \
					${SM_TAG} \
					${REF_GENOME} \
					${SAMPLE_SHEET} \
					${SUBMIT_STAMP}
		}

	##########################################
	# run annovar on final mutect2 based vcf #
	##########################################

		RUN_ANNOVAR_MUTECT2_MT ()
		{
				echo \
				qsub \
					${QSUB_ARGS} \
					${STANDARD_QUEUE_QSUB_ARG} \
				-N B01-A01-A01-A02-RUN_ANNOVAR_MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
					-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-RUN_ANNOVAR_MUTECT2_MT.log \
				-hold_jid B01-A01-A01-MASK_MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
				${SCRIPT_DIR}/B01-A01-A01-A02-RUN_ANNOVAR_MUTECT2_MT.sh \
					${MITO_MUTECT2_CONTAINER} \
					${CORE_PATH} \
					${PROJECT} \
					${SM_TAG} \
					${ANNOVAR_MT_DB_DIR} \
					${SAMPLE_SHEET} \
					${SUBMIT_STAMP}
		}

		##########################################
		# run annovar on final mutect2 based vcf #
		##########################################

			FIX_ANNOVAR_MUTECT2_MT ()
			{
					echo \
					qsub \
						${QSUB_ARGS} \
						${STANDARD_QUEUE_QSUB_ARG} \
					-N B01-A01-A01-A02-A01-FIX_ANNOVAR_MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
						-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-FIX_ANNOVAR_MUTECT2_MT.log \
					-hold_jid B01-A01-A01-A02-RUN_ANNOVAR_MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
					${SCRIPT_DIR}/B01-A01-A01-A02-A01-FIX_ANNOVAR_MUTECT2_MT.sh \
						${CORE_PATH} \
						${PROJECT} \
						${SM_TAG} \
						${SAMPLE_SHEET} \
						${SUBMIT_STAMP}
			}

	#######################################################################
	# generate vcf metrics on mito mutect2 filtered and masked vcf output #
	#######################################################################

		VCF_METRICS_MT ()
		{
				echo \
				qsub \
					${QSUB_ARGS} \
					${STANDARD_QUEUE_QSUB_ARG} \
				-N B01-A01-A01-A03-VCF_METRICS_MT_${SGE_SM_TAG}_${PROJECT} \
					-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-VCF_METRICS_MT.log \
				-hold_jid B01-A01-A01-MASK_MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
				${SCRIPT_DIR}/B01-A01-A01-A03-VCF_METRICS_MT.sh \
					${ALIGNMENT_CONTAINER} \
					${CORE_PATH} \
					${PROJECT} \
					${SM_TAG} \
					${REF_DICT} \
					${DBSNP} \
					${MT_PICARD_INTERVAL_LIST} \
					${THREADS} \
					${SAMPLE_SHEET} \
					${SUBMIT_STAMP}
		}

	#################################
	# CONVERT MUTECT2 MT BAM TO CRAM #
	#################################

		MUTECT2_MT_BAM_TO_CRAM ()
		{
				echo \
				qsub \
					${QSUB_ARGS} \
					${STANDARD_QUEUE_QSUB_ARG} \
				-N B01-A02-MUTECT2_MT_BAM_TO_CRAM_${SGE_SM_TAG}_${PROJECT} \
					-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}-MUTECT2_MT_BAM_TO_CRAM.log \
				-hold_jid B01-MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
				${SCRIPT_DIR}/B01-A02-MUTECT2_MT_BAM_TO_CRAM.sh \
					${MITO_EKLIPSE_CONTAINER} \
					${CORE_PATH} \
					${PROJECT} \
					${SM_TAG} \
					${REF_GENOME} \
					${THREADS} \
					${SAMPLE_SHEET} \
					${SUBMIT_STAMP}
		}

##############################################################
##### RUN EKLIPSE TO DETECT LARGE DELETIONS IN MT GENOME #####
##############################################################

	############################################
	# SUBSET BAM FILE TO CONTAIN ONLY MT READS #
	############################################

		SUBSET_BAM_MT ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
				${STANDARD_QUEUE_QSUB_ARG} \
			-N A02-MAKE_BAM_MT_${SGE_SM_TAG}_${PROJECT} \
				-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-MAKE_BAM_MT.log \
			${SCRIPT_DIR}/A02-MAKE_MT_BAM.sh \
				${MITO_EKLIPSE_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${SM_TAG} \
				${REF_GENOME} \
				${THREADS} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	###############
	# RUN EKLIPSE #
	###############

		RUN_EKLIPSE ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
				${STANDARD_QUEUE_QSUB_ARG} \
			-N A02-A01-RUN_EKLIPSE_${SGE_SM_TAG}_${PROJECT} \
				-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-RUN_EKLIPSE.log \
			-hold_jid A02-MAKE_BAM_MT_${SGE_SM_TAG}_${PROJECT} \
			${SCRIPT_DIR}/A02-A01-RUN_EKLIPSE.sh \
				${MITO_EKLIPSE_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${SM_TAG} \
				${MT_GENBANK} \
				${THREADS} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	#####################################
	# ADD LEGEND TO EKLIPSE CIRCOS PLOT #
	#####################################

		FORMAT_EKLIPSE_CIRCOS ()
		{
			echo \
			qsub \
				${IMGMAGICK_QSUB_ARGS} \
				${STANDARD_QUEUE_QSUB_ARG} \
			-N A02-A01-A01-FORMAT_EKLIPSE_CIRCOS_${SGE_SM_TAG}_${PROJECT} \
				-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-FORMAT_EKLIPSE_CIRCOS.log \
			-hold_jid A02-A01-RUN_EKLIPSE_${SGE_SM_TAG}_${PROJECT} \
			${SCRIPT_DIR}/A02-A01-A01-FORMAT_EKLIPSE_CIRCOS.sh \
				${MITO_MAGICK_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${SM_TAG} \
				${EKLIPSE_FORMAT_CIRCOS_PLOT_R_SCRIPT} \
				${EKLIPSE_CIRCOS_LEGEND} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

######################################################
##### COVERAGE STATISTICS AND PLOT FOR MT GENOME #####
######################################################

	##############################################################
	# RUN COLLECTHSMETRICS ON MT ONLY BAM FILE ###################
	# USES GATK IMPLEMENTATION INSTEAD OF PICARD TOOLS ###########
	##############################################################

		COLLECTHSMETRICS_MT ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
				${STANDARD_QUEUE_QSUB_ARG} \
			-N A02-A02-COLLECTHSMETRICS_MT_${SGE_SM_TAG}_${PROJECT} \
				-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-COLLECTHSMETRICS_MT.log \
			-hold_jid A02-MAKE_BAM_MT_${SGE_SM_TAG}_${PROJECT} \
			${SCRIPT_DIR}/A02-A02-COLLECTHSMETRICS_MT.sh \
				${GATK_CONTAINER_4_2_2_0} \
				${CORE_PATH} \
				${PROJECT} \
				${SM_TAG} \
				${REF_GENOME} \
				${MT_PICARD_INTERVAL_LIST} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

	###############################################################
	# RUN ALEX'S R SCRIPT TO GENERATE COVERAGE PLOT FOR MT GENOME #
	###############################################################

		PLOT_MT_COVERAGE ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
				${STANDARD_QUEUE_QSUB_ARG} \
			-N A02-A02-A01-PLOT_MT_COVERAGE_${SGE_SM_TAG}_${PROJECT} \
				-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-PLOT_MT_COVERAGE.log \
			-hold_jid A02-A02-COLLECTHSMETRICS_MT_${SGE_SM_TAG}_${PROJECT} \
			${SCRIPT_DIR}/A02-A02-A01_PLOT_MT_COVERAGE.sh \
				${MITO_MUTECT2_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${SM_TAG} \
				${MT_COVERAGE_R_SCRIPT} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

######################################
### QC REPORT PREP FOR EACH SAMPLE ###
######################################

QC_REPORT_PREP_MT ()
{
echo \
qsub \
	${QSUB_ARGS} \
	${STANDARD_QUEUE_QSUB_ARG} \
-N MTQC_${SGE_SM_TAG} \
	-o ${CORE_PATH}/${PROJECT}/LOGS/${SM_TAG}/${SM_TAG}-QC_REPORT_PREP_MT.log \
-hold_jid \
A02-A01-A01-FORMAT_EKLIPSE_CIRCOS_${SGE_SM_TAG}_${PROJECT},\
A02-A02-A01-PLOT_MT_COVERAGE_${SGE_SM_TAG}_${PROJECT},\
B01-A02-MUTECT2_MT_BAM_TO_CRAM_${SGE_SM_TAG}_${PROJECT},\
B01-A01-A01-A01-HAPLOGREP2_MUTECT2_MT_${SGE_SM_TAG}_${PROJECT},\
B01-A01-A01-A03-VCF_METRICS_MT_${SGE_SM_TAG}_${PROJECT},\
B01-A01-A01-A02-A01-FIX_ANNOVAR_MUTECT2_MT_${SGE_SM_TAG}_${PROJECT} \
${SCRIPT_DIR}/X01-QC_REPORT_PREP_MT.sh \
	${ALIGNMENT_CONTAINER} \
	${CORE_PATH} \
	${PROJECT} \
	${SM_TAG}
}

###############################################################
# run steps centered on gatk's mutect2 mitochondrial workflow #
###############################################################

	for SM_TAG in $(awk 1 ${SAMPLE_SHEET} \
			| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
			| awk 'BEGIN {FS=","} \
				NR>1 \
				{print $8}' \
			| sort \
			| uniq );
	do
		CREATE_SAMPLE_ARRAY
		MAKE_SAMPLE_DIR_TREE
		# convert cram back to bam
		CRAM_TO_BAM
		echo sleep 0.1s
		# run mutect2 and then filter, annotate, run haplogrep2
		MUTECT2_MT
		echo sleep 0.1s
		FILTER_MUTECT2_MT
		echo sleep 0.1s
		MASK_MUTECT2_MT
		echo sleep 0.1s
		HAPLOGREP2_MUTECT2_MT
		echo sleep 0.1s
		RUN_ANNOVAR_MUTECT2_MT
		echo sleep 0.1s
		FIX_ANNOVAR_MUTECT2_MT
		echo sleep 0.1s
		VCF_METRICS_MT
		echo sleep 0.1s
		# run eklipse workflow
		SUBSET_BAM_MT
		echo sleep 0.1s
		RUN_EKLIPSE
		echo sleep 0.1s
		FORMAT_EKLIPSE_CIRCOS
		echo sleep 0.1s
		# generate coverage for mt genome
		COLLECTHSMETRICS_MT
		echo sleep 0.1s
		PLOT_MT_COVERAGE
		echo sleep 0.1s
		# create a qc report stub for each sample
		QC_REPORT_PREP_MT
		echo sleep 0.1s
	done

#############################
##### END PROJECT TASKS #####
#############################

	# build hold id for per sample, per project

		BUILD_HOLD_ID_PATH_PROJECT_WRAP_UP ()
		{
			HOLD_ID_PATH="-hold_jid "

			for SM_TAG in $(awk 1 ${SAMPLE_SHEET} \
				| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
				| awk 'BEGIN {FS=","} \
					$1=="'${PROJECT}'" \
					{print $8}' \
				| sort \
				| uniq);
			do
				CREATE_SAMPLE_ARRAY

				HOLD_ID_PATH="${HOLD_ID_PATH}MTQC_${SGE_SM_TAG},"

				HOLD_ID_PATH=`echo ${HOLD_ID_PATH} | sed 's/@/_/g'`
			done
		}

	# run end project functions (md5, file clean-up) for each project

		PROJECT_WRAP_UP ()
		{
			echo \
			qsub \
				${QSUB_ARGS} \
				${STANDARD_QUEUE_QSUB_ARG} \
			-N X01-X01-END_PROJECT_TASKS_${PROJECT} \
				-o ${CORE_PATH}/${PROJECT}/LOGS/${PROJECT}-END_PROJECT_TASKS.log \
			${HOLD_ID_PATH} \
			${SCRIPT_DIR}/X01-X01-END_PROJECT_TASKS.sh \
				${ALIGNMENT_CONTAINER} \
				${CORE_PATH} \
				${PROJECT} \
				${SCRIPT_DIR} \
				${SEND_TO} \
				${SUBMITTER_ID} \
				${THREADS} \
				${SAMPLE_SHEET} \
				${SUBMIT_STAMP}
		}

##############
# final loop #
##############

	for PROJECT in $(awk 1 ${SAMPLE_SHEET} \
		| sed 's/\r//g; /^$/d; /^[[:space:]]*$/d; /^,/d' \
		| awk 'BEGIN {FS=","} \
			NR>1 \
			{print $1}' \
		| sort \
		| uniq);
	do
		BUILD_HOLD_ID_PATH_PROJECT_WRAP_UP
		PROJECT_WRAP_UP
	done

# MESSAGE THAT SAMPLE SHEET HAS FINISHED SUBMITTING

	printf "echo\n"

	printf "echo ${SAMPLE_SHEET} has finished submitting at `date`\n"

# EMAIL WHEN DONE SUBMITTING

	printf "${SAMPLE_SHEET}\nhas finished submitting at\n`date`\nby `whoami`" \
		| mail -s "${PERSON_NAME} has submitted SUBMITTER_CIDR_Exome_Mito.sh" \
			${SEND_TO}
