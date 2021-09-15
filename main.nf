#!/usr/bin/env nextflow
/*
========================================================================================
                         nf-core/transcriptcorral
========================================================================================
 nf-core/transcriptcorral Analysis Pipeline.
 #### Homepage / Documentation
 https://github.com/systemsgenetics/transcriptcorral
----------------------------------------------------------------------------------------
*/

def helpMessage() {
    // TODO nf-core: Add to this help message with new command line parameters
    log.info nfcoreHeader()
    log.info"""

    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run nf-core/transcriptcorral --reads '*_R{1,2}.fastq.gz' -profile docker

    Input arguments:
      --local_samples               A folder that contains local paired-end sequencing files that should be preprocessed
      --skip_samples                A .txt file that contains a list of samples that should be skipped
      --sra_samples                 A .txt file containing a list of SRA IDs that should be retrieved from NCBI
      --keep_sra                    A boolean that indicates whether sequencing files should be kept
  
     --preprocessed_samples         A filepattern that contains local paired-end sequencing files that should directly be used for assembly
     --input_assemblies             A filepath containing any preassembled transcriptomes to be used for meta-assembly and BUSCO testing
    
    Assembler options:
    --use_trinity                   A boolean that indicates whether to assemble with Trinity    
    
    Job request arguments:
      --max_cpus                    The number of cpus available
      --max_memory                  The amount of memory available
      --max_time                    The upper limit to allow the pipeline to run (format: ##.h)

    Output arguments:
      --outdir                      The folder to save results to
      --publish_dir_mode            The type of link to use for publishing results (defaut: 'link')

    AWSBatch options:
      --awsqueue [str]                The AWSBatch JobQueue that needs to be set when running on AWSBatch
      --awsregion [str]               The AWS Region for your AWS Batch job to run on
      --awscli [str]                  Path to the AWS CLI tool
    """.stripIndent()
}

// Show help message
if (params.help) {
    helpMessage()
    exit 0
}

////////////////////////////////////////////////////
/* --     Collect configuration parameters     -- */
////////////////////////////////////////////////////

println """\
Workflow Information:
---------------------
  Project Directory:          ${workflow.projectDir}
  Work Directory:             ${workflow.workDir}
  Launch Directory:           ${workflow.launchDir}
  Config Files:               ${workflow.configFiles}
  Container Engine:           ${workflow.containerEngine}
  Profile(s):                 ${workflow.profile}
Samples:
--------
  Remote sample list path:    ${params.sra_samples}
  Local sample glob:          ${params.local_samples}
  Skip samples file:          ${params.skip_samples}

  Preprocesed samples:        ${params.preprocessed_samples}
  User provided assemblies:   ${params.input_assemblies}

Reports
-------
  Report directory:           ${params.outdir}/reports"""


/**
 * Create the directories we'll use for fastq files
 */
file("${workflow.workDir}/transcript_files").mkdir()
file("${workflow.workDir}/sample_files").mkdir()



/**
 * Check that other input files/directories exist
 */

if (params.sra_samples) {
    sample_file = file("${params.sra_samples}")
    if (!sample_file.exists()) {
        error "Error: The NCBI download sample file does not exists at '${params.sra_samples}'. This file must be provided. If you are not downloading samples from NCBI SRA the file must exist but can be left empty."
    }
}

if (params.skip_samples) {
    skip_file = file("${params.skip_samples}")
    if (!skip_file.exists()) {
       error "Error: The file containing samples to skip does not exists at '${params.skip_samples}'."
   }
}

/**
 * Create value channels that can be reused
 */

FAILED_RUN_TEMPLATE = Channel.fromPath("${params.failed_run_report_template}").collect()

if (params.skip_samples) {
  SKIP_SAMPLES_FILE = Channel.fromPath("${params.skip_samples}")
}
else {
    Channel.value('NA').set { SKIP_SAMPLES_FILE }
}

/**
 * Local Sample Input.
 * This checks the folder that the user has given
 */
if (!params.local_samples) {
  Channel.empty().set { LOCAL_SAMPLE_FILES_FOR_STAGING }
  Channel.empty().set { LOCAL_SAMPLE_FILES_FOR_JOIN }
}
else {
  Channel.fromFilePairs( "${params.local_samples}", size: -1 )
    .set { LOCAL_SAMPLE_FILES_FOR_STAGING }
  Channel.fromFilePairs( "${params.local_samples}", size: -1 )
    .set { LOCAL_SAMPLE_FILES_FOR_JOIN }
}

/* 
 * Preprocessed Sample Input
 */
if (!params.preprocessed_samples) {
  Channel.empty().set { PREPROCESSED_FORWARD_READS }
  Channel.empty().set { PREPROCESSED_REVERSE_READS }
} 
else {
  Channel.fromFilePairs( "${params.preprocessed_samples}", size: -1 )
    .map { it[1][0] }
    .set { PREPROCESSED_FORWARD_READS }

  Channel.fromFilePairs( "${params.preprocessed_samples}", size: -1 )
    .map { it[1][1] }
    .set { PREPROCESSED_REVERSE_READS }
}

//FORWARD_READS_FOR_ASSEMBLY.view()
//REVERSE_READS_FOR_ASSEMBLY.view()

/* 
 * User provided transcriptome assemblies
 */
if (params.input_assemblies) {
  Channel.fromPath("${params.input_assemblies}").set { INPUT_ASSEMBLIES }
}

/**
 * Remote fastq_run_id Input.
 */
if (params.sra_samples == "") {
  Channel.empty().set { SRR_FILE }
}
else {
  Channel.fromPath("${params.sra_samples}").set { SRR_FILE }
}

println """\
Published Results:
---------------
  Output Dir:                 ${params.outdir}/transcript_files """


/**
 * Set the pattern for publishing downloaded FASTQ files
 */
publish_pattern_fastq_dump = params.keep_sra
  ? "{*.fastq}"
  : "{none}"

/**
 * Retrieves metadata for all of the remote samples
 * and maps SRA runs to SRA experiments.set
 */
process retrieve_sra_metadata {
  publishDir params.outdir, mode: params.publish_dir_mode, pattern: "failed_runs.metadata.txt"
  label "retrieve_sra_metadata"

  input:
    file srr_file from SRR_FILE
    file skip_samples from SKIP_SAMPLES_FILE

  output:
    stdout REMOTE_SAMPLES_LIST
    file "failed_runs.metadata.txt" into METADATA_FAILED_RUNS

  script:
  if (skip_samples != 'NA') {
      skip_arg = "--skip_file ${skip_samples}"
  }
  """
  >&2 echo "#TRACE n_remote_run_ids=`cat ${srr_file} | wc -l`"
  retrieve_sra_metadata.py \
      --run_id_file ${srr_file} \
      --meta_dir ${workflow.workDir}/transcript_files \
      ${skip_arg}
  """
}


/**
 * Splits the SRR2XRX mapping file
 */

// First create a list of the remote and local samples
REMOTE_SAMPLES_LIST
  .splitCsv()
  .groupTuple(by: 1)
  .map { [it[1], it[0].toString().replaceAll(/[\[\]\'\,]/,''), 'remote'] }
  .set{REMOTE_SAMPLES_FOR_STAGING}

LOCAL_SAMPLE_FILES_FOR_STAGING
  .map{ [it[0], it[1], 'local'] }
  .set{LOCAL_SAMPLES_FOR_STAGING}

ALL_SAMPLES = REMOTE_SAMPLES_FOR_STAGING
  .mix(LOCAL_SAMPLES_FOR_STAGING)


/**
 * Writes the batch files and stores them in the
 * stage directory.
 */
process write_sample_files {
  tag { sample_id }
  label "local"

  input:
    set val(sample_id), val(run_files_or_ids), val(sample_type) from ALL_SAMPLES

  output:
    file '*.sample.csv' into SAMPLE_FILES

  exec:
    // Get any samples to skip
    skip_samples = []
    if (params.skip_samples) {
        skip_file = file("${params.skip_samples}")
        skip_file.eachLine { line ->
            skip_samples << line.trim()
        }
    }

    // Only stage files that should not be skipped.
    if (skip_samples.intersect([sample_id]) == []) {
      // Create a file for each samples.
      sample_file = file("${task.workDir}" + '/' + sample_id + '.sample.csv')
      sample_file.withWriter {
        // If this is a local file.
        if (sample_type.equals('local')) {
          it.writeLine '"' + sample_id + '","' + run_files_or_ids.join('::') + '","' + sample_type + '"'
        }
        // If this is a remote file.
        else {
          it.writeLine '"' + sample_id + '","' + run_files_or_ids + '","' + sample_type + '"'
        }
      }
    }
}



// ######  NF-CORE CODE  ######
/*
 * Parse software version numbers
 */
process get_software_versions {
    publishDir "${params.outdir}/pipeline_info", mode: 'copy',
        saveAs: { filename ->
                      if (filename.indexOf(".csv") > 0) filename
                      else null
                }

    output:
    file 'software_versions_mqc.yaml' into ch_software_versions_yaml
    file "software_versions.csv"

    script:
    // TODO nf-core: Get all tools to print their version number here
    """
    echo $workflow.manifest.version > v_pipeline.txt
    echo $workflow.nextflow.version > v_nextflow.txt
    fastq-dump --version > v_fastq_dump.txt
    scrape_software_versions.py &> software_versions_mqc.yaml
    """
}

// ###### PIPELINE CODE  ######

// Create the channel that will watch the process directory
// for new files. When a new sample file is added
// it will be read it and sent it through the workflow.
//NEXT_SAMPLE = Channel
//   .watchPath("${workflow.workDir}/sample_files")


// ### FASTQ File Setup ###
/**
 * Opens the sample file and prints it's contents to
 * STDOUT so that the samples can be caught in a new
 * channel and start processing.
 */
process read_sample_file {
  tag { sample_file }
  label "local"
  cache false

  input:
    file(sample_file) from SAMPLE_FILES

  output:
    stdout SAMPLE_FILE_CONTENTS

  script:
  """
  cat ${sample_file}
  """
}

// Split our sample file contents into two different
// channels, one for remote samples and another for local.
LOCAL_SAMPLES = Channel.create()
REMOTE_SAMPLES = Channel.create()
SAMPLE_FILE_CONTENTS
  .splitCsv(quote: '"')
  .choice(LOCAL_SAMPLES, REMOTE_SAMPLES) { a -> a[2] =~ /local/ ? 0 : 1 }

// Process local sample files for downstream analysis.
LOCAL_SAMPLES
  .map {[it[0], 'hi']}
  .mix(LOCAL_SAMPLE_FILES_FOR_JOIN)
  .groupTuple(size: 2)
  .map {[it[0], it[1][0]]}
  .set {LOCAL_SAMPLES_FOR_TRIMMING}

/**
 * Downloads SRA files from NCBI using the SRA Toolkit.
 */
process download_runs {
  publishDir params.outdir, mode: params.publish_dir_mode, pattern: '*.failed_runs.download.txt', saveAs: { "Samples/${sample_id}/${it}" }

  tag { sample_id }
  label "download_runs"

  input:
    set val(sample_id), val(run_ids), val(type) from REMOTE_SAMPLES

  output:
    set val(sample_id), file("*.sra") optional true into SRA_TO_EXTRACT    
    set val(sample_id), file('*.failed_runs.download.txt') into DOWNLOAD_FAILED_RUNS

  script:
  """
  echo "#TRACE n_remote_run_ids=${run_ids.tokenize(' ').size()}"
  retrieve_sra.py --sample ${sample_id} --run_ids ${run_ids} --akey \$ASPERA_KEY
  """
}

/**
 * Extracts FASTQ files from downloaded SRA files.
 */
process fastq_dump {
  publishDir params.outdir, mode: params.publish_dir_mode, pattern: publish_pattern_fastq_dump, saveAs: { "Samples/${sample_id}/${it}" }
  publishDir params.outdir, mode: params.publish_dir_mode, pattern: '*.failed_runs.fastq-dump.txt', saveAs: { "Samples/${sample_id}/${it}" }
  tag { sample_id }
  label "fastq_dump"

  input:
    set val(sample_id), file(sra_files) from SRA_TO_EXTRACT

  output:
    set val(sample_id), file("*.fastq") optional true into DOWNLOADED_FASTQ_FOR_MERGING     
    set val(sample_id), file('*.failed_runs.fastq-dump.txt') into FASTQ_DUMP_FAILED_RUNS

  script:
  """
  echo "#TRACE sample_id=${sample_id}"
  echo "#TRACE sra_bytes=`stat -Lc '%s' *.sra | awk '{sum += \$1} END {print sum}'`"
  sra2fastq.py --sample ${sample_id} --sra_files ${sra_files}
  """
}



/**
 * This process merges the fastq files based on their sample_id number.
 */
process fastq_merge {
  tag { sample_id }

  input:
    set val(sample_id), file(fastq_files) from DOWNLOADED_FASTQ_FOR_MERGING

  output:
    set val(sample_id), file("${sample_id}_?.fastq") into MERGED_SAMPLES_FOR_TRIMMING

  script:
  """
  echo "#TRACE sample_id=${sample_id}"
  echo "#TRACE fastq_lines=`cat *.fastq | wc -l`"
  fastq_merge.sh ${sample_id}
  """
}

/**
 * This is where we combine samples from both local and remote sources.
 */
COMBINED_SAMPLES = LOCAL_SAMPLES_FOR_TRIMMING.mix(MERGED_SAMPLES_FOR_TRIMMING)



/**
 * Creates a report of any SRA run IDs that failed and why they failed.
 */
process failed_run_report {
  label "reports"
  publishDir "${params.outdir}/reports", mode: params.publish_dir_mode

  input:
    file metadata_failed_runs from METADATA_FAILED_RUNS
    file download_failed_runs from DOWNLOAD_FAILED_RUNS.collect()
    file fastq_dump_failed_runs from FASTQ_DUMP_FAILED_RUNS.collect()
    file failed_run_template from FAILED_RUN_TEMPLATE

  output:
    file "failed_SRA_run_report.html" into FAILED_RUN_REPORT

  script:
  """
  failed_runs_report.py --template ${failed_run_template}
  """

}

// ### FASTQ Preprocessing ###
/*
 * Trim adapters using Trim Galore
 */
process trim_adapters {
   input:
   set val(sample_id), path(raw_fastq_files) from COMBINED_SAMPLES

   output:
   tuple val(sample_id), file("*_val_1.fq"), file("*_val_2.fq") into TRIMMED_PAIRS

   script:
   """
   echo "Trimming adapters from $raw_fastq_files"

   trim_galore --paired --trim-n --length 36 -q 5 --suppress_warn $raw_fastq_files
   """
}

/*
 * Perform error correction using RCorrector
 */
process error_correction {
   input:
   tuple val(sample_id), file(forward_reads), file(reverse_reads) from TRIMMED_PAIRS

   output:
   tuple val(sample_id), file("*_1.cor.fq"), file("*_2.cor.fq") into CORRECTED_PAIRS

   script:
   """
   echo "Error correction with files: $forward_reads $reverse_reads"

   perl /rcorrector/run_rcorrector.pl -1 $forward_reads -2 $reverse_reads
   """
}

/*
 * Discard reads that RCorrector deemed unfixable
 */
process discard_unfixables {
   input:
   tuple val(sample_id), file(forward_reads), file(reverse_reads) from CORRECTED_PAIRS

   output:
   tuple val(sample_id), file("*_1.cor.fq"), file("*_2.cor.fq") into CORRECTED_PAIRS_CLEAN

   script:
   """
   echo "Removing unfixable reads from corrected files: $forward_reads $reverse_reads"

   python ${workflow.launchDir}/bin/FilterUncorrectedReadsPEfastq.py -1 $forward_reads -2 $reverse_reads -s $sample_id
   """
}

/*
 * Use SILVA rRNA database to remove likely rRNA sequences
 */
process remove_rRNA {
  input:
  tuple val(sample_id), file(forward_reads), file(reverse_reads) from CORRECTED_PAIRS_CLEAN

  output:
  file("*whitelist_paired_unaligned_1.fq") into FORWARD_READS_FOR_ASSEMBLY
  file("*whitelist_paired_unaligned_2.fq") into REVERSE_READS_FOR_ASSEMBLY

  script:
  """
  mkdir logs

  bowtie2 --quiet \
    --very-sensitive-local \
    --phred33 \
    -x /SILVA_db/combined_silva_reference \
    -1 "$forward_reads" \
    -2 "$reverse_reads" \
    --met-file logs/$sample_id"_bowtie2_metrics.txt" \
    --al-conc $sample_id"_blacklist_paired_aligned_%.fq" \
    --un-conc $sample_id"_whitelist_paired_unaligned_%.fq" \
    --al $sample_id"_blacklist_unpaired_aligned_%.fq" \
    --un $sample_id"_whitelist_unpaired_unaligned_%.fq"
  """
}

// ### Multi-Assembly ###
/*
 * Combining the reads into singular files
 */
FORWARD_READS_FOR_ASSEMBLY
  .mix( PREPROCESSED_FORWARD_READS )
  .collectFile(name: "combined_forward_reads.fq", newLine: false, skip: 0)
  .set { COMBINED_FORWARD_READS_FOR_ASSEMBLY }

REVERSE_READS_FOR_ASSEMBLY
  .mix( PREPROCESSED_REVERSE_READS )
  .collectFile(name: "combined_reverse_reads.fq", newLine: false, skip: 0)
  .set  { COMBINED_REVERSE_READS_FOR_ASSEMBLY }

/*
 * Splitting the reads channels for each assembler
 */
COMBINED_FORWARD_READS_FOR_ASSEMBLY.into { FORWARD_READS_FOR_TRINITY }
COMBINED_REVERSE_READS_FOR_ASSEMBLY.into { REVERSE_READS_FOR_TRINITY }

/*
 * Assembly with Trinity
 */
process assembly_Trinity {

when: 
params.use_trinity == true

input:
file(forward_reads) from FORWARD_READS_FOR_TRINITY
file(reverse_reads) from REVERSE_READS_FOR_TRINITY

output:
file("Trinity.fasta") into TRANSCRIPTOME_ASSEMBLIES

script:
"""
Trinity \
  --seqType fq \
  --CPU ${params.max_cpus} \
  --max_memory ${params.trinity_mem} \
  --min_kmer_cov 3 \
  --left "$forward_reads" \
  --right "$reverse_reads"
"""
}

/*
 * Combining multiple assemblies into a single sequence file
 */
TRANSCRIPTOME_ASSEMBLIES
  .mix ( INPUT_ASSEMBLIES )
  .collectFile(name: "combined_assemblies.fastq", newLine: false, skip: 0)
  .set { COMBINED_ASSEMBLY }

/*
 * Unify assembly ID formats across the combined assemblies
 */
process unify_assembly_ids {
when: 
params.meta_assembly == true

input:
file(combined_assembly) from COMBINED_ASSEMBLY

output:
file("unified_transcriptome.fasta") into UNIFIED_COMBINED_ASSEMBLY

script:
"""
trformat.pl \
  -output unified_transcriptome.fasta \
  -input $combined_assembly
"""
}

/*
 * Use Evidentialgene to identify the best transcript assemblies
 */
process evigene {
when: 
params.meta_assembly == true

input:
file(unified_assembly) from UNIFIED_COMBINED_ASSEMBLY

output:
file("okayset/unified_transcriptome.okay.mrna") into EVIGENE_OKAY_SET

script:
"""
tr2aacds4.pl \
  -logfile \
  -cdnaseq $unified_assembly \
  -NCPU ${params.max_cpus} \
  -MAXMEM ${params.max_memory}
"""
}

// ######  NF-CORE CODE ######
/*
 * Completion e-mail notification
 */
workflow.onComplete {

    // Set up the e-mail variables
    def subject = "[nf-core/transcriptcorral] Successful: $workflow.runName"
    if (!workflow.success) {
        subject = "[nf-core/transcriptcorral] FAILED: $workflow.runName"
    }
    def email_fields = [:]
    email_fields['version'] = workflow.manifest.version
    email_fields['runName'] = custom_runName ?: workflow.runName
    email_fields['success'] = workflow.success
    email_fields['dateComplete'] = workflow.complete
    email_fields['duration'] = workflow.duration
    email_fields['exitStatus'] = workflow.exitStatus
    email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    email_fields['errorReport'] = (workflow.errorReport ?: 'None')
    email_fields['commandLine'] = workflow.commandLine
    email_fields['projectDir'] = workflow.projectDir
    email_fields['summary'] = summary
    email_fields['summary']['Date Started'] = workflow.start
    email_fields['summary']['Date Completed'] = workflow.complete
    email_fields['summary']['Pipeline script file path'] = workflow.scriptFile
    email_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
    if (workflow.repository) email_fields['summary']['Pipeline repository Git URL'] = workflow.repository
    if (workflow.commitId) email_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
    if (workflow.revision) email_fields['summary']['Pipeline Git branch/tag'] = workflow.revision
    email_fields['summary']['Nextflow Version'] = workflow.nextflow.version
    email_fields['summary']['Nextflow Build'] = workflow.nextflow.build
    email_fields['summary']['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp

    // TODO nf-core: If not using MultiQC, strip out this code (including params.max_multiqc_email_size)
    // On success try attach the multiqc report
    def mqc_report = null
    try {
        if (workflow.success) {
            mqc_report = ch_multiqc_report.getVal()
            if (mqc_report.getClass() == ArrayList) {
                log.warn "[nf-core/transcriptcorral] Found multiple reports from process 'multiqc', will use only one"
                mqc_report = mqc_report[0]
            }
        }
    } catch (all) {
        log.warn "[nf-core/transcriptcorral] Could not attach MultiQC report to summary email"
    }

    // Check if we are only sending emails on failure
    email_address = params.email
    if (!params.email && params.email_on_fail && !workflow.success) {
        email_address = params.email_on_fail
    }

    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$baseDir/assets/email_template.txt")
    def txt_template = engine.createTemplate(tf).make(email_fields)
    def email_txt = txt_template.toString()

    // Render the HTML template
    def hf = new File("$baseDir/assets/email_template.html")
    def html_template = engine.createTemplate(hf).make(email_fields)
    def email_html = html_template.toString()

    // Render the sendmail template
    def smail_fields = [ email: email_address, subject: subject, email_txt: email_txt, email_html: email_html, baseDir: "$baseDir", mqcFile: mqc_report, mqcMaxSize: params.max_multiqc_email_size.toBytes() ]
    def sf = new File("$baseDir/assets/sendmail_template.txt")
    def sendmail_template = engine.createTemplate(sf).make(smail_fields)
    def sendmail_html = sendmail_template.toString()

    // Send the HTML e-mail
    if (email_address) {
        try {
            if (params.plaintext_email) { throw GroovyException('Send plaintext e-mail, not HTML') }
            // Try to send HTML e-mail using sendmail
            [ 'sendmail', '-t' ].execute() << sendmail_html
            log.info "[nf-core/transcriptcorral] Sent summary e-mail to $email_address (sendmail)"
        } catch (all) {
            // Catch failures and try with plaintext
            [ 'mail', '-s', subject, email_address ].execute() << email_txt
            log.info "[nf-core/transcriptcorral] Sent summary e-mail to $email_address (mail)"
        }
    }

    // Write summary e-mail HTML to a file
    def output_d = new File("${params.outdir}/pipeline_info/")
    if (!output_d.exists()) {
        output_d.mkdirs()
    }
    def output_hf = new File(output_d, "pipeline_report.html")
    output_hf.withWriter { w -> w << email_html }
    def output_tf = new File(output_d, "pipeline_report.txt")
    output_tf.withWriter { w -> w << email_txt }

    c_green = params.monochrome_logs ? '' : "\033[0;32m";
    c_purple = params.monochrome_logs ? '' : "\033[0;35m";
    c_red = params.monochrome_logs ? '' : "\033[0;31m";
    c_reset = params.monochrome_logs ? '' : "\033[0m";

    if (workflow.stats.ignoredCount > 0 && workflow.success) {
        log.info "-${c_purple}Warning, pipeline completed, but with errored process(es) ${c_reset}-"
        log.info "-${c_red}Number of ignored errored process(es) : ${workflow.stats.ignoredCount} ${c_reset}-"
        log.info "-${c_green}Number of successfully ran process(es) : ${workflow.stats.succeedCount} ${c_reset}-"
    }

    if (workflow.success) {
        log.info "-${c_purple}[nf-core/transcriptcorral]${c_green} Pipeline completed successfully${c_reset}-"
    } else {
        checkHostname()
        log.info "-${c_purple}[nf-core/transcriptcorral]${c_red} Pipeline completed with errors${c_reset}-"
    }

}


def nfcoreHeader() {
    // Log colors ANSI codes
    c_black = params.monochrome_logs ? '' : "\033[0;30m";
    c_blue = params.monochrome_logs ? '' : "\033[0;34m";
    c_cyan = params.monochrome_logs ? '' : "\033[0;36m";
    c_dim = params.monochrome_logs ? '' : "\033[2m";
    c_green = params.monochrome_logs ? '' : "\033[0;32m";
    c_purple = params.monochrome_logs ? '' : "\033[0;35m";
    c_reset = params.monochrome_logs ? '' : "\033[0m";
    c_white = params.monochrome_logs ? '' : "\033[0;37m";
    c_yellow = params.monochrome_logs ? '' : "\033[0;33m";

    return """    -${c_dim}--------------------------------------------------${c_reset}-
                                            ${c_green},--.${c_black}/${c_green},-.${c_reset}
    ${c_blue}        ___     __   __   __   ___     ${c_green}/,-._.--~\'${c_reset}
    ${c_blue}  |\\ | |__  __ /  ` /  \\ |__) |__         ${c_yellow}}  {${c_reset}
    ${c_blue}  | \\| |       \\__, \\__/ |  \\ |___     ${c_green}\\`-._,-`-,${c_reset}
                                            ${c_green}`._,._,\'${c_reset}
    ${c_purple}  nf-core/transcriptcorral v${workflow.manifest.version}${c_reset}
    -${c_dim}--------------------------------------------------${c_reset}-
    """.stripIndent()
}

def checkHostname() {
    def c_reset = params.monochrome_logs ? '' : "\033[0m"
    def c_white = params.monochrome_logs ? '' : "\033[0;37m"
    def c_red = params.monochrome_logs ? '' : "\033[1;91m"
    def c_yellow_bold = params.monochrome_logs ? '' : "\033[1;93m"
    if (params.hostnames) {
        def hostname = "hostname".execute().text.trim()
        params.hostnames.each { prof, hnames ->
            hnames.each { hname ->
                if (hostname.contains(hname) && !workflow.profile.contains(prof)) {
                    log.error "====================================================\n" +
                            "  ${c_red}WARNING!${c_reset} You are running with `-profile $workflow.profile`\n" +
                            "  but your machine hostname is ${c_white}'$hostname'${c_reset}\n" +
                            "  ${c_yellow_bold}It's highly recommended that you use `-profile $prof${c_reset}`\n" +
                            "============================================================"
                }
            }
        }
    }
}
