# Puppet installation

---
## Puppet modules

###genesis
[https://gerrit.opnfv.org/gerrit/genesis](https://gerrit.opnfv.org/gerrit/genesis)

This module is a small set of puppet code. Its intention is mostly to glue the variables in foreman to the quickstack module. These classes could also be used as a site.pp node manifest for running a puppet apply.

There is a class for each the control node, network node and compute nodes. The site.pp/node-manifest should have one of these classes and the
appropriate variables that they check for applied to each of the them. This module will invoke the quickstack classes.

There is not HA or ceph configuration in this module yet, though quickstack does support them so they can be added.

###Quickstack

[https://github.com/radez/astapor/tree/opendaylight](https://github.com/radez/astapor/tree/opendaylight)

This module is the composition layer that will tie together all the puppet modules that will install openstack together.

Quickstack is maintained as part of astapor. Pull the astapor module from this fork and link the  puppet/modules/quickstack directory to your puppet modules directory so it can be used.

The fork is necessary because there is a patch on this fork to teach quickstack how to configure neutron with ODL.

Once this patch is merged the upstream astapor module can be cloned from upstream at
[https://github.com/redhat-openstack/astapor](https://github.com/redhat-openstack/astapor).

### openstack-puppet-modules (OPM)
*or the stackforge puppet modules*

[https://repos.fedorapeople.org/repos/openstack/openstack-juno/epel-7/](https://repos.fedorapeople.org/repos/openstack/openstack-juno/epel-7/)

Pull the latest copy of the openstack-puppet-modules rpm from RDO. This rpm has all the puppet modules needed to install openstack in it that have been tested together. You could also just pull all the stackforge modules. Put these modules on your puppet module path.

### puppet-opendaylight
[https://github.com/dfarrell07/puppet-opendaylight](https://github.com/dfarrell07/puppet-opendaylight)

This module is not included in OPM pull a clone a copy of it to your puppet modules path.

---
##Installation Options
###Puppet apply

TODO: add details to do a puppet apply install

###Foreman
[http://theforeman.org/](http://theforeman.org/)

Foreman is a provisioning and puppet master platform in one project.

TODO: add foreman installation details


