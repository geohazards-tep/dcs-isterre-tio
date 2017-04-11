Name:		nsbas_invers_optic
Version:	r1824
Release:	1%{?dist}
Summary:	The invers_pixel program from NSBAS customized for optical data

License:	GPL-3.0
URL:		http://www.isterre.fr/
Source0:	nsbas_invers_optic-%{version}.tar.bz2

BuildRequires: devtoolset-1.1-gcc
BuildRequires: devtoolset-1.1-gcc-gfortran

%description
The invers_pixel program from NSBAS customized for optical data


%prep
%setup -q


%build
source /opt/centos/devtoolset-1.1/enable
sed 's/^LDFLAGS *=.*$/LDFLAGS = -static-libgcc -static-libgfortran/' mk/linux.gnu-toolchain.mk > mk/build.mk
make %{?_smp_mflags} -Csrc/common base math lapack
make %{?_smp_mflags} -Csrc/timeseries ../../bin/invers_pixel


%install
#%make_install
mkdir -p %{buildroot}/%{_bindir}
install -m 0755 bin/invers_pixel %{buildroot}/%{_bindir}

%files
%{_bindir}/invers_pixel



%changelog

