#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/libcap-ng/Sanity/cap-audit
#   Description: Verify cap-audit produces actionable and accurate
#                capability recommendations
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

rlJournalStart

    rlPhaseStartSetup
        rlAssertRpm "$PACKAGE"
        rlAssertRpm "${PACKAGE}-utils"
        rlRun "which cap-audit" 0 "cap-audit binary must be in PATH"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
    rlPhaseEnd

    rlPhaseStartTest "CapAuditBasicRun"
        rlRun "cap-audit -- ping -c1 127.0.0.1 > ${TmpDir}/ping-audit.out 2>&1" 0 \
            "cap-audit should successfully audit ping"
        rlRun "cat ${TmpDir}/ping-audit.out"
        rlRun "test -s ${TmpDir}/ping-audit.out" 0 "Output must be non-empty"
    rlPhaseEnd

    rlPhaseStartTest "CapAuditOutputStructure"
        rlAssertGrep "CAPABILITY ANALYSIS FOR" "${TmpDir}/ping-audit.out"
        rlAssertGrep "REQUIRED CAPABILITIES" "${TmpDir}/ping-audit.out"
        rlAssertGrep "SUMMARY" "${TmpDir}/ping-audit.out"
        rlAssertGrep "RECOMMENDATIONS" "${TmpDir}/ping-audit.out"
        rlAssertGrep "Total capability checks:" "${TmpDir}/ping-audit.out"
    rlPhaseEnd

    rlPhaseStartTest "CapAuditDetectsCapability"
        rlRun "cap-audit -- chroot / /bin/true > ${TmpDir}/chroot-audit.out 2>&1" 0 \
            "cap-audit should successfully audit chroot"
        rlRun "cat ${TmpDir}/chroot-audit.out"
        rlAssertGrep "sys_chroot" "${TmpDir}/chroot-audit.out"
        rlAssertGrep "chroot" "${TmpDir}/chroot-audit.out"
        rlAssertGrep "REQUIRED CAPABILITIES" "${TmpDir}/chroot-audit.out"
    rlPhaseEnd

    rlPhaseStartTest "CapAuditUnprivilegedTarget"
        rlRun "cap-audit -- cat /dev/null > ${TmpDir}/cat-audit.out 2>&1" 0 \
            "cap-audit should successfully audit an unprivileged command"
        rlRun "cat ${TmpDir}/cat-audit.out"
        rlAssertGrep "does not require" "${TmpDir}/cat-audit.out"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -rf ${TmpDir}" 0 "Removing tmp directory"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
