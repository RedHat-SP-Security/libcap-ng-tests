#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/libcap-ng/Sanity/netcap-advanced
#   Description: Verify netcap --advanced produces accurate
#                situational awareness for admins
#   Author: Adam Prikryl <aprikryl@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2026 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="libcap-ng"
SSHD_STARTED_BY_TEST=false
ADVANCED_AVAILABLE=false

rlJournalStart

    rlPhaseStartSetup
        rlAssertRpm "$PACKAGE"
        rlAssertRpm "${PACKAGE}-utils"
        rlRun "which netcap" 0 "netcap binary must be in PATH"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        if ! systemctl is-active sshd &>/dev/null; then
            rlRun "systemctl start sshd" 0 "Starting sshd for test"
            SSHD_STARTED_BY_TEST=true
        fi
        if netcap --advanced &>/dev/null; then
            ADVANCED_AVAILABLE=true
            rlLog "netcap --advanced is available"
        else
            rlLog "netcap --advanced is NOT available (disabled at configure time?)"
        fi
    rlPhaseEnd

    rlPhaseStartTest "NetcapBasicStillWorks"
        rlRun "netcap > ${TmpDir}/netcap-basic.out 2>&1" 0 \
            "Basic netcap must still work"
        rlRun "cat ${TmpDir}/netcap-basic.out"
        rlRun "test -s ${TmpDir}/netcap-basic.out" 0 "Basic output must be non-empty"
    rlPhaseEnd

    rlPhaseStartTest "NetcapAdvancedRun"
        if ! $ADVANCED_AVAILABLE; then
            rlFail "netcap --advanced was disabled at configure time — required kernel headers were missing from the build"
        else
            rlRun "netcap --advanced > ${TmpDir}/netcap-advanced.out 2>&1" 0 \
                "netcap --advanced must run successfully"
            rlRun "cat ${TmpDir}/netcap-advanced.out"
            rlRun "test -s ${TmpDir}/netcap-advanced.out" 0 "Advanced output must be non-empty"
        fi
    rlPhaseEnd

    rlPhaseStartTest "NetcapAdvancedExtraOutput"
        if ! $ADVANCED_AVAILABLE; then
            rlLog "Skipping — netcap --advanced not available"
        else
            BASIC_COLS=$(head -1 "${TmpDir}/netcap-basic.out" | awk '{print NF}')
            ADVANCED_COLS=$(head -1 "${TmpDir}/netcap-advanced.out" | awk '{print NF}')
            rlLog "Basic mode columns: ${BASIC_COLS}, Advanced mode columns: ${ADVANCED_COLS}"
            if [ "$ADVANCED_COLS" -gt "$BASIC_COLS" ]; then
                rlPass "Advanced mode produces more columns (${ADVANCED_COLS}) than basic (${BASIC_COLS})"
            else
                BASIC_SIZE=$(wc -c < "${TmpDir}/netcap-basic.out")
                ADVANCED_SIZE=$(wc -c < "${TmpDir}/netcap-advanced.out")
                rlLog "Basic output size: ${BASIC_SIZE} bytes, Advanced: ${ADVANCED_SIZE} bytes"
                rlRun "[ $ADVANCED_SIZE -ge $BASIC_SIZE ]" 0 \
                    "Advanced output must be at least as large as basic output"
            fi
        fi
    rlPhaseEnd

    rlPhaseStartTest "NetcapAdvancedSshdVisible"
        if ! $ADVANCED_AVAILABLE; then
            rlLog "Skipping — netcap --advanced not available"
        else
            rlAssertGrep "sshd" "${TmpDir}/netcap-advanced.out"
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        if $SSHD_STARTED_BY_TEST; then
            rlRun "systemctl stop sshd" 0 "Stopping sshd started by test"
        fi
        rlRun "rm -rf ${TmpDir}" 0 "Removing tmp directory"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
