#
# spec file for package webyast-users (Version 0.1)
#
# Copyright (c) 2008 SUSE LINUX Products GmbH, Nuernberg, Germany.
# This file and all modifications and additions to the pristine
# package are under the same license as the package itself.
#
# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           webyast-users
Provides:       WebYaST(org.opensuse.yast.modules.yapi.users)
Provides:       WebYaST(org.opensuse.yast.modules.yapi.groups)
Provides:       yast2-webservice-users = %{version}
Obsoletes:      yast2-webservice-users < %{version}
PreReq:         yast2-webservice
Requires:       webyast-roles-ws
License:        GPL-2.0 
Group:          Productivity/Networking/Web/Utilities
URL:            http://en.opensuse.org/Portal:WebYaST
Autoreqprov:    on
Version:        0.2.9
Release:        0
Summary:        WebYaST - users management
Source:         www.tar.bz2
Source1:        org.opensuse.yast.modules.yapi.users.policy
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch

BuildRequires:  webyast-base-testsuite webyast-roles-ws
BuildRequires:	rubygem-test-unit rubygem-mocha tidy

#
%define plugin_name users
%define plugin_dir %{webyast_dir}/vendor/plugins/%{plugin_name}
#

%package testsuite
Group:    Productivity/Networking/Web/Utilities
Requires: %{name} = %{version}
Requires: webyast-base-testsuite webyast-roles-ws
Summary:  Testsuite for webyast-users package

%description
WebYaST - Plugin providing REST based interface to handle users settings.

Authors:
--------
    Stefan Schubert <schubi@opensuse.org>

%description testsuite
This package contains complete testsuite for webyast-users package.
It's only needed for verifying the functionality of the module and it's not
needed at runtime.

%prep
%setup -q -n www

%build
#do not package generated doc
rm -rf doc
export RAILS_PARENT=%{webyast_dir}
env LANG=en rake makemo
rake js:users

%check
# run the testsuite
%webyast_check

%install

#
# Install all web and frontend parts.
#
mkdir -p $RPM_BUILD_ROOT%{plugin_dir}
cp -a * $RPM_BUILD_ROOT%{plugin_dir}/
rm -f $RPM_BUILD_ROOT%{plugin_dir}/COPYING

# Policies
mkdir -p $RPM_BUILD_ROOT/usr/share/PolicyKit/policy
install -m 0644 %SOURCE1 $RPM_BUILD_ROOT/usr/share/PolicyKit/policy/

# remove .po files (no longer needed)
rm -rf $RPM_BUILD_ROOT/%{plugin_dir}/po

# search locale files
%find_lang webyast-users


%clean
rm -rf $RPM_BUILD_ROOT

%post
#
# granting all permissions for root 
#
/usr/sbin/grantwebyastrights --user root --action grant > /dev/null || :
# and for webyast
/usr/sbin/grantwebyastrights --user %{webyast_user} --action grant > /dev/null ||:

%files -f webyast-users.lang
%defattr(-,root,root)
%dir %{webyast_dir}
%dir %{webyast_dir}/vendor
%dir %{webyast_dir}/vendor/plugins
%dir %{plugin_dir}
%{plugin_dir}/app
%{plugin_dir}/config
%{plugin_dir}/init.rb
%{plugin_dir}/install.rb
%{plugin_dir}/uninstall.rb
%{plugin_dir}/Rakefile
%{plugin_dir}/README
%{plugin_dir}/shortcuts.yml
%{plugin_dir}/lib
%{plugin_dir}/public
%{plugin_dir}/locale

%dir /usr/share/PolicyKit
%dir /usr/share/PolicyKit/policy
%attr(644,root,root) %config /usr/share/PolicyKit/policy/org.opensuse.yast.modules.yapi.users.policy
%doc COPYING

%files testsuite
%defattr(-,root,root)
%{plugin_dir}/test

%changelog