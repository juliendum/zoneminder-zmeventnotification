FROM zoneminderhq/zoneminder:latest-ubuntu18.04
ARG CUDA_VERSION="none"
ARG BUILD_DEPS="curl wget git build-essential cmake python-dev python3-dev python3-pip libopenblas-dev liblapack-dev libblas-dev libsm-dev zlib1g-dev libjpeg8-dev libtiff5-dev libpng-dev"
ARG CUDA_DEPS="nvidia-cuda-toolkit nvidia-cuda-dev g++-6 gcc-6"
ARG BUILD_DIR="/tmp/build"

# Install dependencies.
RUN mkdir -p "$BUILD_DIR" \
    && apt-get update \
    && apt-get --assume-yes install \
        sudo \
        libcrypt-mysql-perl \
        libcrypt-eksblowfish-perl \
        libmodule-build-perl \
        libyaml-perl \
        libjson-perl \
        libfile-spec-native-perl \
        libgetopt-long-descriptive-perl \
        libconfig-inifiles-perl \
        liblwp-protocol-https-perl \
        python-numpy \
        python3 \
        python3-pip \
        python3-numpy \
        python-idna \
        python3-idna \
        libsm6 \
        libxrender1 \
        libfontconfig1 \
        $([ "$CUDA_VERSION" = 'none' ] && echo -n "" || echo -n "$CUDA_DEPS") \
        $BUILD_DEPS \
    && curl "https://bootstrap.pypa.io/get-pip.py" -o "$BUILD_DIR/get-pip.py" \
    && python "$BUILD_DIR/get-pip.py" \
    && python3 -m pip install --upgrade pip \
    && pip install future \
    && pip3 install future \
    && perl -MCPAN -e "install Net::WebSocket::Server" \
    && perl -MCPAN -e "install Net::MQTT::Simple"

# Build opencv
RUN git clone "https://github.com/opencv/opencv.git" "$BUILD_DIR/opencv" \
    && git clone "https://github.com/opencv/opencv_contrib.git" "$BUILD_DIR/opencv_contrib" \
    && mkdir -p "$BUILD_DIR/opencv/build" \
    && cd "$BUILD_DIR/opencv/build" \
    && CC=gcc-6 CXX=g++-6 cmake \
        -DCMAKE_BUILD_TYPE=RELEASE \
       	-DCMAKE_INSTALL_PREFIX=/usr/local \
       	-DOPENCV_EXTRA_MODULES_PATH="$BUILD_DIR/opencv_contrib/modules" \
       	-DINSTALL_C_EXAMPLES=OFF \
       	-DOPENCV_ENABLE_NONFREE=ON \
       	-DWITH_CUDA=$([ "$CUDA_VERSION" = "none" ] && echo "OFF" || echo "ON") \
       	-DWITH_CUDNN=$([ "$CUDA_VERSION" = "none" ] && echo "OFF" || echo "ON") \
       	-DOPENCV_DNN_CUDA=$([ "$CUDA_VERSION" = "none" ] && echo "OFF" || echo "ON") \
       	-DENABLE_FAST_MATH=$([ "$CUDA_VERSION" = "none" ] && echo "OFF" || echo "ON") \
       	-DCUDA_FAST_MATH=$([ "$CUDA_VERSION" = "none" ] && echo "OFF" || echo "ON") \
       	-DWITH_CUBLAS=$([ "$CUDA_VERSION" = "none" ] && echo "OFF" || echo "ON") \
       	-DCUDA_ARCH_BIN=$CUDA_VERSION \
       	-DBUILD_opencv_python2=ON \
       	-DBUILD_opencv_python3=ON \
       	.. \
    && echo "Starting make with $(grep -cE '^processor\s+:\s+[0-9]+' /proc/cpuinfo) theads." \
    && make -j$(grep -cE '^processor\s+:\s+[0-9]+' /proc/cpuinfo) \
    && make install \
    && ldconfig

# Confirm opencv is working with python.
COPY ./scripts/print_cv2_info.py "$BUILD_DIR"
RUN python "$BUILD_DIR/print_cv2_info.py" && python3 "$BUILD_DIR/print_cv2_info.py"

# Install remaining python dependencies that rely on opencv.
RUN pip install face_recognition

# Install zmeventnotification.
RUN git clone "https://github.com/pliablepixels/zmeventnotification.git" \
    && cd zmeventnotification \
    && git fetch --tags \
    && git checkout $(git describe --tags $(git rev-list --tags --max-count=1)) \
    && ./install.sh --no-interactive --install-es --install-hook --install-config --no-pysudo \
    && mkdir -p /var/lib/zmeventnotification/push/ \
    && chown www-data /var/lib/zmeventnotification/push/ -R

# Cleanup
RUN apt-get --assume-yes remove $BUILD_DEPS \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf "$BUILD_DIR"
