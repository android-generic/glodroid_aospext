# SPDX-License-Identifier: Apache-2.0
#
# AOSPEXT project (https://github.com/GloDroid/aospext)
#
# Copyright (C) 2021 GlobalLogic Ukraine
# Copyright (C) 2021-2022 Roman Stratiienko (r.stratiienko@gmail.com)

ifneq ($(filter true, $(BOARD_BUILD_AOSPEXT_MESA3D)),)

LOCAL_PATH := $(call my-dir)
include $(LOCAL_PATH)/aospext_cleanup.mk

AOSPEXT_PROJECT_NAME := MESA3D
AOSPEXT_BUILD_SYSTEM := meson

LIBDRM_VERSION = $(shell cat external/libdrm/meson.build | grep -o "\<version\>\s*:\s*'\w*\.\w*\.\w*'" | grep -o "\w*\.\w*\.\w*" | head -1)
MESA3D_VERSION = $(shell cat $(BOARD_MESA3D_SRC_DIR)/VERSION | cut -d '.' -f 1-2)
LLVM_VERSION_MAJOR = $(shell \
    if [ -f external/llvm-project/cmake/Modules/LLVMVersion.cmake ]; then \
        grep 'set.LLVM_VERSION_MAJOR ' external/llvm-project/cmake/Modules/LLVMVersion.cmake | grep -o '[0-9]\+'; \
    else \
        grep 'set.LLVM_VERSION_MAJOR ' external/llvm-project/llvm/CMakeLists.txt | grep -o '[0-9]\+'; \
    fi)
LLVM_VERSION_MINOR = $(shell \
    if [ -f external/llvm-project/cmake/Modules/LLVMVersion.cmake ]; then \
        grep 'set.LLVM_VERSION_MINOR ' external/llvm-project/cmake/Modules/LLVMVersion.cmake | grep -o '[0-9]\+'; \
    else \
        grep 'set.LLVM_VERSION_MINOR ' external/llvm-project/llvm/CMakeLists.txt | grep -o '[0-9]\+'; \
    fi)
LLVM_VERSION_PATCH = $(shell \
    if [ -f external/llvm-project/cmake/Modules/LLVMVersion.cmake ]; then \
        grep 'set.LLVM_VERSION_PATCH ' external/llvm-project/cmake/Modules/LLVMVersion.cmake | grep -o '[0-9]\+'; \
    else \
        grep 'set.LLVM_VERSION_PATCH ' external/llvm-project/llvm/CMakeLists.txt | grep -o '[0-9]\+'; \
    fi)

MESA3D_GALLIUM_LIBDIR :=
MESA3D_POPULATE_DRI_SYMLINKS :=
MESA3D_POPULATE_GVA_SYMLINKS :=

ifeq ($(shell expr $(MESA3D_VERSION) \<= 24.1), 1)
MESA3D_GALLIUM_LIBDIR := dri
MESA3D_POPULATE_DRI_SYMLINKS := true
endif

ifeq ($(BOARD_MESA3D_GALLIUM_VA),enabled)
MESA3D_POPULATE_GVA_SYMLINKS := true
endif

MESA_VK_LIB_SUFFIX_amd := radeon
MESA_VK_LIB_SUFFIX_intel := intel
MESA_VK_LIB_SUFFIX_intel_hasvk := intel_hasvk
MESA_VK_LIB_SUFFIX_nouveau := nouveau
MESA_VK_LIB_SUFFIX_freedreno := freedreno
MESA_VK_LIB_SUFFIX_broadcom := broadcom
MESA_VK_LIB_SUFFIX_panfrost := panfrost
MESA_VK_LIB_SUFFIX_virtio := virtio
MESA_VK_LIB_SUFFIX_swrast := lvp

MESON_BUILD_ARGUMENTS := \
    -Dplatforms=android                                                          \
    -Dplatform-sdk-version=$(PLATFORM_SDK_VERSION)                               \
    -Dgallium-drivers=$(subst $(space),$(comma),$(BOARD_MESA3D_GALLIUM_DRIVERS)) \
    -Dvulkan-drivers=$(subst $(space),$(comma),$(subst radeon,amd,$(BOARD_MESA3D_VULKAN_DRIVERS)))   \
    -Dgbm=enabled                                                                \
    -Degl=$(if $(BOARD_MESA3D_GALLIUM_DRIVERS),enabled,disabled)                 \
    -Dllvm=$(if $(MESON_GEN_LLVM_STUB),enabled,disabled)                         \
    -Dcpp_rtti=false                                                             \
    -Dlmsensors=disabled                                                         \
    -Dandroid-libbacktrace=disabled                                              \
	-Dgallium-va=$(BOARD_MESA3D_GALLIUM_VA)					    				 \
	-Dvideo-codecs=$(subst $(space),$(comma),$(BOARD_MESA3D_VIDEO_CODECS))	 \
	-Dxmlconfig=enabled															 \
    $(BOARD_MESA3D_EXTRA_MESON_ARGS)                                             \
    $(BOARD_MESA3D_MESON_ARGS)

ifeq ($(shell test $(PLATFORM_SDK_VERSION) -ge 30; echo $$?), 0)
MESA_LIBGBM_NAME := libgbm_mesa
else
MESA_LIBGBM_NAME := libgbm
endif

# Format: TYPE:REL_PATH_TO_INSTALL_ARTIFACT:VENDOR_SUBDIR:MODULE_NAME:SYMLINK_SUFFIX
# TYPE one of: lib, bin, etc
AOSPEXT_GEN_TARGETS := $(BOARD_MESA3D_EXTRA_TARGETS)

ifneq ($(strip $(BOARD_MESA3D_GALLIUM_DRIVERS)),)
AOSPEXT_GEN_TARGETS += \
    lib:libgallium_dri.so:$(MESA3D_GALLIUM_LIBDIR):libgallium_dri:   \
    lib:libEGL.so:egl:libEGL_mesa:              \
    lib:libGLESv1_CM.so:egl:libGLESv1_CM_mesa:  \
    lib:libGLESv2.so:egl:libGLESv2_mesa:        \

endif

ifeq ($(shell expr $(MESA3D_VERSION) \< 25.0), 1)
AOSPEXT_GEN_TARGETS += lib:libglapi.so::libglapi:
endif

ifneq ($(filter true, $(BOARD_MESA3D_BUILD_LIBGBM)),)
AOSPEXT_GEN_TARGETS += lib:$(MESA_LIBGBM_NAME).so::$(MESA_LIBGBM_NAME):
AOSPEXT_GEN_TARGETS += lib:gbm/dri_gbm.so::dri_gbm:
endif

ifneq ($(BOARD_MESA3D_GALLIUM_VA),)
ifeq ($(shell expr $(MESA3D_VERSION) \<= 24.2), 1)
AOSPEXT_GEN_TARGETS += lib:libgallium_drv_video.so:$(MESA3D_GALLIUM_LIBDIR):libgallium_drv_video:
endif
endif

AOSPEXT_GEN_TARGETS += \
    $(foreach driver,$(BOARD_MESA3D_VULKAN_DRIVERS), lib:libvulkan_$(MESA_VK_LIB_SUFFIX_$(driver)).so:hw:vulkan.$(MESA_VK_LIB_SUFFIX_$(driver)):)

include $(CLEAR_VARS)

LOCAL_SHARED_LIBRARIES := libc libdl libdrm libm liblog libcutils libz libc++ libnativewindow libsync libhardware libxml2
LOCAL_STATIC_LIBRARIES := libexpat libarect libelf libzstd
LOCAL_HEADER_LIBRARIES := libnativebase_headers hwvulkan_headers
AOSPEXT_GEN_PKGCONFIGS := log cutils expat hardware libdrm:$(LIBDRM_VERSION) nativewindow sync zlib:1.2.11 libelf libxml2 libzstd
LOCAL_CFLAGS += $(BOARD_MESA3D_CFLAGS)

ifneq ($(filter swrast,$(BOARD_MESA3D_GALLIUM_DRIVERS) $(BOARD_MESA3D_VULKAN_DRIVERS)),)
ifeq ($(BOARD_MESA3D_FORCE_SOFTPIPE),)
MESON_GEN_LLVM_STUB := true
endif
endif

ifneq ($(filter zink,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_SHARED_LIBRARIES += libvulkan
AOSPEXT_GEN_PKGCONFIGS += vulkan
endif

ifneq ($(filter iris,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_SHARED_LIBRARIES += libdrm_intel
AOSPEXT_GEN_PKGCONFIGS += libdrm_intel:$(LIBDRM_VERSION)
endif

ifneq ($(filter radeonsi,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
MESON_GEN_LLVM_STUB := true
LOCAL_CFLAGS += -DFORCE_BUILD_AMDGPU   # instructs LLVM to declare LLVMInitializeAMDGPU* functions
endif

ifneq ($(filter radeonsi amd,$(BOARD_MESA3D_GALLIUM_DRIVERS) $(BOARD_MESA3D_VULKAN_DRIVERS)),)
LOCAL_SHARED_LIBRARIES += libdrm_amdgpu
AOSPEXT_GEN_PKGCONFIGS += libdrm_amdgpu:$(LIBDRM_VERSION)
endif

ifneq ($(filter radeonsi r300 r600,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_SHARED_LIBRARIES += libdrm_radeon
AOSPEXT_GEN_PKGCONFIGS += libdrm_radeon:$(LIBDRM_VERSION)
endif

ifneq ($(filter nouveau,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_SHARED_LIBRARIES += libdrm_nouveau
AOSPEXT_GEN_PKGCONFIGS += libdrm_nouveau:$(LIBDRM_VERSION)
endif

ifneq ($(filter d3d12,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_HEADER_LIBRARIES += DirectX-Headers
LOCAL_STATIC_LIBRARIES += DirectX-Guids
AOSPEXT_GEN_PKGCONFIGS += DirectX-Headers
endif

ifneq ($(MESON_GEN_LLVM_STUB),)
MESON_LLVM_VERSION := $(LLVM_VERSION_MAJOR).$(LLVM_VERSION_MINOR).$(LLVM_VERSION_PATCH)
LOCAL_SHARED_LIBRARIES += libLLVM$(LLVM_VERSION_MAJOR)
endif

ifneq ($(BOARD_MESA3D_GALLIUM_VA),)
LOCAL_SHARED_LIBRARIES += libva libva-android
LOCAL_HEADER_LIBRARIES += libva_headers
AOSPEXT_GEN_PKGCONFIGS += libva:1.22.0
endif

ifeq ($(shell test $(PLATFORM_SDK_VERSION) -ge 30; echo $$?), 0)
LOCAL_SHARED_LIBRARIES += libgralloctypes libutils

ifeq ($(shell test $(PLATFORM_SDK_VERSION) -ge 35; echo $$?), 0)
LOCAL_SHARED_LIBRARIES += libui
AOSPEXT_GEN_PKGCONFIGS += ui
else
LOCAL_SHARED_LIBRARIES += libhidlbase android.hardware.graphics.mapper@4.0
AOSPEXT_GEN_PKGCONFIGS += android.hardware.graphics.mapper:4.0
endif

endif

LOCAL_EXPORT_C_INCLUDE_DIRS := $(BOARD_MESA3D_SRC_DIR)/src/gbm/main
AOSPEXT_EXPORT_INSTALLED_INCLUDE_DIRS := vendor/include

ifneq ($(MESA3D_POPULATE_DRI_SYMLINKS),)
define populate_dri_symlinks
# -------------------------------------------------------------------------------
# Mesa3d installs every dri target as a separate shared library, but for gallium drivers all
# dri targets are identical and can be replaced with symlinks to save some disk space.
# To do that we take first driver, copy it as libgallium_dri.so and populate vendor/lib{64}/dri/
# directory with a symlinks to libgallium_dri.so

$(SYMLINKS_TARGET): MESA3D_LIB_INSTALL_DIR:=$(dir $(AOSPEXT_INTERNAL_BUILD_TARGET))/install/vendor/lib$(if $(TARGET_IS_64_BIT),$(if $(filter 64 first,$(LOCAL_MULTILIB)),64))
$(SYMLINKS_TARGET): $(AOSPEXT_INTERNAL_BUILD_TARGET)
	# Create Symlinks
	mkdir -p $$(dir $$@)
ifneq ($(strip $(BOARD_MESA3D_GALLIUM_DRIVERS)),)
	find $$(MESA3D_LIB_INSTALL_DIR)/dri -name \*_dri.so -printf '%f\n' | PATH=/usr/bin:$$PATH xargs -I{} ln -s -f libgallium_dri.so $$(dir $$@)/{}
	cp `find $$(MESA3D_LIB_INSTALL_DIR)/dri -name \*_dri.so | head -1` $$(MESA3D_LIB_INSTALL_DIR)/libgallium_dri.so
endif
	touch $$@
endef
endif # MESA3D_POPULATE_DRI_SYMLINKS

ifneq ($(MESA3D_POPULATE_GVA_SYMLINKS),)
define populate_drv_video_symlinks
# -------------------------------------------------------------------------------
# This function is the same as populate_dri_symlinks, but made for Mesa's VA-API 
# drivers instead of Gallium dri drivers

$(SYMLINKS_TARGET_VIDEO): MESA3D_LIB_INSTALL_DIR:=$(dir $(AOSPEXT_INTERNAL_BUILD_TARGET))/install/vendor/lib$(if $(TARGET_IS_64_BIT),$(if $(filter 64 first,$(LOCAL_MULTILIB)),64))
$(SYMLINKS_TARGET_VIDEO): $(AOSPEXT_INTERNAL_BUILD_TARGET)
	# Create Symlinks
	mkdir -p $$(dir $$@)
ifneq ($(strip $(BOARD_MESA3D_GALLIUM_VA)),)
	find $$(MESA3D_LIB_INSTALL_DIR)/dri -name \*_drv_video.so -printf '%f\n' | PATH=/usr/bin:$$PATH xargs -I{} ln -s -f $$(if $(shell expr $(MESA3D_VERSION) \>= 24.3),libgallium_dri, libgallium_drv_video).so $$(dir $$@)/{}
ifeq ($(shell expr $(MESA3D_VERSION) \<= 24.2), 1)
	cp `find $$(MESA3D_LIB_INSTALL_DIR)/dri -name \*_drv_video.so | head -1` $$(MESA3D_LIB_INSTALL_DIR)/libgallium_drv_video.so
endif
endif
	touch $$@
endef
endif # MESA3D_POPULATE_GVA_SYMLINKS

#-------------------------------------------------------------------------------

LOCAL_MULTILIB := first
include $(LOCAL_PATH)/aospext_cross_compile.mk
FIRSTARCH_SYMLINKS_TARGET :=
ifneq ($(MESA3D_POPULATE_DRI_SYMLINKS),)
SYMLINKS_TARGET := $($(AOSPEXT_ARCH_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES)/$(MESA3D_GALLIUM_LIBDIR)/.symlinks.timestamp
$(eval $(call populate_dri_symlinks))
FIRSTARCH_SYMLINKS_TARGET += $(SYMLINKS_TARGET)
endif # MESA3D_POPULATE_DRI_SYMLINKS
ifneq ($(MESA3D_POPULATE_GVA_SYMLINKS),)
SYMLINKS_TARGET_VIDEO := $($(AOSPEXT_ARCH_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES)/$(MESA3D_GALLIUM_LIBDIR)/.symlinks.drv_video.timestamp
$(eval $(call populate_drv_video_symlinks))
FIRSTARCH_SYMLINKS_TARGET += $(SYMLINKS_TARGET_VIDEO)
endif # MESA3D_POPULATE_GVA_SYMLINKS
FIRSTARCH_BUILD_TARGET := $(AOSPEXT_INTERNAL_BUILD_TARGET)

ifdef TARGET_2ND_ARCH
LOCAL_MULTILIB := 32
include $(LOCAL_PATH)/aospext_cross_compile.mk
SECONDARCH_SYMLINKS_TARGET :=
ifneq ($(MESA3D_POPULATE_DRI_SYMLINKS),)
SYMLINKS_TARGET := $($(AOSPEXT_ARCH_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES)/$(MESA3D_GALLIUM_LIBDIR)/.symlinks.timestamp
$(eval $(call populate_dri_symlinks))
SECONDARCH_SYMLINKS_TARGET += $(SYMLINKS_TARGET)
endif # MESA3D_POPULATE_DRI_SYMLINKS
ifneq ($(MESA3D_POPULATE_GVA_SYMLINKS),)
SYMLINKS_TARGET_VIDEO := $($(AOSPEXT_ARCH_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES)/$(MESA3D_GALLIUM_LIBDIR)/.symlinks.drv_video.timestamp
$(eval $(call populate_drv_video_symlinks))
SECONDARCH_SYMLINKS_TARGET += $(SYMLINKS_TARGET_VIDEO)
endif # MESA3D_POPULATE_GVA_SYMLINKS
SECONDARCH_BUILD_TARGET := $(AOSPEXT_INTERNAL_BUILD_TARGET)
endif

#-------------------------------------------------------------------------------

LOCAL_MULTILIB := first
AOSPEXT_EXTRA_DEPS := $(FIRSTARCH_SYMLINKS_TARGET)
AOSPEXT_INTERNAL_BUILD_TARGET := $(FIRSTARCH_BUILD_TARGET)
include $(LOCAL_PATH)/aospext_gen_targets.mk

ifdef TARGET_2ND_ARCH
LOCAL_MULTILIB := 32
AOSPEXT_EXTRA_DEPS := $(SECONDARCH_SYMLINKS_TARGET)
AOSPEXT_INTERNAL_BUILD_TARGET := $(SECONDARCH_BUILD_TARGET)
include $(LOCAL_PATH)/aospext_gen_targets.mk
endif

endif # BOARD_BUILD_AOSPEXT_MESA3D
