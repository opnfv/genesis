:Authors: Jonas Bjurel (Ericsson)
:Version: 0.3

=====================================================================================
OPNFV Release Note for the Arno release of OPNFV when using Fuel as a deployment tool
=====================================================================================

Abstract
========

This document compiles the release notes for the ARNO release, when using Fuel as a deployment tool.

License
=======
Arno release with th Fuel deployment tool Docs (c) by Jonas Bjurel (Ericsson AB)

Arno release with the Fuel deployment tool Docs are licensed under a Creative Commons Attribution 4.0 International License. You should have received a copy of the license along with this. If not, see <http://creativecommons.org/licenses/by/4.0/>.


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
| 2015-05-12         | 0.3                | Chris Price        | Minor edits        |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+

2   Important notes
===================

For the first OPNFV release (Arno), these notes introduce use of `OpenStack Fuel <https://wiki.openstack.org/wiki/Fuel>`_ for the deployment stage of the OPNFV continuous integration (CI) pipeline.  The goal of the Arno release and this Fuel-based deployment process is to establish a foundational platform accelerating further development of the OPNFV infrastructure.

Carefully follow the installation-instructions and pay special attention to the pre-deploy script that needs to be run before deployment is started.

3   Summary
===========

For Arno, the typical use of Fuel as an OpenStack installer is supplemented with OPNFV unique components such as `OpenDaylight <http://www.opendaylight.org/software>`_ version Helium as well as OPNFV-unique configurations.

This Arno artefact provides Fuel as the deployment stage tool in the OPNFV CI pipeline including:

- Documentation built by Jenkins
  - this document (release notes)
  - installation instructions
  - build-instructions
- The Arno Fuel installer image (.iso) built by Jenkins
- Automated deployment of Arno with running on bare metal or a nested hypervisor environment (KVM)
- Automated validation of the Arno deployment


4   Release Data
================

+--------------------------------------+--------------------------------------+
| **Project**                          | Arno/genesis/fuel                    |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Repo/tag**                         | genesis/arno                         |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release designation**              | Arno                                 |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **Release date**                     | 2015-Spring                          |
|                                      |                                      |
+--------------------------------------+--------------------------------------+

4.1 Version change
------------------

4.1.1   Module version changes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
This is the first tracked release of genesis/fuel. It is based on following upstream versions:

- Fuel 6.0.1 (Juno release)
- OpenDaylight Helium-SR2

4.1.2   Document version changes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
This is the first tracked version of genesis/fuel. It comes with the following documentation:

- OPNFV Installation instructions for Arno with Fuel as deployment tool
- OPNFV Release Notes for Arno use of Fuel as deployment tool
- OPNFV Build instructions for Arno with Fuel as deployment tool


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
Fuel-based installer iso (opnfv.iso) file

4.3.2   Documentation deliverables
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
- OPNFV Installation instructions for Arno release with the Fuel deployment tool - ver. 0.0.1
- OPNFV Release Note for Arno release with the Fuel deployment tool - ver. 0.1 (this document)

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

Arno release with the Fuel deployment tool has undergone QA test runs with the following results:

+--------------------------------------+--------------------------------------+
| **TEST-SUITE**                       | **Results:**                         |
|                                      |                                      |
+--------------------------------------+--------------------------------------+
| **-**                                | **-**                                |
+--------------------------------------+--------------------------------------+


7  References
=============

For more information on the OPNFV Arno release, please see http://wiki.opnfv.org/releases/arno.
