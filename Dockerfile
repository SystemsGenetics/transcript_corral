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
