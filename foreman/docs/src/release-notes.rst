:Authors: Tim Rozet (trozet@redhat.com)
:Version: 0.1

===========================================================================================
OPNFV Release Note for  the Arno release of OPNFV when using Foreman as a deployment tool
===========================================================================================

Abstract
========

This document provides the release notes for ARNO-RC2 release candidate of Foreman/QuickStack@OPNFV.

License
=======
All Foreman/QuickStack and "common" entities are protected by the Apache License ( http://www.apache.org/licenses/ )

**Contents**

1  Version History

2  Important notes

3  Summary

4  Delivery Data

5 Known Limitations, Issues and Workarounds

6 Test Result

7 References

1   Version history
===================

+--------------------+--------------------+--------------------+--------------------+
| **Date**           | **Ver.**           | **Author**         | **Comment**        |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+
| 2015-04-16         | 0.1.0              | Tim Rozet          | First draft        |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+

2   Important notes
===================

This is the first OPNFV Arno pre-release that implements the deploy stage of the OPNFV CI pipeline.

Carefully follow the installation-instructions which guide a user on how to deploy OPNFV using Foreman/QuickStack installer.

3   Summary
===========

Arno Foreman/QuickStack@OPNFV is an installer capable of setting up an OPNFV target system.  The current definition of an OPNFV target system is OpenStack Juno upstream project versioncombined with OpenDaylight version: Helium.  The system is deployed with OpenStack High Availability (HA) for most OpenStack services.  OpenDaylight is deployed in non-HA form as HA is not availble for Arno release.  Ceph storage is used as Cinder backend, and is the only supported storage for Arno.  Ceph is setup as 3 OSDs and 3 Monitors, one OSD+Mon per Controller node.

This Arno pre-release of Foreman/QuickStack@OPNFV adds the deploy stage of the OPNFV CI pipeline

- Documentation is built by Jenkins
- .iso image is built by Jenkins
- Jenkins deploys an Foreman/QuickStack@OPNFV stack to baremetal, which includes 3 control+network nodes, and 2 compute nodes.

Automatic test of the deployed system is not part of this pre-release.

4   Release Data
================

+--------------------------------------+--------------------------------------+
| **Project**                          | Arno/genesis/bgs                     |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | genesis/arno-rc2                     |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release designation**              | Arno RC2                             |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release date**                     | 2015-04-23                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Purpose of the delivery**          | OPNFV Internal quality assurance     |
|                                      | and CI Pipline dry-run               |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

4.1 Version change
------------------

4.1.1   Module version changes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
This is the first tracked version of genesis-Foreman/QuickStack. It is based on following upstream versions:

- OpenStack (Juno release)

- OpenDaylight Helium-SR2

- CentOS 7

4.1.2   Document version changes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
This is the first tracked version of genesis-Foreman/QuickStack. It comes with the following documentation:

- OPNFV Installation instructions for - Foreman/QuickStack@OPNFV - ver. 0.0.1
- OPNFV Release Note for "Arno-RC2 release candidate" - Foreman/QuickStack@OPNFV - ver. 0.1 (this document)

4.2 Reason for version
----------------------
4.2.1 Feature additions
~~~~~~~~~~~~~~~~~~~~~~~

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: BGS-4                          | OPNFV base system install            |
|                                      | using Foreman/Quickstack.            |
+--------------------------------------+--------------------------------------+

4.2.2 Bug corrections
~~~~~~~~~~~~~~~~~~~~~

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
|                                      |                                      |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

4.3 Deliverables
----------------

4.3.1   Software deliverables
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Foreman/QuickStack@OPNFV .iso file
deploy.sh - Automatically deploys Target OPNFV System to Bare Metal

4.3.2   Documentation deliverables
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- OPNFV Installation instructions for - Foreman/QuickStack@OPNFV - ver. 0.0.1
- OPNFV Release Note for "Arno-RC2 release candidate" - Foreman/QuickStack@OPNFV - ver. 0.1 (this document)

5  Known Limitations, Issues and Workarounds
============================================

5.1    System Limitations
-------------------------

**Max number of blades:**   1 Foreman/QuickStack master, 3 Controllers, 20 Compute blades

**Min number of blades:**   1 Foreman/QuickStack master, 1 Controller, 1 Compute blade

**Storage:**    Ceph is the only supported storage configuration.

**Min master requirements:** At least 2048 MB of RAM


5.2    Known issues
-------------------

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA: BGS-13                         | bridge br-ex is not auto configured  |
|                                      | by puppet                            |
+--------------------------------------+--------------------------------------+

5.3    Workarounds
------------------
**-**


6  Test Result
==============

Foreman/QuickStack@OPNFV Arno RC2 has undergone QA test runs with the following results:

+--------------------------------------+--------------------------------------+
| **TEST-SUITE**                       | **Results:**                         |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **-**                                | **-**                                |
+--------------------------------------+--------------------------------------+


7  References
=============

For more information on the OPNFV Arno release, please see:

http://wiki.opnfv.org/release/arno
