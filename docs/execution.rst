.. _execution:

Step 3: Run TranscriptCorral
--------------------

How to Launch TranscriptCorral
''''''''''''''''''''''
.. note::

    For the examples on this page, Singularity will be used.  Singularity will automatically retrieve the TranscriptCorral Docker images and by default will store them in the ``work`` folder that Nextflow creates. However, Nextflow may warn that a cache directory is not set. If you intend to run TranscriptCorral multipe times, you may wish to designate a permanent cache directory by seting the ``NXF_SINGULARITY_CACHEDIR`` prior to running TranscriptCorral. You can learn more at the `nf-core tools page <https://nf-co.re/tools/#singularity-cache-directory>`_

Use Trinity
............
To run TranscriptCorral in single assembly mode using only Trinity you need to specify:

- A file containing a set of SRA run IDs you want to download or the path were FASTQ files are stored on the local system.

For example:

.. code:: bash

  nextflow run systemsgenetics/TranscriptCorral -profile singularity \
    --pipeline trinity \
    --sras SRAs.txt

Use Local FASTQ Files
.....................
If your FASTQ files are local to your computer you must provide the ``--input`` argument when launching Nextflow and indicate the `GLOB pattern <https://en.wikipedia.org/wiki/Glob_(programming)>`_ than is needed to find the files:

.. code:: bash

  nextflow run systemsgenetics/TranscriptCorral -profile singularity \
    --pipeline trinity \
    --input "../../01-input_data/RNA-seq/fastq/*{1,2}.fastq"

In the example above the ``--input`` argument indicates that FASTQ files are found in the ``../../01-input_data/RNA-seq/fastq/`` directory and TranscriptCorral should use all files that match the GLOB pattern ``*{1,2}.fastq``.

.. note ::

  TranscriptCorral currently expects that all fASTQ files have a `1` or `2` suffix. For paired files two files with the same name but each suffix respectively.

Resuming After Failure
''''''''''''''''''''''
If for some reason TranscriptCorral fails to fully complete and Nextflow reports some form of error. You can resume execution of the workflow, afer correcting any problems, by passing the ``-resume`` flag to TranscriptCorral. For example to resume a failed run:

.. code:: bash

  nextflow run systemsgenetics/TranscriptCorral -profile singularity \
    -resume \
    --pipeline trinity \
    --sras SRAs.txt

TranscriptCorral should resume processing of samples without starting over.

Skipping Samples
................
You may find that a sample is problematic. It may be corrupt or has other problems that may cause GEMaker to fail. For such samples that cause TranscriptCorral to fail, you have two options. You can either remove the bad samples and restart TranscriptCorral or you can resume, as just described in the previous section, but first add the sample names to a new file, one per line, then, use the ``--skip_samples`` argument to tell TranscriptCorral about this file.  For example:

.. code:: bash

  nextflow run systemsgenetics/TranscriptCorral -profile singularity \
    --pipeline kallisto \
    --kallisto_index_path Arabidopsis_thaliana.TAIR10.kallisto.indexed \
    --sras SRAs.txt \
    --skip_samples samples2skip.txt

In the example above any samples that should be skipped should be added to the ``samples2skip.txt`` file.

.. warning ::

    Note, when you provide SRA IDs to TranscriptCorral you provide the RUN IDs, but multiple run IDs can be contained in a single sample.  To skip a sample, you must provide the sample ID. For SRA, these  begin with the prefix SRX, DRX or ERX, where as run IDs begin with SRR, DRR or ERR.

Running on a Cluster
''''''''''''''''''''
If you want to run TranscriptCorral on a local High Performance Computing Cluster (HPC) that uses a scheduler such as SLURM or PBS, you must first create a configuration file to help TranscriptCorral know how to submit jobs.  The file should be named ``nextflow.config`` and be placed in the same directory where you are running TranscriptCorral.  Below is an example ``nextflow.config`` file for executing TranscriptCorral on a cluster that uses the SLURM scheduler.

.. code::

   profiles {
      my_cluster {
         process {
            executor = "slurm"
            queue = "<queue name>"
            clusterOptions = ""
         }
         executor {
            queueSize = 120
        }
      }
   }

In the example above we created a new profile named ``my_cluster``. Within the stanza, the placeholder text ``<queue name>`` should be replaced with the name of the queue on which you are allowed to submit jobs. If you need to provide specific options that you would normally provide in a SLURM submission script (such as an account or other node targetting settings) you can use the ``clusterOptions`` setting.

Next, is an example SLURM submission script for submitting a job to run TranscriptCorral. Please note, this is just an example and your specific cluster may require slightly different configuration/usage. The script assumes your cluster uses the lmod system for specifying software.

.. code:: bash

    #!/bin/sh
    #SBATCH --partition=<queue_name>
    #SBATCH --nodes=1
    #SBATCH --ntasks-per-node=1
    #SBATCH --time=10:00:00
    #SBATCH --job-name=TranscriptCorral
    #SBATCH --output=%x-%j.out
    #SBATCH --error=%x-%j.err

    module add java nextflow singularity

    nextflow run systemsgenetics/TranscriptCorral \
      -profile my_cluster,singularity \
      -resume \
      --pipeline trinity \
      --sras  SRA_IDs.txt \
      --max_cpus 120

Notice in the call to nextflow, the profile ``my_cluster`` has been added along with ``singularity``, also, the ``--max_cpus`` argument has been set to the same size as the ``queueSize`` value in the config file. The default value of ``--max_cpus`` is 4 and won't allow the workflow to expand beyond 4 CPUs if it is not increased to match the config file.

Increasing Resources
.....................
You may find that default resources are not adequate for the size of your data set.  You can alter resources requested for each step of the TranscriptCorral workflow by using the ``withLabel`` scope selector in a custom ``nextflow.config`` file.

For example, if you have thousands of SRA data sets to process, you may need more memory allocated to the ``retrieve_sra_metadata`` step of the workflow. All steps in the workflow have a "label" that you can use to indicate which step resources should be changed. Below is an example ``nextflow.config`` file where a new profile named ``custom`` is provided where the memory has been increased for the ``retrieve_sra_metadata``.

.. code::

    profiles {
        custom {
            process {
                withLabel:retrieve_sra_metadata {
                    memory = "10.GB"
         	    }
            }
        }
    }

This new ``custom`` profile can be used when calling TranscriptCorral. The following is an example Kallisto run of TranscriptCorral using the custom and singularity profiles:

.. code:: bash

  nextflow run systemsgenetics/TranscriptCorral -profile custom,singularity \
    --pipeline trinity \
    --sras SRAs.txt

Nextflow provides many "directives", such as ``memory`` that you can use to alter or customize the resources of any step (or process) in the workflow.  You can find more about these in the `Nextflow documentation. <https://www.nextflow.io/docs/latest/process.html#directives>`_ Some useful directives are:

- `memory <https://www.nextflow.io/docs/latest/process.html#memory>`_: change the amount of memory allocated to the step.
- `time <https://www.nextflow.io/docs/latest/process.html#time>`_: change the amount of time allocated to the step.
- `disk <https://www.nextflow.io/docs/latest/process.html#disk>`_: defines how much local storage is required.
- `cpus <https://www.nextflow.io/docs/latest/process.html#cpus>`_: defines how many threads (or CPUs) the task can use.

The "labels" that TranscriptCorral provides and which you can set custom directives include:

- ``retrieve_sra_metadata``:  For the step that retrieves metadata from the NCBI web services for the SRR run IDs that were provided. This step can require more memory than the defaults if there are huge numbers of samples.
- ``download_runs``: For the step is used for downloading SRA files from NCBI.
- ``fastq_dump``: For the step that is used after downloading SRA files and converting them to FASTQ files.
- ``fastqc``: For the step where the FastQC program is used which generates quality reports on FASTQ files.
- ``multiqc``: For the step that runs the MultiQC results summary report.
- ``multithreaded``:  For all of the tools that support multithreading you can use this label to set a default number of CPUs using the ``cpus`` directive.  By using this label you set set the same number of ``cpus`` for all multithreaded steps at once.

Using the Development Version
'''''''''''''''''''''''''''''
New updates to TranscriptCorral, prior to issuing a formal release, are held in the ``dev`` branch of the TranscriptCorral github repository. It is recommended to always use a formal release of TranscriptCorral, however, you can test the most recent improvements prior to release.  To do so, use the ``-r dev`` argument when running TranscriptCorral. For example:

.. code:: bash

  nextflow run systemsgenetics/TranscriptCorral -r dev -profile singularity \
    --pipeline kallisto \
    --kallisto_index_path Arabidopsis_thaliana.TAIR10.kallisto.indexed \
    --sras SRAs.txt

The ``-r dev`` argument forces Nextflow to use the development version of TranscriptCorral rather than the most recent stable version.

.. note::

    You can find the most recent documentation for the ``dev`` branch at https://TranscriptCorral.readthedocs.io/en/dev/