Name:		micmac
Version:	20170411.fbf9dedc4c23e026a3ff780f408395d07b14d92e
Release:	1%{?dist}
Summary:	Software for automatic matching in geographical context

License:	CeCILL-B
URL:		https://github.com/micmacIGN/micmac/archive/
Source0:	micmac-fbf9dedc4c23e026a3ff780f408395d07b14d92e.zip

BuildRequires:	ImageMagick
Requires: ImageMagick

%description
The photogrammetry software developped at the IGN (French National Geographic Institute) and ENSG (French national school for geographic sciences).

%prep
%setup -q -n micmac-fbf9dedc4c23e026a3ff780f408395d07b14d92e


%build
cmake -DWITH_QT4=off -DWITH_QT5=off -DNO_X11=on -DBUILD_POISSON=off -DBUILD_PATH_BIN=%{_bindir} -DBUILD_PATH_LIB=%{_libdir} .
make %{?_smp_mflags}


%install
%make_install
find %{buildroot} -name libANN.a -print0|xargs -0 rm
cp -Rf include %{buildroot}/%{_includedir}


%files
%{_bindir}/*
%{_libdir}/*
%{_includedir}/*
%{_includedir}/*/*


%changelog

%clean
echo NOOP
