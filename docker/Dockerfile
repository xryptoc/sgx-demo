FROM  teaclave/teaclave-build-ubuntu-1804-sgx-2.9.1:latest

WORKDIR /root/sgx

# ENV for sgx sdk
ENV SGX_SDK=/opt/sgxsdk
ENV LD_LIBRARY_PATH $SGX_SDK/lib64:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH=:/opt/sgxsdk/pkgconfig

ADD . /root/sgx

# build SW mode
RUN SGX_MODE=SW make

CMD [ "./app.out" ]