# SPDX-License-Identifier: Apache-2.0
#
# AOSPEXT project (https://github.com/GloDroid/aospext)
#
# Copyright (C) 2021 GlobalLogic Ukraine
# Copyright (C) 2021-2022 Roman Stratiienko (r.stratiienko@gmail.com)

AOSPEXT_PROJECT_NAME := MESA3D

ifneq ($(filter true, $(BOARD_BUILD_AOSPEXT_MESA3D)),)

LOCAL_PATH := $(call my-dir)

LIBDRM_VERSION = $(shell cat external/libdrm/meson.build | grep -o "\<version\>\s*:\s*'\w*\.\w*\.\w*'" | grep -o "\w*\.\w*\.\w*" | head -1)

MESA_VK_LIB_SUFFIX_amd := radeon
MESA_VK_LIB_SUFFIX_intel := intel
MESA_VK_LIB_SUFFIX_intel_hasvk := intel_hasvk
MESA_VK_LIB_SUFFIX_freedreno := freedreno
MESA_VK_LIB_SUFFIX_broadcom := broadcom
MESA_VK_LIB_SUFFIX_panfrost := panfrost
MESA_VK_LIB_SUFFIX_virtio-experimental := virtio
MESA_VK_LIB_SUFFIX_swrast := lvp

MESON_BUILD_ARGUMENTS := \
    -Dplatforms=android                                                          \
    -Dplatform-sdk-version=$(PLATFORM_SDK_VERSION)                               \
    -Ddri-drivers=                                                               \
    -Dgallium-drivers=$(subst $(space),$(comma),$(BOARD_MESA3D_GALLIUM_DRIVERS)) \
    -Dvulkan-drivers=$(subst $(space),$(comma),$(subst radeon,amd,$(BOARD_MESA3D_VULKAN_DRIVERS)))   \
    -Dgbm=enabled                                                                \
    -Degl=enabled                                                                \
    -Dcpp_rtti=false                                                             \
    -Dlmsensors=disabled                                                         \
	-Dgallium-va=$(BOARD_MESA3D_GALLIUM_VA)					    				 \
	-Dvideo-codecs=$(subst $(space),$(comma),$(BOARD_MESA3D_GALLIUM_VA_CODECS))	 \
    $(BOARD_MESA3D_EXTRA_MESON_ARGS)

ifeq ($(shell test $(PLATFORM_SDK_VERSION) -ge 30; echo $$?), 0)
MESA_LIBGBM_NAME := libgbm_mesa
else
MESA_LIBGBM_NAME := libgbm
endif

# Format: TYPE:REL_PATH_TO_INSTALL_ARTIFACT:VENDOR_SUBDIR:MODULE_NAME:SYMLINK_SUFFIX
# TYPE one of: lib, bin, etc
AOSPEXT_GEN_TARGETS := \
    lib:libgallium_dri.so:dri:libgallium_dri:   \
    lib:libglapi.so::libglapi:                  \
    lib:libEGL.so:egl:libEGL_mesa:              \
    lib:libGLESv1_CM.so:egl:libGLESv1_CM_mesa:  \
    lib:libGLESv2.so:egl:libGLESv2_mesa:        \
    $(BOARD_MESA3D_EXTRA_TARGETS)

ifneq ($(filter true, $(BOARD_MESA3D_BUILD_LIBGBM)),)
AOSPEXT_GEN_TARGETS += lib:$(MESA_LIBGBM_NAME).so::$(MESA_LIBGBM_NAME):
endif

ifneq ($(BOARD_MESA3D_GALLIUM_VA),)
AOSPEXT_GEN_TARGETS += lib:libgallium_drv_video.so:dri:libgallium_drv_video:
endif

AOSPEXT_GEN_TARGETS += \
    $(foreach driver,$(BOARD_MESA3D_VULKAN_DRIVERS), lib:libvulkan_$(MESA_VK_LIB_SUFFIX_$(driver)).so:hw:vulkan.$(driver):)

include $(CLEAR_VARS)

LOCAL_SHARED_LIBRARIES := libc libdl libdrm libm liblog libcutils libz libc++ libnativewindow libsync libhardware
LOCAL_STATIC_LIBRARIES := libexpat libarect libelf
LOCAL_HEADER_LIBRARIES := libnativebase_headers hwvulkan_headers libbacktrace_headers
MESON_GEN_PKGCONFIGS := backtrace cutils expat hardware libdrm:$(LIBDRM_VERSION) nativewindow sync zlib:1.2.11 libelf
LOCAL_CFLAGS += $(BOARD_MESA3D_CFLAGS)

ifneq ($(filter swrast,$(BOARD_MESA3D_GALLIUM_DRIVERS) $(BOARD_MESA3D_VULKAN_DRIVERS)),)
ifeq ($(BOARD_MESA3D_FORCE_SOFTPIPE),)
MESON_GEN_LLVM_STUB := true
endif
endif

ifneq ($(filter zink,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_SHARED_LIBRARIES += libvulkan
MESON_GEN_PKGCONFIGS += vulkan
endif

ifneq ($(filter iris,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_SHARED_LIBRARIES += libdrm_intel
MESON_GEN_PKGCONFIGS += libdrm_intel:$(LIBDRM_VERSION)
endif

ifneq ($(filter radeonsi amd,$(BOARD_MESA3D_GALLIUM_DRIVERS) $(BOARD_MESA3D_VULKAN_DRIVERS)),)
MESON_GEN_LLVM_STUB := true
LOCAL_CFLAGS += -DFORCE_BUILD_AMDGPU   # instructs LLVM to declare LLVMInitializeAMDGPU* functions
LOCAL_SHARED_LIBRARIES += libdrm_amdgpu
MESON_GEN_PKGCONFIGS += libdrm_amdgpu:$(LIBDRM_VERSION)
endif

ifneq ($(filter radeonsi r300 r600,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_SHARED_LIBRARIES += libdrm_radeon
MESON_GEN_PKGCONFIGS += libdrm_radeon:$(LIBDRM_VERSION)
endif

ifneq ($(filter nouveau,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_SHARED_LIBRARIES += libdrm_nouveau
MESON_GEN_PKGCONFIGS += libdrm_nouveau:$(LIBDRM_VERSION)
endif

ifneq ($(filter d3d12,$(BOARD_MESA3D_GALLIUM_DRIVERS)),)
LOCAL_HEADER_LIBRARIES += DirectX-Headers
LOCAL_STATIC_LIBRARIES += DirectX-Guids
MESON_GEN_PKGCONFIGS += DirectX-Headers
endif

ifneq ($(MESON_GEN_LLVM_STUB),)
MESON_LLVM_VERSION := 12.0.0
LOCAL_SHARED_LIBRARIES += libLLVM12
endif

ifneq ($(BOARD_MESA3D_GALLIUM_VA),)
LOCAL_SHARED_LIBRARIES += libva libva-android
MESON_GEN_PKGCONFIGS += libva:1.18.0
endif

ifeq ($(shell test $(PLATFORM_SDK_VERSION) -ge 30; echo $$?), 0)
LOCAL_SHARED_LIBRARIES += \
    android.hardware.graphics.mapper@4.0 \
    libgralloctypes \
    libhidlbase \
    libutils

MESON_GEN_PKGCONFIGS += android.hardware.graphics.mapper:4.0
endif

define populate_dri_symlinks
# -------------------------------------------------------------------------------
# Mesa3d installs every dri target as a separate shared library, but for gallium drivers all
# dri targets are identical and can be replaced with symlinks to save some disk space.
# To do that we take first driver, copy it as libgallium_dri.so and populate vendor/lib{64}/dri/
# directory with a symlinks to libgallium_dri.so

$(SYMLINKS_TARGET): MESA3D_LIB_INSTALL_DIR:=$(dir $(MESON_GEN_FILES_TARGET))/install/vendor/lib$(if $(TARGET_IS_64_BIT),$(if $(filter 64 first,$(LOCAL_MULTILIB)),64))
$(SYMLINKS_TARGET): $(MESON_GEN_FILES_TARGET)
	# Create Symlinks
	mkdir -p $$(dir $$@)
	find $$(MESA3D_LIB_INSTALL_DIR)/dri -name \*_dri.so -printf '%f\n' | PATH=/usr/bin:$$PATH xargs -I{} ln -s -f libgallium_dri.so $$(dir $$@)/{}
	cp `find $$(MESA3D_LIB_INSTALL_DIR)/dri -name \*_dri.so | head -1` $$(MESA3D_LIB_INSTALL_DIR)/libgallium_dri.so
	touch $$@
endef

define populate_drv_video_symlinks
# -------------------------------------------------------------------------------
# This function is the same as populate_dri_symlinks, but made for Mesa's VA-API 
# drivers instead of Gallium dri drivers

$(SYMLINKS_TARGET_VIDEO): MESA3D_LIB_INSTALL_DIR:=$(dir $(MESON_GEN_FILES_TARGET))/install/vendor/lib$(if $(TARGET_IS_64_BIT),$(if $(filter 64 first,$(LOCAL_MULTILIB)),64))
$(SYMLINKS_TARGET_VIDEO): $(MESON_GEN_FILES_TARGET)
	# Create Symlinks
	mkdir -p $$(dir $$@)
	find $$(MESA3D_LIB_INSTALL_DIR)/dri -name \*_drv_video.so -printf '%f\n' | PATH=/usr/bin:$$PATH xargs -I{} ln -s -f libgallium_drv_video.so $$(dir $$@)/{}
	cp `find $$(MESA3D_LIB_INSTALL_DIR)/dri -name \*_drv_video.so | head -1` $$(MESA3D_LIB_INSTALL_DIR)/libgallium_drv_video.so
	touch $$@
endef

#-------------------------------------------------------------------------------

LOCAL_MULTILIB := first
include $(LOCAL_PATH)/meson_cross.mk
SYMLINKS_TARGET:=$($(AOSPEXT_ARCH_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES)/dri/.symlinks.timestamp
$(eval $(call populate_dri_symlinks))
SYMLINKS_TARGET_VIDEO:=$($(AOSPEXT_ARCH_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES)/dri/.symlinks.drv_video.timestamp
$(eval $(call populate_drv_video_symlinks))
FIRSTARCH_SYMLINKS_TARGET:=$(SYMLINKS_TARGET) $(SYMLINKS_TARGET_VIDEO)
FIRSTARCH_INSTALL_DIR:=$(dir $(MESON_GEN_FILES_TARGET))/install

ifdef TARGET_2ND_ARCH
LOCAL_MULTILIB := 32
include $(LOCAL_PATH)/meson_cross.mk
SYMLINKS_TARGET:=$($(AOSPEXT_ARCH_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES)/dri/.symlinks.timestamp
$(eval $(call populate_dri_symlinks))
SYMLINKS_TARGET_VIDEO:=$($(AOSPEXT_ARCH_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES)/dri/.symlinks.drv_video.timestamp
$(eval $(call populate_drv_video_symlinks))
SECONDARCH_SYMLINKS_TARGET:=$(SYMLINKS_TARGET) $(SYMLINKS_TARGET_VIDEO)
SECONDARCH_INSTALL_DIR:=$(dir $(MESON_GEN_FILES_TARGET))/install
endif

#-------------------------------------------------------------------------------

LOCAL_MULTILIB := first
AOSPEXT_TARGETS_DEP:=$(FIRSTARCH_SYMLINKS_TARGET)
AOSPEXT_PROJECT_INSTALL_DIR:=$(FIRSTARCH_INSTALL_DIR)
AOSPEXT_PROJECT_OUT_INCLUDE_DIR:=$(AOSPEXT_PROJECT_INSTALL_DIR)/vendor/include $(BOARD_MESA3D_SRC_DIR)/src/gbm/main
include $(LOCAL_PATH)/aospext_gen_targets.mk

ifdef TARGET_2ND_ARCH
LOCAL_MULTILIB := 32
AOSPEXT_TARGETS_DEP:=$(SECONDARCH_SYMLINKS_TARGET)
AOSPEXT_PROJECT_INSTALL_DIR:=$(SECONDARCH_INSTALL_DIR)
AOSPEXT_PROJECT_OUT_INCLUDE_DIR:=$(AOSPEXT_PROJECT_INSTALL_DIR)/vendor/include $(BOARD_MESA3D_SRC_DIR)/src/gbm/main
include $(LOCAL_PATH)/aospext_gen_targets.mk
endif

endif # BOARD_BUILD_AOSPEXT_MESA3D
