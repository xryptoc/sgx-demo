## tips

---

#### build and run:

- docker pull teaclave/teaclave-build-ubuntu-1804-sgx-2.9.1:latest
- docker run --rm -v ./:/root/sgx -ti teaclave/teaclave-build-ubuntu-1804-sgx-2.9.1:latest
- cd /root/sgx
- SGX_MODE=SW make
- ./app.out