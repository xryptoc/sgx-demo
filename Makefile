######## SGX SDK Settings ########
# 设置 SGX SDK 的路径、模式、架构和调试选项
# SGX SDK 安装路径
SGX_SDK ?= /opt/intel/sgxsdk
# SGX 模式：硬件模式(HW)
SGX_MODE ?= HW
# SGX 架构：64 位(x64)
SGX_ARCH ?= x64
# SGX 调试模式：启用(1)
SGX_DEBUG ?= 1

# 判断系统的位数，如果是 32 位，设置架构为 x86
ifeq ($(shell getconf LONG_BIT), 32)
    SGX_ARCH := x86
# 如果编译器标志中包含 -m32，也设置架构为 x86
else ifeq ($(findstring -m32, $(CXXFLAGS)), -m32)
    SGX_ARCH := x86
endif

# 根据架构选择编译器标志、库路径和工具路径
ifeq ($(SGX_ARCH), x86)
    SGX_COMMON_FLAGS := -m32                         # 设置 32 位编译标志
    SGX_LIBRARY_PATH := $(SGX_SDK)/lib               # 32 位库路径
    SGX_ENCLAVE_SIGNER := $(SGX_SDK)/bin/x86/sgx_sign # 使用 32 位签名工具
    SGX_EDGER8R := $(SGX_SDK)/bin/x86/sgx_edger8r     # 使用 32 位 Edger8r 工具
else
    SGX_COMMON_FLAGS := -m64                         # 设置 64 位编译标志
    SGX_LIBRARY_PATH := $(SGX_SDK)/lib64             # 64 位库路径
    SGX_ENCLAVE_SIGNER := $(SGX_SDK)/bin/x64/sgx_sign # 使用 64 位签名工具
    SGX_EDGER8R := $(SGX_SDK)/bin/x64/sgx_edger8r     # 使用 64 位 Edger8r 工具
endif

# 检查是否同时设置了调试模式和预发布模式
ifeq ($(SGX_DEBUG), 1)
ifeq ($(SGX_PRERELEASE), 1)
$(error Cannot set SGX_DEBUG and SGX_PRERELEASE at the same time!!)
# 如果两个都设置了，报错 "不能同时设置调试模式和预发布模式"
endif
endif

# 根据是否启用调试模式设置编译标志
ifeq ($(SGX_DEBUG), 1)
        SGX_COMMON_FLAGS += -O0 -g  # 调试模式：不进行优化，包含调试信息
else
        SGX_COMMON_FLAGS += -O2    # 生产模式：优化代码
endif

# 设置更多的编译器警告标志，确保代码质量
SGX_COMMON_FLAGS += -Wall -Wextra -Winit-self -Wpointer-arith -Wreturn-type \
                    -Waddress -Wsequence-point -Wformat-security \
                    -Wmissing-include-dirs -Wfloat-equal -Wundef -Wshadow \
                    -Wcast-align -Wcast-qual -Wconversion -Wredundant-decls
SGX_COMMON_CFLAGS := $(SGX_COMMON_FLAGS) -Wjump-misses-init -Wstrict-prototypes -Wunsuffixed-float-constants # C 编译标志
SGX_COMMON_CXXFLAGS := $(SGX_COMMON_FLAGS) -Wnon-virtual-dtor -std=c++11  # C++ 编译标志，使用 C++11 标准

######## App Settings ########

# 应用程序设置
ifneq ($(SGX_MODE), HW)
    Urts_Library_Name := sgx_urts_sim  # 如果不是硬件模式，使用仿真库
else
    Urts_Library_Name := sgx_urts      # 如果是硬件模式，使用真实库
endif

# 指定应用程序的源文件和包含路径
App_Cpp_Files := App/App.cpp $(wildcard App/TrustedLibrary/*.cpp)
App_Include_Paths := -IApp -I$(SGX_SDK)/include

# 设置应用程序的编译标志
App_C_Flags := -fPIC -Wno-attributes $(App_Include_Paths)

# 根据不同的配置模式，设置不同的宏定义
# Three configuration modes - Debug, prerelease, release
#   Debug - Macro DEBUG enabled.
#   Prerelease - Macro NDEBUG and EDEBUG enabled.
#   Release - Macro NDEBUG enabled.
ifeq ($(SGX_DEBUG), 1)
        App_C_Flags += -DDEBUG -UNDEBUG -UEDEBUG
else ifeq ($(SGX_PRERELEASE), 1)
        App_C_Flags += -DNDEBUG -DEDEBUG -UDEBUG
else
        App_C_Flags += -DNDEBUG -UEDEBUG -UDEBUG
endif

App_Cpp_Flags := $(App_C_Flags)
App_Link_Flags := -L$(SGX_LIBRARY_PATH) -l$(Urts_Library_Name) -lpthread 

# 生成对象文件的规则
App_Cpp_Objects := $(App_Cpp_Files:.cpp=.o)
# 指定生成的应用程序名称
App_Name := app.out

######## Enclave Settings ########
# 设置信任域版本脚本文件根据调试模式与硬件模式判断
Enclave_Version_Script := Enclave/Enclave.lds
ifeq ($(SGX_MODE), HW)
ifneq ($(SGX_DEBUG), 1)
ifneq ($(SGX_PRERELEASE), 1)
	# 硬件发布模式下使用的版本脚本文件
	# Choose to use 'Enclave.lds' for HW release mode
	Enclave_Version_Script = Enclave/Enclave.lds 
endif
endif
endif

# 仿真模式与硬件模式下使用不同的库
ifneq ($(SGX_MODE), HW)
    Trts_Library_Name := sgx_trts_sim      # 仿真模式库
    Service_Library_Name := sgx_tservice_sim # 仿真模式服务库
else
    Trts_Library_Name := sgx_trts         # 硬件模式库
    Service_Library_Name := sgx_tservice  # 硬件模式服务库
endif
Crypto_Library_Name := sgx_tcrypto        # 加密库

# 指定信任域的源文件和包含路径
Enclave_Cpp_Files := Enclave/Enclave.cpp $(wildcard Enclave/TrustedLibrary/*.cpp)
Enclave_Include_Paths := -IEnclave -I$(SGX_SDK)/include -I$(SGX_SDK)/include/libcxx -I$(SGX_SDK)/include/tlibc 

# 设置信任域的编译标志
Enclave_C_Flags := -nostdinc -fvisibility=hidden -fpie -fstack-protector -fno-builtin-printf $(Enclave_Include_Paths)
Enclave_Cpp_Flags := $(Enclave_C_Flags) -nostdinc++

# 启用安全链接选项
Enclave_Security_Link_Flags := -Wl,-z,relro,-z,now,-z,noexecstack

# 生成信任域的正确链接规则
# 按步骤链接信任库
Enclave_Link_Flags := $(Enclave_Security_Link_Flags) \
    -Wl,--no-undefined -nostdlib -nodefaultlibs -nostartfiles -L$(SGX_LIBRARY_PATH) \
	-Wl,--whole-archive -l$(Trts_Library_Name) -Wl,--no-whole-archive \
	-Wl,--start-group -lsgx_tstdc -lsgx_tcxx -l$(Crypto_Library_Name) -l$(Service_Library_Name) -Wl,--end-group \
	-Wl,-Bstatic -Wl,-Bsymbolic -Wl,--no-undefined \
	-Wl,-pie,-eenclave_entry -Wl,--export-dynamic  \
	-Wl,--defsym,__ImageBase=0 \
	-Wl,--version-script=$(Enclave_Version_Script)
# 指定信任域生成的对象文件
Enclave_Cpp_Objects := $(Enclave_Cpp_Files:.cpp=.o)
# 指定生成的信任域库名
Enclave_Name := enclave.so
Signed_Enclave_Name := enclave.signed.so
# 配置文件和测试密钥文件
Enclave_Config_File := Enclave/Enclave.config.xml
Enclave_Key := Enclave/Enclave_private.pem

# 生成不同的构建模式名称
ifeq ($(SGX_MODE), HW)
ifeq ($(SGX_DEBUG), 1)
	Build_Mode = HW_DEBUG
else ifeq ($(SGX_PRERELEASE), 1)
	Build_Mode = HW_PRERELEASE
else
	Build_Mode = HW_RELEASE
endif
else
ifeq ($(SGX_DEBUG), 1)
	Build_Mode = SIM_DEBUG
else ifeq ($(SGX_PRERELEASE), 1)
	Build_Mode = SIM_PRERELEASE
else
	Build_Mode = SIM_RELEASE
endif
endif


.PHONY: all run target
all: .config_$(Build_Mode)_$(SGX_ARCH)
	@$(MAKE) target

ifeq ($(Build_Mode), HW_RELEASE)
target: $(App_Name) $(Enclave_Name)
	@echo "The project has been built in release hardware mode."
	@echo "Please sign the $(Enclave_Name) first with your signing key before you run the $(App_Name) to launch and access the enclave."
	@echo "To sign the enclave use the command:"
	@echo "   $(SGX_ENCLAVE_SIGNER) sign -key <your key> -enclave $(Enclave_Name) -out <$(Signed_Enclave_Name)> -config $(Enclave_Config_File)"
	@echo "You can also sign the enclave using an external signing tool."
	@echo "To build the project in simulation mode set SGX_MODE=SIM. To build the project in prerelease mode set SGX_PRERELEASE=1 and SGX_MODE=HW."
else
target: $(App_Name) $(Signed_Enclave_Name)
ifeq ($(Build_Mode), HW_DEBUG)
	@echo "The project has been built in debug hardware mode."
else ifeq ($(Build_Mode), SIM_DEBUG)
	@echo "The project has been built in debug simulation mode."
else ifeq ($(Build_Mode), HW_PRERELEASE)
	@echo "The project has been built in pre-release hardware mode."
else ifeq ($(Build_Mode), SIM_PRERELEASE)
	@echo "The project has been built in pre-release simulation mode."
else
	@echo "The project has been built in release simulation mode."
endif
endif

# 运行目标规则，首先构建所有目标，然后运行应用程序，除非是在硬件发布模式下。
run: all
ifneq ($(Build_Mode), HW_RELEASE)
	@$(CURDIR)/$(App_Name)
	@echo "RUN  =>  $(App_Name) [$(SGX_MODE)|$(SGX_ARCH), OK]"
endif

# 配置文件生成规则，如果构建模式和架构改变，重新生成配置
.config_$(Build_Mode)_$(SGX_ARCH):
	@rm -f .config_* $(App_Name) $(Enclave_Name) $(Signed_Enclave_Name) $(App_Cpp_Objects) App/Enclave_u.* $(Enclave_Cpp_Objects) Enclave/Enclave_t.*
	@touch .config_$(Build_Mode)_$(SGX_ARCH)

######## App Objects ########

# 生成 Enclave_u.h，如果 Enclave.edl 改变
App/Enclave_u.h: $(SGX_EDGER8R) Enclave/Enclave.edl
	@cd App && $(SGX_EDGER8R) --untrusted ../Enclave/Enclave.edl --search-path ../Enclave --search-path $(SGX_SDK)/include
	@echo "GEN  =>  $@"

App/Enclave_u.c: App/Enclave_u.h

# 编译 Enclave_u.c 生成对象文件
App/Enclave_u.o: App/Enclave_u.c
	@$(CC) $(SGX_COMMON_CFLAGS) $(App_C_Flags) -c $< -o $@
	@echo "CC   <=  $<"

# 编译应用程序源文件生成对象文件
App/%.o: App/%.cpp App/Enclave_u.h
	@$(CXX) $(SGX_COMMON_CXXFLAGS) $(App_Cpp_Flags) -c $< -o $@
	@echo "CXX  <=  $<"

# 链接对象文件生成应用程序可执行文件
$(App_Name): App/Enclave_u.o $(App_Cpp_Objects)
	@$(CXX) $^ -o $@ $(App_Link_Flags)
	@echo "LINK =>  $@"

######## Enclave Objects ########
# 生成 Enclave_t.h，如果 Enclave.edl 改变
Enclave/Enclave_t.h: $(SGX_EDGER8R) Enclave/Enclave.edl
	@cd Enclave && $(SGX_EDGER8R) --trusted ../Enclave/Enclave.edl --search-path ../Enclave --search-path $(SGX_SDK)/include
	@echo "GEN  =>  $@"

Enclave/Enclave_t.c: Enclave/Enclave_t.h

# 编译 Enclave_t.c 生成对象文件
Enclave/Enclave_t.o: Enclave/Enclave_t.c
	@$(CC) $(SGX_COMMON_CFLAGS) $(Enclave_C_Flags) -c $< -o $@
	@echo "CC   <=  $<"

# 编译信任域源文件生成对象文件
Enclave/%.o: Enclave/%.cpp
	@$(CXX) $(SGX_COMMON_CXXFLAGS) $(Enclave_Cpp_Flags) -c $< -o $@
	@echo "CXX  <=  $<"

# 生成信任域对象文件
$(Enclave_Cpp_Objects): Enclave/Enclave_t.h

# 链接对象文件生成信任域共享库文件
$(Enclave_Name): Enclave/Enclave_t.o $(Enclave_Cpp_Objects)
	@$(CXX) $^ -o $@ $(Enclave_Link_Flags)
	@echo "LINK =>  $@"

# 使用测试私钥签名信任域共享库文件
$(Signed_Enclave_Name): $(Enclave_Name)
ifeq ($(wildcard $(Enclave_Key)),)
	@echo "There is no enclave test key<Enclave_private_test.pem>."
	@echo "The project will generate a key<Enclave_private_test.pem> for test."
	@openssl genrsa -out $(Enclave_Key) -3 3072
endif
	@$(SGX_ENCLAVE_SIGNER) sign -key $(Enclave_Key) -enclave $(Enclave_Name) -out $@ -config $(Enclave_Config_File)
	@echo "SIGN =>  $@"


# clean 目标，删除生成的文件
.PHONY: clean

clean:
	@rm -f .config_* $(App_Name) $(Enclave_Name) $(Signed_Enclave_Name) $(App_Cpp_Objects) App/Enclave_u.* $(Enclave_Cpp_Objects) Enclave/Enclave_t.*
