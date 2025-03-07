#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017 The LineageOS Project
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

set -e

DEVICE=axon7
VENDOR=zte

# Load extractutils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

AOSP_ROOT="$MY_DIR"/../../..

HELPER="$AOSP_ROOT"/vendor/aosp/build/tools/extract_utils.sh
if [ ! -f "$HELPER" ]; then
    echo "Unable to find helper script at $HELPER"
    exit 1
fi
. "$HELPER"

if [ $# -eq 0 ]; then
  SRC=adb
else
  if [ $# -eq 1 ]; then
    SRC=$1
  else
    echo "$0: bad number of arguments"
    echo ""
    echo "usage: $0 [PATH_TO_EXPANDED_ROM]"
    echo ""
    echo "If PATH_TO_EXPANDED_ROM is not specified, blobs will be extracted from"
    echo "the device using adb pull."
    exit 1
  fi
fi

# Initialize the helper
setup_vendor "$DEVICE" "$VENDOR" "$AOSP_ROOT"

extract "$MY_DIR"/proprietary-files-qc.txt "$SRC"
extract "$MY_DIR"/proprietary-files-qc-perf.txt "$SRC"
extract "$MY_DIR"/proprietary-files.txt "$SRC"

BLOB_ROOT="$AOSP_ROOT"/vendor/"$VENDOR"/"$DEVICE"/proprietary

#
# Load NXP container profiles from vendor
#
LIBTFA9890="$BLOB_ROOT"/vendor/lib/libtfa9890.so
sed -i "s|/etc/settings/stereo_qcom_spk.cnt|/vendor/etc/tfa/stereo_qc_spk.cnt|g" "$LIBTFA9890"
sed -i "s|/etc/settings/mono_qcom_rcv.cnt|/vendor/etc/tfa/mono_qc_rcv.cnt|g" "$LIBTFA9890"
sed -i "s|/etc/settings/mono_qcom_spk_l.cnt|/vendor/etc/tfa/mono_qc_spk_l.cnt|g" "$LIBTFA9890"
sed -i "s|/etc/settings/mono_qcom_spk_r.cnt|/vendor/etc/tfa/mono_qc_spk_r.cnt|g" "$LIBTFA9890"
sed -i "s|/etc/settings/stereo_qcom_spk_l.cnt|/vendor/etc/tfa/stereo_qc_spk_l.cnt|g" "$LIBTFA9890"
sed -i "s|/etc/settings/stereo_qcom_spk_r.cnt|/vendor/etc/tfa/stereo_qc_spk_r.cnt|g" "$LIBTFA9890"

#
# Correct VZW IMS library location
#
QTI_VZW_IMS_INTERNAL="$BLOB_ROOT"/vendor/etc/permissions/qti-vzw-ims-internal.xml
sed -i "s|/system/vendor/framework/qti-vzw-ims-internal.jar|/vendor/framework/qti-vzw-ims-internal.jar|g" "$QTI_VZW_IMS_INTERNAL"

#
# Correct android.hidl.manager@1.0-java jar name
#
QTI_LIBPERMISSIONS="$BLOB_ROOT"/vendor/etc/permissions/qti_libpermissions.xml
sed -i "s|name=\"android.hidl.manager-V1.0-java|name=\"android.hidl.manager@1.0-java|g" "$QTI_LIBPERMISSIONS"

#
# Remove android.hidl.base@1.0 & android.hidl.manager@1.0
#
for HIDL_BASE_LIB in $(grep -lr "android\.hidl\.base@1\.0\.so" $BLOB_ROOT); do
    patchelf --remove-needed android.hidl.base@1.0.so "$HIDL_BASE_LIB" || true
done
 for HIDL_MANAGER_LIB in $(grep -lr "android\.hidl\.@1\.0\.so" $BLOB_ROOT); do
    patchelf --remove-needed android.hidl.manager@1.0.so "$HIDL_MANAGER_LIB" || true
done

patchelf --replace-needed android.hardware.gnss@1.0.so android.hardware.gnss@1.0-v27.so $BLOB_ROOT/vendor/lib64/vendor.qti.gnss@1.0_vendor.so

"$MY_DIR"/setup-makefiles.sh
