set -e
MKL_FILE_NAME=CNTKCustomMKL-Linux-3.tgz
MKL_URL=https://amsword.blob.core.windows.net/setup/$MKL_FILE_NAME
MKL_TARGET_FOLDER=/usr/local/CNTKCustomMKL
OMP_FILE=openmpi-1.10.3.tar.gz
OMP_URL=https://www.open-mpi.org/software/ompi/v1.10/downloads/$OMP_FILE
PROTOL_BUF_FILE=v3.1.0.tar.gz
PROTOL_BUF_URL=https://github.com/google/protobuf/archive/$PROTOL_BUF_FILE
LIBZIP_FOLDER=libzip-1.1.2
LIBZIP_FILE=${LIBZIP_FOLDER}.tar.gz
LIBZIP_URL=http://nih.at/libzip/$LIBZIP_FILE

# normally boost version is 1.54 
BOOST_FOLDER=boost_1_60_0
BOOST_URL=https://sourceforge.net/projects/boost/files/boost/1.60.0/${BOOST_FOLDER}.tar.gz/download

CUB_VERSION=1.4.1
CUB_FOLDER=cub-${CUB_VERSION}
CUB_NAME_IN_URL=${CUB_VERSION}.zip
CUB_URL=https://github.com/NVlabs/cub/archive/${CUB_NAME_IN_URL}
CUDNN_FILE=cudnn-8.0-linux-x64-v6.0.tgz
CUDNN_URL=http://developer.download.nvidia.com/compute/redist/cudnn/v6.0/$CUDNN_FILE


# setup MKL
if [ ! -f $MKL_FILE_NAME ]; then
    wget $MKL_URL
fi
if [ ! -d $MKL_TARGET_FOLDER ]; then
    sudo mkdir $MKL_TARGET_FOLDER
    sudo tar -xzf CNTKCustomMKL-Linux-3.tgz -C $MKL_TARGET_FOLDER 
fi

# setup MPI
if [ ! -f $OMP_FILE ]; then
    wget $OMP_URL
    tar -xzvf ./openmpi-1.10.3.tar.gz
    cd openmpi-1.10.3
    ./configure --prefix=/usr/local/mpi
    make -j all
    sudo make install
    cd ..
fi
export PATH=/usr/local/mpi/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/mpi/lib:$LD_LIBRARY_PATH

# protobuf
if [ ! -f $PROTOL_BUF_FILE ]; then
    sudo apt-get install -y curl autoconf
    wget $PROTOL_BUF_URL
    tar -xzf v3.1.0.tar.gz
    cd protobuf-3.1.0
    ./autogen.sh
    ./configure CFLAGS=-fPIC CXXFLAGS=-fPIC --disable-shared \
        --prefix=/usr/local/protobuf-3.1.0
    make -j $(nproc)
    sudo make install
    cd ..
fi

if [ ! -d $LIBZIP_FOLDER ]; then
    wget $LIBZIP_URL
    tar -xzvf ./$LIBZIP_FILE
    cd $LIBZIP_FOLDER
    ./configure
    make -j all
    sudo make install
fi

export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

if [ ! -d $BOOST_FOLDER ]; then
    sudo apt-get install libbz2-dev
    sudo apt-get install python-dev
    
    wget -q -O - https://sourceforge.net/projects/boost/files/boost/1.60.0/boost_1_60_0.tar.gz/download | tar -xzf - 
    cd $BOOST_FOLDER
    ./bootstrap.sh --prefix=/usr/local/boost-1.60.0
    sudo ./b2 -d0 -j"$(nproc)" install  
    cd ..
fi

if [ ! -d $CUB_FOLDER ]; then
    wget $CUB_URL
    unzip ./${CUB_NAME_IN_URL}
    sudo cp -r $CUB_FOLDER /usr/local
fi

# opencv
if [ ! -d 'opencv-3.1.0' ]; then
    wget https://github.com/Itseez/opencv/archive/3.1.0.zip
    unzip 3.1.0.zip
    cd opencv-3.1.0
    mkdir release
    cd release
    cmake -D WITH_CUDA=OFF -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local/opencv-3.1.0 ..
    make all
    sudo make install
    cd ../../
fi

if [ ! -f $CUDNN_FILE ]; then
    wget $CUDNN_URL
    tar -xzvf ./$CUDNN_FILE
    sudo mkdir -p /usr/local/cudnn-6.0
    sudo cp -r cuda /usr/local/cudnn-6.0
    rm cuda -rf
fi

export LD_LIBRARY_PATH=/usr/local/cudnn-6.0/cuda/lib64:$LD_LIBRARY_PATH

sudo apt-get install zlib1g-dev

# setup the nccl
if [ ! -d 'nccl' ]; then
    git clone https://github.com/NVIDIA/nccl.git && \
            cd nccl && sudo make -j install && \
            cd .. && sudo rm -rf nccl
fi

# setup some magic path
sudo mkdir -p /usr/src/gdk/nvml/lib && \
    sudo cp -av /usr/local/cuda/lib64/stubs/libnvidia-ml* /usr/src/gdk/nvml/lib && \
    sudo mkdir -p /usr/include/nvidia/gdk && \
    sudo cp -av /usr/local/cuda/include/nvml.h /usr/include/nvidia/gdk/nvml.h

# download the cntk and build
mkdir -p ~/code
cd ~/code
git clone https://github.com/Microsoft/cntk
cd cntk
git submodule update --init -- Source/Multiverso
# the latest version has some build issue
git checkout -b tmp 7d66c47f613cf2101b72652671e9bb502d3a03cd
# install the swig for python
/Tools/devInstall/Linux/install-swig.sh
mkdir -p build/release
cd build/release
# compile for python
../../configure --with-swig=/usr/local/swig-3.0.10
make -j all
cd ../../


