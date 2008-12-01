package Demeter::Data::IO;

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Moose::Role;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER   => $RE{num}{real};
use Carp;

sub save {
  my ($self, $what, $filename) = @_;
  croak("No filename specified for save") unless $filename;
  ($what = 'chi') if (lc($what) eq 'k');
  ($what = 'xmu') if (lc($what) eq 'e');
  croak("Valid save types are: xmu norm chi r q fit bkgsub")
    if ($what !~ m{\A(?:xmu|norm|chi|r|q|fit|bkgsub)\z});
  my $string = q{};
 WHAT: {
    (lc($what) eq 'fit') and do {
      $string = $self->_save_fit_command($filename);
      last WHAT;
    };
    (lc($what) eq 'xmu') and do {
      $self->_update("fft");
      carp("cannot save mu(E) file from chi(k) data"), return if ($self->datatype eq "chi");
      $string = $self->_save_xmu_command($filename);
      last WHAT;
    };
    (lc($what) eq 'norm') and do {
      $self->_update("fft");
      carp("cannot save norm(E) file from chi(k) data"), return if ($self->datatype eq "chi");
      $string = $self->_save_norm_command($filename);
      last WHAT;
    };
    (lc($what) eq 'chi') and do {
      $self->_update("fft");
      $string = $self->_save_chi_command('k', $filename);
      last WHAT;
    };
    (lc($what) eq 'r') and do {
      $self->_update("bft");
      $string = $self->_save_chi_command('r', $filename);
      last WHAT;
    };
    (lc($what) eq 'q') and do {
      $self->_update("all");
      $string = $self->_save_chi_command('q', $filename);
      last WHAT;
    };
    (lc($what) eq 'bkgsub') and do {
      $self->_update("all");
      $string = $self->_save_bkgsub_command($filename);
      last WHAT;
    };
  };
  $self->dispose($string);
  return $self;
};


sub _save_chi_command {
  my ($self, $space, $filename) = @_;
  my $pf = $self->po;
  if (not $self->plottable) {
    my $class = ref $self;
    croak("$class objects do not have data that can be saved");
  };
  my $string = q{};
  $space = lc($space);
  croak("Demeter: '$space' is not a valid space for saving chi xdata (k k1 k2 k3 r q)")
    if ($space !~ /\A(?:k$NUMBER?|r|q)\z/); # }

  my $data = $self->data;
  my $how = ($space eq 'k') ? "chi(k)" :
            ($space eq 'r') ? "chi(R)" :
	                      "chi(q)" ;
  $self->title_glob("dem_data_", $space);

  my ($label, $columns) = (q{}, q{});
  if ($space =~ m{\Ak0?\z}) {
    $self->_update("bft");
    $string = $self->template("process", "save_chik", {filename => $filename,
						       titles   => "dem_data_*"});
  } elsif ($space =~ /\Ak($NUMBER)/) {
    croak("Not doing arbitrary wight chi(k) files just now");
    #$string .= sprintf("set %s.chik = %s.k^%.3f*%s.chi\n", $self, $self, $1, $self);
    #$label   = "k chi" . int($1) . " win";
    #$columns = "$self.k, $self.chik, $self.win";
    #$how = "chi(k) * k^$1";
  } elsif ($space eq 'r') {
    $self->_update("all");
    $string = $self->template("process", "save_chir", {filename => $filename,
						       titles   => "dem_data_*"});
  } elsif ($space eq 'q') {
    $self->_update("all");
    $string = $self->template("process", "save_chiq", {filename => $filename,
						       titles	  => "dem_data_*",});
  } else {
    croak("Demeter::save: How did you get here?");
  }

  return $string;
};



## need to include the data's titles in write_data() command
sub _save_fit_command {
  my ($self, $filename) = @_;
  croak("No filename specified for save_fit") unless $filename;
  $self->title_glob("dem_data_", "f");
  my $command = $self-> template("fit", "save_fit", {filename => $filename,
						     titles   => "dem_data_*"});
  return $command;
};

sub _save_bkgsub_command {
  my ($self, $filename) = @_;
  croak("No filename specified for save_bkgsub") unless $filename;
  $self->title_glob("dem_data_", "f");
  my $command = $self-> template("fit", "save_bkgsub", {filename => $filename,
							titles   => "dem_data_*"});
  return $self;
};


sub data_parameter_report {
  my ($self, $include_rfactor) = @_;
  my $string = $self->data->template("process", "data_report");
  $string =~ s/\+ \-/- /g;
  return $string;
};
sub fit_parameter_report {
  my ($self, $include_rfactor, $fit_performed) = @_;
  $include_rfactor ||= 0;
  $fit_performed   ||= 0;
  my $string = $self->data->template("fit", "fit_report");
  if ($include_rfactor and $fit_performed) {	# only print this for a multiple data set fit
    $string .= sprintf("\nr-factor for this data set = %.7f\n", $self->rfactor);
  };
  return $string;
};

sub rfactor {
  return q{};
};


sub title_glob {
  my ($self, $globname, $space) = @_;
  my $data = $self->data;
  $space = lc($space);
  my $type = ($space eq 'e') ? " mu(E)"   :
             ($space eq 'n') ? " norm(E)" :
             ($space eq 'k') ? " chi(k)"  :
             ($space eq 'r') ? " chi(R)"  :
             ($space eq 'q') ? " chi(q)"  :
             ($space eq 'f') ? " fit"     :
	                       q{}        ;
  my @titles = split(/\n/, $data->data_parameter_report);
  @titles = split(/\n/, $data->fit_parameter_report) if ($space eq 'f');
  my $i = 0;
  $self->dispose("erase \$$globname\*");
  foreach my $line ("Demeter$type file -- Demeter $Demeter::VERSION", @titles, "--") {
    ++$i;
    my $t = sprintf("%s%2.2d", $globname, $i);
    Ifeffit::put_string($t, $line);
  };
  return $self;
};


sub read_fit {
  my ($self, $filename) = @_;
  croak("No filename specified for read_fit") unless $filename;
  my $command = $self-> template("fit", "read_fit", {filename => $filename,});
  $self->dispose($command);
  $self->update_fft(1);
  return $self;
};




1;


=head1 NAME

Demeter::Data::IO - Data Input/Output methods for Demeter

=head1 VERSION

This documentation refers to Demeter version 0.2.

=head1 SYNOPSIS

  use Demeter;
  my $data  = Demeter::Data -> new(file=>'t/fe.060', @common_attributes);
  $data->save('xmu', 'data.xmu');

=head1 DESCRIPTION

This Demeter::Data role contains methods for dealing
with data input/output.

=head1 METHODS

=over 4

=item C<save>

This method is a wrapper around Ifeffit command generators for saving
the various kinds of output files.  The syntax is

  $dataobject -> save('xmu', 'data.xmu');

The first argument is one of C<xmu>, C<norm>, C<chi>, C<r>, C<q>,
C<fit>, and C<bkgsub>.  The second argument is a file name.

=over 4

=item C<xmu>

This is a seven column file of energy, mu(E), bkg(E), preline(E),
postline(E), first derivative of mu(E), and second derivative of
mu(E).

=item C<norm>

This is a seven column file of energy, norm(E), normalized bkg(E),
flattened mu(E), flattened bkg(E), first derivative of norm(E), and
second derivative of norm(E).

=item C<chi>

This is a five column file of k, chi(k), k*chi(k), k^2*chi(k),
k^3*chi(k), and the window in k.

=item C<r>

This is a six column file of R, real part of chi(r), imaginary part of
chi(r), magnitude of chi(r), phase of chi(r), and the window in R.
The current value of kweight of the Plot object is used to generate chi(R).

=item C<q>

This is a seven column file of q, real part of chi(q), imaginary part
of chi(q), magnitude of chi(q), phase of chi(q), the window in k, the
k-weighted chi(k) used in the Fourier transform.  The current value of
kweight of the Plot object is used to generate chi(R).

=item C<fit>

Fit...

=item C<bkgsub>

Background subtracted chi(k) data....

=back

=item C<read_fit>

Reimport a fit written out by a previous instance of Demeter....

=item C<title_glob>

This pushes the title generated by the C<data_parameter_report> or
C<fit_parameter_report> methods into Ifeffit scalars which can then be
accessed by an Ifeffit title glob.

   $object -> title_glob($name, $which)

C<$name> is the base of the name of the string scalars in Ifeffit and
C<$which> is one of C<e>, C<n>, C<k>, C<r>, C<q>, or C<f> depending on
whether you wish to generate title lines for mu(E), normalized mu(E),
chi(k), chi(R), chi(q), or a fit.

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

L<Moose> is the basis of Demeter.  This module is implemented as a
role and used by the L<Demeter::Data> object.  I feel obloged
to admit that I am using Moose roles in the most trivial fashion here.
This is mostly an organization tool to keep modules small and methods
organized by common functionality.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut