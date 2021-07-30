.. figure:: images/nf-core-transcriptcorral_logo.png
   :alt: tc_logo

.. image:: images/transcript_lasso.png
   :alt: lasso_logo

Welcome to TranscriptCorral's documentation!
====================================

TranscriptCorral is a NF-core compatible `Nextflow <https://www.nextflow.io/>`_ workflow for large-scale *de novo* transcriptome meta-assembly for RNA sequencing data

nf-core Compatibility
---------------------
GEMmaker is an `nf-core <https://nf-co.re/>`_ compatible workflow, however, GEMmaker is not an official nf-core workflow.  This is because nf-core offers the `nf-core/rnaseq <https://nf-co.re/rnaseq>`_ workflow which is an excellent workflow for RNA-seq analysis that provides similar functionality to GEMmaker.  However, GEMmaker is different in that it can scale to thousands of samples without exceeding local storage resources by running samples in batches and removing intermediate files.  It can do the same for smaller sample sets on machines with less computational resources.  This ability to scale is a unique adaption that is currently not provided by Nextflow.   When Nextflow does provide support for batching and scaling, the `nf-core/rnaseq <https://nf-co.re/rnaseq>`_ will be updated and GEMmaker will probably be retired in favor of the nf-core workflow. Until then, if you are limited by storage GEMmaker can help!

Acknowledgments
---------------
Development of TranscriptCorral was funded by the U.S. National Science Foundation Award `#1659300 <https://www.nsf.gov/awardsearch/showAward?AWD_ID=1659300&HistoricalAwards=false>`_.

.. toctree::
   :maxdepth: 2
   :caption: Contents:

   installation
   execution
   core_parameters
   optional_parameters
   results
   whats_next
   troubleshooting
