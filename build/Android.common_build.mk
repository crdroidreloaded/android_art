#
# Copyright (C) 2011 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

ifndef ART_ANDROID_COMMON_BUILD_MK
ART_ANDROID_COMMON_BUILD_MK = true

include art/build/Android.common.mk
include art/build/Android.common_utils.mk

# These can be overridden via the environment or by editing to
# enable/disable certain build configuration.
#
# For example, to disable everything but the host debug build you use:
#
# (export ART_BUILD_TARGET_NDEBUG=false && export ART_BUILD_TARGET_DEBUG=false && export ART_BUILD_HOST_NDEBUG=false && ...)
#
# Beware that tests may use the non-debug build for performance, notable 055-enum-performance
#
ART_BUILD_TARGET_NDEBUG ?= true
ART_BUILD_TARGET_DEBUG ?= false
ART_BUILD_HOST_NDEBUG ?= true
ART_BUILD_HOST_DEBUG ?= false

ifneq ($(USE_DEX2OAT_DEBUG),false)
ART_BUILD_TARGET_DEBUG ?= true
ART_BUILD_HOST_DEBUG ?= true
endif

# Set this to change what opt level Art is built at.
ART_DEBUG_OPT_FLAG := -O3
ART_NDEBUG_OPT_FLAG := -O3

# Enable the static builds only for checkbuilds.
ifneq (,$(filter checkbuild,$(MAKECMDGOALS)))
  ART_BUILD_HOST_STATIC ?= true
else
  ART_BUILD_HOST_STATIC ?= false
endif

# Asan does not support static linkage
ifdef SANITIZE_HOST
  ART_BUILD_HOST_STATIC := false
endif

ifneq ($(HOST_OS),linux)
  ART_BUILD_HOST_STATIC := false
endif

ifeq ($(ART_BUILD_TARGET_NDEBUG),false)
$(info Disabling ART_BUILD_TARGET_NDEBUG)
endif
ifeq ($(ART_BUILD_TARGET_DEBUG),false)
$(info Disabling ART_BUILD_TARGET_DEBUG)
endif
ifeq ($(ART_BUILD_HOST_NDEBUG),false)
$(info Disabling ART_BUILD_HOST_NDEBUG)
endif
ifeq ($(ART_BUILD_HOST_DEBUG),false)
$(info Disabling ART_BUILD_HOST_DEBUG)
endif
ifeq ($(ART_BUILD_HOST_STATIC),true)
$(info Enabling ART_BUILD_HOST_STATIC)
endif

#
# Used to change the default GC. Valid values are CMS, SS, GSS. The default is CMS.
#
ART_DEFAULT_GC_TYPE ?= CMS
art_default_gc_type_cflags := -DART_DEFAULT_GC_TYPE_IS_$(ART_DEFAULT_GC_TYPE)

ART_HOST_CFLAGS :=
ART_TARGET_CFLAGS :=

ART_HOST_ASFLAGS :=
ART_TARGET_ASFLAGS :=

# Clang build support.

# Host.
ART_HOST_CLANG := false
ifneq ($(WITHOUT_HOST_CLANG),true)
  # By default, host builds use clang for better warnings.
  ART_HOST_CLANG := true
endif

# Clang on the target. Target builds use GCC by default.
ifneq ($(USE_CLANG_PLATFORM_BUILD),)
ART_TARGET_CLANG := $(USE_CLANG_PLATFORM_BUILD)
else
ART_TARGET_CLANG := false
endif
ART_TARGET_CLANG_arm :=
ART_TARGET_CLANG_arm64 :=
ART_TARGET_CLANG_mips :=
ART_TARGET_CLANG_mips64 :=
ART_TARGET_CLANG_x86 :=
ART_TARGET_CLANG_x86_64 :=

define set-target-local-clang-vars
    LOCAL_CLANG := $(ART_TARGET_CLANG)
    $(foreach arch,$(ART_TARGET_SUPPORTED_ARCH),
      ifneq ($$(ART_TARGET_CLANG_$(arch)),)
        LOCAL_CLANG_$(arch) := $$(ART_TARGET_CLANG_$(arch))
      endif)
endef

ART_TARGET_CLANG_CFLAGS :=
ART_TARGET_CLANG_CFLAGS_arm :=
ART_TARGET_CLANG_CFLAGS_arm64 :=
ART_TARGET_CLANG_CFLAGS_mips :=
ART_TARGET_CLANG_CFLAGS_mips64 :=
ART_TARGET_CLANG_CFLAGS_x86 :=
ART_TARGET_CLANG_CFLAGS_x86_64 :=

ART_TARGET_CLANG_CFLAGS := $(art_clang_cflags)
ifeq ($(ART_HOST_CLANG),true)
  # Bug: 15446488. We don't omit the frame pointer to work around
  # clang/libunwind bugs that cause SEGVs in run-test-004-ThreadStress.
  ART_HOST_CFLAGS += $(art_clang_cflags) -fno-omit-frame-pointer
else
  ART_HOST_CFLAGS += $(art_gcc_cflags)
endif
ifneq ($(ART_TARGET_CLANG),true)
  ART_TARGET_CFLAGS += $(art_gcc_cflags)
else
  # TODO: if we ever want to support GCC/Clang mix for multi-target products, this needs to be
  #       split up.
  ifeq ($(ART_TARGET_CLANG_$(TARGET_ARCH)),false)
    ART_TARGET_CFLAGS += $(art_gcc_cflags)
  endif
endif

# Clear local variables now their use has ended.
art_clang_cflags :=
art_gcc_cflags :=

ART_CPP_EXTENSION := .cc

ART_C_INCLUDES := \
  external/gtest/include \
  external/icu/icu4c/source/common \
  external/lz4/lib \
  external/valgrind/include \
  external/valgrind \
  external/vixl/src \
  external/zlib \

# We optimize Thread::Current() with a direct TLS access. This requires access to a private
# Bionic header.
# Note: technically we only need this on device, but this avoids the duplication of the includes.
ART_C_INCLUDES += bionic/libc/private

# Base set of cflags used by all things ART.
art_cflags := \
  -fno-rtti \
  -g0 \
  -fstrict-aliasing \
  -fvisibility=protected \
  $(art_default_gc_type_cflags)

# The architectures the compiled tools are able to run on. Setting this to 'all' will cause all
# architectures to be included.
ART_TARGET_CODEGEN_ARCHS ?= all
ART_HOST_CODEGEN_ARCHS ?= all

ifeq ($(ART_TARGET_CODEGEN_ARCHS),all)
  ART_TARGET_CODEGEN_ARCHS := $(sort $(ART_TARGET_SUPPORTED_ARCH) $(ART_HOST_SUPPORTED_ARCH))
  ART_TARGET_COMPILER_TESTS := false
else
  ART_TARGET_COMPILER_TESTS := false
  ifeq ($(ART_TARGET_CODEGEN_ARCHS),svelte)
    ART_TARGET_CODEGEN_ARCHS := $(sort $(ART_TARGET_ARCH_64) $(ART_TARGET_ARCH_32))
  endif
endif
ifeq ($(ART_HOST_CODEGEN_ARCHS),all)
  ART_HOST_CODEGEN_ARCHS := $(sort $(ART_TARGET_SUPPORTED_ARCH) $(ART_HOST_SUPPORTED_ARCH))
  ART_HOST_COMPILER_TESTS := false
else
  ART_HOST_COMPILER_TESTS := false
  ifeq ($(ART_HOST_CODEGEN_ARCHS),svelte)
    ART_HOST_CODEGEN_ARCHS := $(sort $(ART_TARGET_CODEGEN_ARCHS) $(ART_HOST_ARCH_64) $(ART_HOST_ARCH_32))
  endif
endif

ifneq (,$(filter arm64,$(ART_TARGET_CODEGEN_ARCHS)))
  ART_TARGET_CODEGEN_ARCHS += arm
endif
ifneq (,$(filter mips64,$(ART_TARGET_CODEGEN_ARCHS)))
  ART_TARGET_CODEGEN_ARCHS += mips
endif
ifneq (,$(filter x86_64,$(ART_TARGET_CODEGEN_ARCHS)))
  ART_TARGET_CODEGEN_ARCHS += x86
endif
ART_TARGET_CODEGEN_ARCHS := $(sort $(ART_TARGET_CODEGEN_ARCHS))
ifneq (,$(filter arm64,$(ART_HOST_CODEGEN_ARCHS)))
  ART_HOST_CODEGEN_ARCHS += arm
endif
ifneq (,$(filter mips64,$(ART_HOST_CODEGEN_ARCHS)))
  ART_HOST_CODEGEN_ARCHS += mips
endif
ifneq (,$(filter x86_64,$(ART_HOST_CODEGEN_ARCHS)))
  ART_HOST_CODEGEN_ARCHS += x86
endif
ART_HOST_CODEGEN_ARCHS := $(sort $(ART_HOST_CODEGEN_ARCHS))

# Base set of cflags used by target build only
art_target_cflags := \
  $(foreach target_arch,$(strip $(ART_TARGET_CODEGEN_ARCHS)), -DART_ENABLE_CODEGEN_$(target_arch))
# Base set of cflags used by host build only
art_host_cflags := \
  $(foreach host_arch,$(strip $(ART_HOST_CODEGEN_ARCHS)), -DART_ENABLE_CODEGEN_$(host_arch))

# Base set of asflags used by all things ART.
art_asflags :=

ifdef ART_IMT_SIZE
  art_cflags += -DIMT_SIZE=$(ART_IMT_SIZE)
else
  # Default is 64
  art_cflags += -DIMT_SIZE=64
endif

ifeq ($(ART_HEAP_POISONING),true)
  art_cflags += -DART_HEAP_POISONING=1
  art_asflags += -DART_HEAP_POISONING=1
endif

#
# Used to change the read barrier type. Valid values are BAKER, BROOKS, TABLELOOKUP.
# The default is BAKER.
#
ART_READ_BARRIER_TYPE ?= BAKER

ifeq ($(ART_USE_READ_BARRIER),true)
  art_cflags += -DART_USE_READ_BARRIER=1
  art_cflags += -DART_READ_BARRIER_TYPE_IS_$(ART_READ_BARRIER_TYPE)=1
  art_asflags += -DART_USE_READ_BARRIER=1
  art_asflags += -DART_READ_BARRIER_TYPE_IS_$(ART_READ_BARRIER_TYPE)=1

  # Temporarily override -fstack-protector-strong with -fstack-protector to avoid a major
  # slowdown with the read barrier config. b/26744236.
  art_cflags += -fstack-protector
endif

ifeq ($(ART_USE_TLAB),true)
  art_cflags += -DART_USE_TLAB=1
endif

# Cflags for non-debug ART and ART tools.
art_non_debug_cflags := \
  $(ART_NDEBUG_OPT_FLAG)

# Cflags for debug ART and ART tools.
art_debug_cflags := \
  $(ART_DEBUG_OPT_FLAG) \
  -DDYNAMIC_ANNOTATIONS_ENABLED=1 \
  -UNDEBUG

art_host_non_debug_cflags := $(art_non_debug_cflags)
art_target_non_debug_cflags := $(art_non_debug_cflags)

ifeq ($(HOST_OS),linux)
  # Larger frame-size for host clang builds today
  ifneq ($(ART_COVERAGE),true)
    ifneq ($(NATIVE_COVERAGE),true)
      art_host_non_debug_cflags += -Wframe-larger-than=2700
      ifdef SANITIZE_TARGET
        art_target_non_debug_cflags += -Wframe-larger-than=6400
      else
        art_target_non_debug_cflags += -Wframe-larger-than=1728
      endif
    endif
  endif
endif

ifndef LIBART_IMG_HOST_BASE_ADDRESS
  $(error LIBART_IMG_HOST_BASE_ADDRESS unset)
endif
ART_HOST_CFLAGS += $(art_cflags) -DART_BASE_ADDRESS=$(LIBART_IMG_HOST_BASE_ADDRESS)
ART_HOST_CFLAGS += -DART_DEFAULT_INSTRUCTION_SET_FEATURES=default $(art_host_cflags)
ART_HOST_ASFLAGS += $(art_asflags)

ifndef LIBART_IMG_TARGET_BASE_ADDRESS
  $(error LIBART_IMG_TARGET_BASE_ADDRESS unset)
endif
ART_TARGET_CFLAGS += $(art_cflags) -DART_TARGET -DART_BASE_ADDRESS=$(LIBART_IMG_TARGET_BASE_ADDRESS)
ART_TARGET_CFLAGS += $(art_target_cflags)
ART_TARGET_ASFLAGS += $(art_asflags)

ART_HOST_NON_DEBUG_CFLAGS := $(art_host_non_debug_cflags)
ART_TARGET_NON_DEBUG_CFLAGS := $(art_target_non_debug_cflags)
ART_HOST_DEBUG_CFLAGS := $(art_host_non_debug_cflags)
ART_TARGET_DEBUG_CFLAGS := $(art_target_non_debug_cflags)

ifndef LIBART_IMG_HOST_MIN_BASE_ADDRESS_DELTA
  LIBART_IMG_HOST_MIN_BASE_ADDRESS_DELTA=-0x1000000
endif
ifndef LIBART_IMG_HOST_MAX_BASE_ADDRESS_DELTA
  LIBART_IMG_HOST_MAX_BASE_ADDRESS_DELTA=0x1000000
endif
ART_HOST_CFLAGS += -DART_BASE_ADDRESS_MIN_DELTA=$(LIBART_IMG_HOST_MIN_BASE_ADDRESS_DELTA)
ART_HOST_CFLAGS += -DART_BASE_ADDRESS_MAX_DELTA=$(LIBART_IMG_HOST_MAX_BASE_ADDRESS_DELTA)

ifndef LIBART_IMG_TARGET_MIN_BASE_ADDRESS_DELTA
  LIBART_IMG_TARGET_MIN_BASE_ADDRESS_DELTA=-0x1000000
endif
ifndef LIBART_IMG_TARGET_MAX_BASE_ADDRESS_DELTA
  LIBART_IMG_TARGET_MAX_BASE_ADDRESS_DELTA=0x1000000
endif
ART_TARGET_CFLAGS += -DART_BASE_ADDRESS_MIN_DELTA=$(LIBART_IMG_TARGET_MIN_BASE_ADDRESS_DELTA)
ART_TARGET_CFLAGS += -DART_BASE_ADDRESS_MAX_DELTA=$(LIBART_IMG_TARGET_MAX_BASE_ADDRESS_DELTA)

# To use oprofile_android --callgraph, uncomment this and recompile with "mmm art -B -j16"
# ART_TARGET_CFLAGS += -fno-omit-frame-pointer -marm -mapcs

# Clear locals now they've served their purpose.
art_cflags :=
art_asflags :=
art_host_cflags :=
art_target_cflags :=
art_debug_cflags :=
art_non_debug_cflags :=
art_host_non_debug_cflags :=
art_target_non_debug_cflags :=
art_default_gc_type_cflags :=

ART_HOST_LDLIBS :=
ifneq ($(ART_HOST_CLANG),true)
  # GCC lacks libc++ assumed atomic operations, grab via libatomic.
  ART_HOST_LDLIBS += -latomic
endif

ART_TARGET_LDFLAGS :=

# $(1): ndebug_or_debug
define set-target-local-cflags-vars
  LOCAL_CFLAGS += $(ART_TARGET_CFLAGS)
  LOCAL_CFLAGS_x86 += $(ART_TARGET_CFLAGS_x86)
  LOCAL_ASFLAGS += $(ART_TARGET_ASFLAGS)
  LOCAL_LDFLAGS += $(ART_TARGET_LDFLAGS)
  art_target_cflags_ndebug_or_debug := $(1)
  ifeq ($$(art_target_cflags_ndebug_or_debug),debug)
    LOCAL_CFLAGS += $(ART_TARGET_DEBUG_CFLAGS)
  else
    LOCAL_CFLAGS += $(ART_TARGET_NON_DEBUG_CFLAGS)
  endif

  LOCAL_CLANG_CFLAGS := $(ART_TARGET_CLANG_CFLAGS)
  $(foreach arch,$(ART_TARGET_SUPPORTED_ARCH),
    LOCAL_CLANG_CFLAGS_$(arch) += $$(ART_TARGET_CLANG_CFLAGS_$(arch)))

  # Clear locally used variables.
  art_target_cflags_ndebug_or_debug :=
endef

# Support for disabling certain builds.
ART_BUILD_TARGET := true
ART_BUILD_HOST := true
ART_BUILD_NDEBUG := true
ART_BUILD_DEBUG := false

endif # ART_ANDROID_COMMON_BUILD_MK
