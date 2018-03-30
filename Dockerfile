FROM continuumio/miniconda3
MAINTAINER vsochat@stanford.edu

# docker build -t vanessa/tunel .

RUN apt-get update 
RUN apt-get -y install build-essential
RUN apt-get -y install apt-utils cmake wget unzip libffi-dev libssl-dev \
                       libtool autotools-dev automake autoconf git \
                       libarchive-dev squashfs-tools uuid-dev \
                       vim jq aria2 nginx

ENV DEBIAN_FRONTEND noninteractive
ENV PATH /opt/conda/bin:$PATH
RUN mkdir /code
RUN mkdir /data

# Install Globus Personal Connect

WORKDIR /opt
RUN wget https://s3.amazonaws.com/connect.globusonline.org/linux/stable/globusconnectpersonal-2.3.4.tgz && \
    tar xzf globusconnectpersonal-2.3.4.tgz && mv globusconnectpersonal-2.3.4 globus 

# Sregistry with Globus
RUN git clone -b integration/globus https://www.github.com/vsoch/sregistry-cli && \
              cd sregistry-cli && python setup.py install && /opt/conda/bin/pip install globus-cli
#RUN git clone https://www.github.com/singularityhub/sregistry-cli && \
#              cd sregistry-cli && python setup.py install

WORKDIR /tmp
RUN wget https://github.com/singularityware/singularity/releases/download/2.4.3/singularity-2.4.3.tar.gz \
    && tar -xzf singularity-2.4.3.tar.gz && cd singularity-2.4.3 && ./autogen.sh && ./configure --prefix=/usr/local \
    && make && make install

ADD . /code

# Set up nginx
RUN cp /code/script/nginx.conf /etc/nginx/nginx.conf && \
    cp /code/script/nginx.gunicorn.conf /etc/nginx/sites-enabled/default && \
    chmod u+x /code/script/entrypoint.sh && \
    cp /code/tunel/config_dummy.py /code/tunel/config.py && \
    chmod u+x /code/script/generate_key.sh && \
    /bin/bash /code/script/generate_key.sh /code/tunel/config.py

RUN /opt/conda/bin/pip install --upgrade pip && \
    /opt/conda/bin/pip install -r /code/requirements.txt

# Install HPC Container Maker
#RUN git clone https://github.com/NVIDIA/hpc-container-maker.git && cd hpc-container-maker && python setup.py install

# Clean up
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add a user for Globus
RUN useradd -ms /bin/bash globus-user
RUN echo "globus-user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
USER globus-user

ENTRYPOINT ["/bin/bash", "/code/script/entrypoint.sh"]
WORKDIR /code
EXPOSE 5000
EXPOSE 80
