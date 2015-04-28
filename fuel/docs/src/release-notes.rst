:Authors: Jonas Bjurel (Ericsson)
:Version: 0.2

================================================================
OPNFV Release Note for "Arno-RC2 release candidate" - Fuel@OPNFV
================================================================

Abstract
========

This document provides the release notes for ARNO-RC2 release candidate of Fuel@OPNFV.

License
=======
Fuel@OPNFV DOCs (c) by Jonas Bjurel (Ericsson AB)

Fuel@OPNFV DOCs are licensed under a Creative Commons Attribution 4.0 International License. You should have received a copy of the license along with this. If not, see <http://creativecommons.org/licenses/by/4.0/>.


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
| 2015-04-16         | 0.1                | Jonas Bjurel       | First draft        |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+
| 2015-04-23         | 0.2                | Jonas Bjurel       | Minor change       |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+

2   Important notes
===================

This is the first OPNFV Arno pre-release that implements the deploy stage of the OPNFV CI pipeline.

Carefully follow the installation-instructions and pay special attention to the pre-deploy script that needs to be ran befor deployment is started.

3   Summary
===========

Arno Fuel@OPNFV is based the OpenStack Fuel upstream project version 6.0.1, but adds OPNFV unique components such as OpenDaylight version: Helium as well as other OPNFV unique configurations.

This Arno pre-release of Fuel@OPNFV adds the deploy stage of the OPNFV CI pipeline

- Documentation is built by Jenkins
- .iso image is built by Jenkins
- Jenkins deploy an Fuel@OPNFV stack instance on a nested hypervisor environment (KVM)

Automatic test of the deployed system is not part of this pre-release.

4   Release Data
================

+--------------------------------------+--------------------------------------+
| **Project**                          | Arno/genesis/fuel                    |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | genesis/arno-rc2                     |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release designation**              | Arno RC2                             |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release date**                     | 2015-04-16                           |
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
This is the first tracked version of genesis/fuel. It is based on following upstream versions:

- Fuel 6.0.1 (Juno release)

- OpenDaylight Helium-SR2

- Ubuntu 12.04.5

4.1.2   Document version changes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
This is the first tracked version of genesis/fuel. It comes with the following documentation:

- OPNFV Installation instructions for - Fuel@OPNFV - ver. 0.0.1
- OPNFV Release Note for "Arno-RC2 release candidate" - Fuel@OPNFV - ver. 0.1 (this document)

4.2 Reason for version
----------------------
4.2.1 Feature additions
~~~~~~~~~~~~~~~~~~~~~~~

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA:                                | Baselining Fuel 6.0.1 for OPNFV      |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA:                                | Integration of OpenDaylight          |
|                                      |                                      |
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
Fuel@OPNFV .iso file

4.3.2   Documentation deliverables
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- OPNFV Installation instructions for - Fuel@OPNFV - ver. 0.0.1
- OPNFV Release Note for "Arno-RC2 release candidate" - Fuel@OPNFV - ver. 0.1 (this document)

5  Known Limitations, Issues and Workarounds
============================================

5.1    System Limitations
-------------------------

**Max number of blades:**   1 Fuel master, 3 Controllers, 20 Compute blades

**Min number of blades:**   1 Fuel master, 1 Controller, 1 Compute blade

**Storage:**    Ceph is the only supported storage configuration.

**Max number of networks:**   3800 (Needs special switch config.)

**L3Agent:**   L3 agent and floating IPs is not supported.

5.2    Known issues
-------------------

**JIRA TICKETS:**

+--------------------------------------+--------------------------------------+
| **JIRA REFERENCE**                   | **SLOGAN**                           |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| JIRA:                                | CentOS is not supported              |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

5.3    Workarounds
------------------
**-**


6  Test Result
==============

Fuel@OPNFV Arno RC2 has undergone QA test runs with the following results:

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
