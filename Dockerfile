FROM nfcore/base:1.9
LABEL authors="Matthew McGowan" \
      description="Docker image containing all software requirements for the nf-core/transcriptcorral pipeline"

# Install the conda environment
COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a

# Add conda installation dir to PATH (instead of doing 'conda activate')
ENV PATH /opt/conda/envs/nf-core-transcriptcorral-1.0dev/bin:$PATH

# Dump the details of the installed packages to a file for posterity
RUN conda env export --name nf-core-transcriptcorral-1.0dev > nf-core-transcriptcorral-1.0dev.yml

# Installing make
RUN apt-get --allow-releaseinfo-change --fix-missing -y update
RUN apt-get install -y make
RUN apt-get install -y g++
RUN apt-get install zlib1g-dev

# Installing TrimGalore
RUN wget https://github.com/FelixKrueger/TrimGalore/archive/0.6.6.tar.gz -O trim_galore.tar.gz \
  && tar -xvf trim_galore.tar.gz

ENV PATH "$PATH:/TrimGalore-0.6.6"

# Installing Jellyfish2 and RCorrector
RUN wget https://github.com/gmarcais/Jellyfish/releases/download/v2.3.0/jellyfish-2.3.0.tar.gz \
  && tar -xvf jellyfish-2.3.0.tar.gz

ENV PATH "$PATH:/jellyfish-2.3.0"

RUN git clone https://github.com/mourisl/rcorrector.git \
  && cd rcorrector \
  && make \
  && cd ..

ENV PATH "$PATH:/rcorrector"


# Get the non-redundant SILVA LSU databases and combine them
RUN mkdir SILVA_db \
  && cd SILVA_db \
  && wget https://www.arb-silva.de/fileadmin/silva_databases/current/Exports/SILVA_138.1_LSURef_NR99_tax_silva.fasta.gz \
  && wget https://www.arb-silva.de/fileadmin/silva_databases/current/Exports/SILVA_138.1_SSURef_NR99_tax_silva.fasta.gz \
  && zcat *.fasta.gz > combined_silva.fasta \
  && sed '/^[^>]/s/U/T/g' combined_silva.fasta > combined_silva_Tfixed.fasta \
  && bowtie2-build combined_silva_Tfixed.fasta combined_silva_reference


WORKDIR /

# Getting scripts to handle corrected files from Harvard Informatics GitHub repository
RUN git clone https://github.com/harvardinformatics/TranscriptomeAssemblyTools
ENV PATH "$PATH:/TranscriptomeAssemblyTools"
# ----------------------------
# Aspera is not a conda module so we have to manually include it.
# Aspera can only be installed as a non-root user
RUN groupadd -g 61000 gemmaker \
  && useradd -g 61000 --no-log-init --create-home --shell /bin/bash -u 61000 gemmaker
USER gemmaker
WORKDIR /home/gemmaker

RUN wget -q https://download.asperasoft.com/download/sw/connect/3.8.1/ibm-aspera-connect-3.8.1.161274-linux-g2.12-64.tar.gz \
  && tar -xf ibm-aspera-connect-3.8.1.161274-linux-g2.12-64.tar.gz \
  && ./ibm-aspera-connect-3.8.1.161274-linux-g2.12-64.sh \
  && rm ibm-aspera-connect-3.8.1.161274-linux-g2.12-64.sh


USER root
WORKDIR /root

RUN mv /home/gemmaker/.aspera /opt/aspera

# Make sure the ascp command is in the path and to support future
# updates of aspera we'll add a new variable ASPERA_KEY that can be
# used in the GEMmaker bash code.
ENV PATH "$PATH:/opt/aspera/connect/bin"
ENV ASPERA_KEY "/opt/aspera/connect/etc/asperaweb_id_dsa.openssh"

WORKDIR /

# Adding the Trinity Docker image
FROM trinityrnaseq/trinityrnaseq:2.13.2