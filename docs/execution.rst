.. _execution:

Step 3: Run Transcript Corral
--------------------

How to Launch The Workflow
''''''''''''''''''''''
As an example, we will indicate 3 SRA files for automatic retrieval and processing by listing them in a file named ``SRAs.txt``:

.. code:: bash

    SRR1058270
    SRR1058271
    SRR1058272

.. note::

    For the examples on this page, Singularity will be used.  Singularity will automatically retrieve the workflow Docker images and by default will store them in the ``work`` folder that Nextflow creates. However, Nextflow may warn that a cache directory is not set. If you intend to run this workflow multiple times, you may wish to designate a permanent cache directory by seting the ``NXF_SINGULARITY_CACHEDIR`` prior to running the workflow. You can learn more at the `nf-core tools page <https://nf-co.re/tools/#singularity-cache-directory>`_

Using Local FASTQ Files
.....................
If your FASTQ files are local to your computer you must provide the ``--input`` argument when launching Nextflow and indicate the `GLOB pattern <https://en.wikipedia.org/wiki/Glob_(programming)>`_ than is needed to find the files:

.. code:: bash

  nextflow run systemsgenetics/transcript_corral -profile singularity \
    --local_samples "../../01-input_data/RNA-seq/fastq/*{1,2}.fastq"

In the example above the ``--local_samples`` argument indicates that FASTQ files are found in the ``../../01-input_data/RNA-seq/fastq/`` directory and all files matching the GLOB pattern ``*{1,2}.fastq`` will be used.

.. note ::

  This workflow currently only works with paired-end files and expects that all fASTQ files have a `1` or `2` suffix. Paired files should consist of two files with the same name except for the numeric suffix.

Use Both Local and SRA Files
............................
You can combine data from the NCBI SRA with local files in a single run of GEMmaker by providing both the ``--sra_samples`` and ``--input`` arguments.

.. code:: bash

  nextflow run systemsgenetics/transcript_corral -profile singularity \
    --local_samples "../../01-input_data/RNA-seq/fastq/*{1,2}.fastq" \
    --sra_samples SRAs.txt

Including previous assemblies
............................
You can include previously assemblied transcriptomes, which will be incorporated with the new assemblies before meta-assembly with EvidentialGenes with the ``--input_assemblies`` arguments.

.. code:: bash

  nextflow run systemsgenetics/transcript_corral -profile singularity \
    --local_samples "../../01-input_data/RNA-seq/fastq/*{1,2}.fastq" \
    --sra_samples SRAs.txt \
    --input_assemblies "old_assembly.fa"

Specifying a particular assembler or skipping meta-assembly
............................
By default, Transcript Corral uses both Trinity and Trans-abyss assemblers and combines them with EvidentialGenes. However, it is possible to only use a single assembler and skip metaassembly with EvidentialGenes.

Using only Trinity without meta-assembly
.. code:: bash

  nextflow run systemsgenetics/transcript_corral -profile singularity \
    --sra_samples SRAs.txt \
    --use_transabyss false \
    --meta_assembly false

Using only Trans-abyss with meta-assembly
.. code:: bash

  nextflow run systemsgenetics/transcript_corral -profile singularity \
    --sra_samples SRAs.txt \
    --use_trinity false

Resuming After Failure
''''''''''''''''''''''
If for some reason the workflow fails to fully complete and Nextflow reports some form of error. You can resume execution of the workflow, afer correcting any problems, by using the ``-resume`` flag.

.. code:: bash

  nextflow run systemsgenetics/transcript_corral -profile singularity \
    -resume \
    --sra_samples SRAs.txt 

Skipping Samples
................
You may find that a sample is problematic. It may be corrupt or has other problems that may cause the workflow to fail. For such samples, you have two options. You can either remove the bad samples and restart, or you can resume. To resume, first add the sample names to a new file, one per line, then, use the ``--skip_samples`` argument to tell the workflow to skip those samples.  For example:

.. code:: bash

  nextflow run systemsgenetics/gemmaker -profile singularity \
    --sra_samples SRAs.txt \
    --skip_samples samples2skip.txt

In the example above any samples that should be skipped should be added to the ``samples2skip.txt`` file.

.. warning ::

    Note, when you provide SRA IDs, you provide the RUN IDs, but multiple run IDs can be contained in a single sample. To skip a sample, you must provide the sample ID. For SRA, these  begin with the prefix SRX, DRX or ERX, where as run IDs begin with SRR, DRR or ERR.

Running on a Cluster
''''''''''''''''''''
If you want to run this workflow on a local High Performance Computing Cluster (HPC) that uses a scheduler such as SLURM or PBS, you must first create a configuration file to help Nextflow know how to submit jobs.  The file should be named ``nextflow.config`` and be placed in the same directory where you are running the workflow.  Below is an example ``nextflow.config`` file for executing on a cluster that uses the SLURM scheduler.

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

Next, is an example SLURM submission script for submitting a job to run the workflow. Please note, this is just an example and your specific cluster may require slightly different configuration/usage. The script assumes your cluster uses the lmod system for specifying software.

.. code:: bash

    #!/bin/sh
    #SBATCH --partition=<queue_name>
    #SBATCH --nodes=1
    #SBATCH --cpus-per-task=4
    #SBATCH --ntasks-per-node=1
    #SBATCH --time=10:00:00
    #SBATCH --job-name=Trans_corral
    #SBATCH --output=%x-%j.out
    #SBATCH --error=%x-%j.err

    module add java nextflow singularity

    nextflow run systemsgenetics/transcript_corral \
      -profile my_cluster,singularity \
      -resume
      --sra_samples SRA_IDs.txt

Notice in the call to nextflow, the profile ``my_cluster`` has been added along with ``singularity``

Configuration
'''''''''''''
The instructions above provide details for running the workflow using Singularity. For most instances you probably won't need to make customizations to the workflow configuration. However, should you need to, GEMmaker is a `nf-core <https://nf-co.re/>`_ compatible workflow.  Therefore, it follows the general approach for workflow configuration which is described at the `nf-core Pipeline Configuration page <https://nf-co.re/usage/configuration>`_. Please see those instructions for the various platforms and settings you can configure.  However, below are some quick tips for tweaking the workflow:

In all cases, if you need to set some customizations you must first create a configuration file.  The file should be named ``nextflow.config`` and be placed in the same directory where you are running GEMmaker.

Configuration for a Cluster
...........................
To run on a computational cluster you will need to to create a custom configuration.  Instructions and examples are provided in the `Running on a Cluster`_ section.

Increasing Resources
.....................
You may find that default resources are not adequate for the size of your data set.  You can alter resources requested for each step of the GEMmaker workflow by using the ``withLabel`` scope selector in a custom ``nextflow.config`` file.

Nextflow provides many "directives", such as ``memory`` that you can use to alter or customize the resources of any step (or process) in the workflow.  You can find more about these in the `Nextflow documentation. <https://www.nextflow.io/docs/latest/process.html#directives>`_ Some useful directives are:

- `memory <https://www.nextflow.io/docs/latest/process.html#memory>`_: change the amount of memory allocated to the step.
- `time <https://www.nextflow.io/docs/latest/process.html#time>`_: change the amount of time allocated to the step.
- `disk <https://www.nextflow.io/docs/latest/process.html#disk>`_: defines how much local storage is required.
- `cpus <https://www.nextflow.io/docs/latest/process.html#cpus>`_: defines how many threads (or CPUs) the task can use.