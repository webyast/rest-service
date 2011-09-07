#
# example spec file for package webyast-example-ws
#
# Copyright (c) 2010 SUSE LINUX Products GmbH, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           webyast-example-ws
#allows to search for missing interface
Provides:       WebYaST(org.example.plugin)
#webservice already require yast2-dbus-server which is needed for yapi
PreReq:         yast2-webservice
License:	      BSD
Group:          Productivity/Networking/Web/Utilities
URL:            http://en.opensuse.org/Portal:WebYaST
Autoreqprov:    on
Version:        0.1
Release:        0
Summary:        WebYaST - example plugin service
Source:         www.tar.bz2
Source1:        example.service.conf
Source2:        exampleService.rb
Source3:        example.service.service
Source4:        org.opensuse.yast.system.example.policy
Source5:        wicd-rpmlintrc
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch
BuildRequires:  rubygem-yast2-webservice-tasks rubygem-restility

BuildRequires:  webyast-base-ws-testsuite
BuildRequires:	rubygem-test-unit rubygem-mocha

#
%define plugin_dir %{webyast_ws_dir}/vendor/plugins/example
#

%package testsuite
Group:    Productivity/Networking/Web/Utilities
Requires: %{name} = %{version}
Requires: webyast-base-ws-testsuite
Summary:  Testsuite for webyast-example-ws package

%description
WebYaST - Plugin providing EXAMPLE REST based interface

Authors:
--------
    Josef Reidinger <jreidinger@novell.com>

%description testsuite
This package contains complete testsuite for webyast-example-ws webservice package.
It's only needed for verifying the functionality of the module and it's not
needed at runtime.

%prep
%setup -q -n www

%build

%check
# run the testsuite
%webyast_ws_check

%install

#
# Install all web and frontend parts.
#
mkdir -p $RPM_BUILD_ROOT%{plugin_dir}
cp -a * $RPM_BUILD_ROOT%{plugin_dir}
rm -f $RPM_BUILD_ROOT%{plugin_dir}/COPYING

#Dbus service permissions configuration
mkdir -p $RPM_BUILD_ROOT/etc/dbus-1/system.d/
cp %{SOURCE1} $RPM_BUILD_ROOT/etc/dbus-1/system.d/
# binary providing DBus service - place is specified in service config
mkdir -p $RPM_BUILD_ROOT/usr/local/sbin/
cp %{SOURCE2} $RPM_BUILD_ROOT/usr/local/sbin
#Dbus service describotion
mkdir -p $RPM_BUILD_ROOT/usr/share/dbus-1/system-services/
cp %{SOURCE3} $RPM_BUILD_ROOT/usr/share/dbus-1/system-services/
#policies
mkdir -p $RPM_BUILD_ROOT/usr/share/PolicyKit/policy/
cp %{SOURCE4} $RPM_BUILD_ROOT/usr/share/PolicyKit/policy/

%clean
rm -rf $RPM_BUILD_ROOT

%post
# granting all permissions for the webservice user and root
polkit-auth --user root --grant org.opensuse.yast.system.example.read > /dev/null || :
polkit-auth --user root --grant org.opensuse.yast.system.example.write > /dev/null || :

%postun

%files 
%defattr(-,root,root)
%dir %{webyast_ws_dir}
%dir %{webyast_ws_dir}/vendor
%dir %{webyast_ws_dir}/vendor/plugins
%dir %{plugin_dir}
%{plugin_dir}/Rakefile
%{plugin_dir}/app
%{plugin_dir}/config
%attr(744,root,root) /usr/local/sbin/exampleService.rb
%attr(644,root,root) /usr/share/PolicyKit/policy/org.opensuse.yast.system.example.policy
%attr(644,root,root) /etc/dbus-1/system.d/example.service.conf
%attr(644,root,root) /usr/share/dbus-1/system-services/example.service.service
%doc COPYING

%files testsuite
%defattr(-,root,root)
%{plugin_dir}/test

%changelog
