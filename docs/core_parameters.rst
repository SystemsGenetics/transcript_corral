.. _core_parameters:

Core Parameters
-------------

The goal of TranscriptCorral is to simplify the process of using the same RNAseq data with many different assemblers to obtain a combined meta-assembly that combines the best transcripts. To keep the initial setup as easy as possible, we have tried to consolidate the large number of tunable parameters for each assembler into a couple different labeled strategies. This helps reduce user option fatigue and should allow you to quickly get started assembling your data without having too much under-the-hood management. 

However, there are still several parameters that you as a user will need to provide to get started:

INPUT DATA
''''''''''''''''''

DESCRIBE DIFFERENT INPUT STRATEGIES HERE

ASSEMBLY TYPE/STRATEGY:
''''''''''''''''''
Single assembly

The simplest use of TranscriptCorral is to only use a single assembler. To do this, you will need to use the --no_meta_assembly flag when executing the pipeline. You will also need to provide which assembler to use. Here is an example of executing TranscriptCorral to produce an assembly using only Trinity:

EXAMPLE HERE

Multiple assembly

Based on several studies (REFERENCES HERE) that have tried to benchmark different assembly strategies, it has been shown that combining assemblies across multiple different assembly algorithms can often result in a meta-assembly that outperforms any single assembly.

