package Demeter::Data::Prj;

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

use autodie qw(open close);

use Moose;
extends 'Demeter';
use MooseX::AttributeHelpers;

#use diagnostics;
use Carp;
use Compress::Zlib;
use Ifeffit;
use List::Util qw(max);
use List::MoreUtils qw(any none);
use Safe;

use Data::Dumper;

has 'file'    => (is => 'rw', isa => 'Str',  default => q{},
		  trigger => sub{shift -> Read} );
has 'entries' => (
		  metaclass => 'Collection::Array',
		  is        => 'rw',
		  isa       => 'ArrayRef[ArrayRef]',
		  default   => sub { [] },
		  provides  => {
				'push' => 'add_entry',
				'pop'  => 'remove_entry',
				'clear' => 'clear_entries',
			       }
		 );

sub Read {
  my ($self) = @_;
  my $file = $self->file;
  return 0 if not $file;
  if (not -e $file) {
    carp(ref($self) . ": $file does not exist");
    return -1;
  };
  if (not -r $file) {
    carp(ref($self) . ": $file cannot be read (permissions?)");
    return -1;
  };

  my @entries = ();
  my $athena_fh = gzopen($file, "rb") or die "could not open $file as an Athena project\n";
  my $nline = 0;
  my $line = q{};
  my $cpt = new Safe;
  while ($athena_fh->gzreadline($line) > 0) {
    ++$nline;
    next unless ($line =~ /^\$old_group/);
    ## need to make a map to the groups by old group name so that
    ## background removal with a standard can be performed correctly
    $ {$cpt->varglob('old_group')} = $cpt->reval( $line );
    my $og = $ {$cpt->varglob('old_group')};
    $self -> add_entry([$nline, $og]);
  };
  $athena_fh->gzclose();
};


# Note that the array referenced by the C<entries> attribute is a
# list-of-lists containing information used to locate the entry in the
# project file.  It looks something like this:
#
#   $entries_ref = [ [4, 'iaxh'],
#                    [11,'yksy'],
#                    [18,'eitj']
#                  ];
#
# Each item in the list is a reference to a two-element list containing
# the line number where the group's record begins in the project file
# and the name of the group in the Athena session that saved the project
# file.  This information can be used along with the C<record> method to
# extract individual groups from the project file.


sub list {
  my ($self, @attributes) = @_;
  my $response  = q{};
  my $length    = 0;
  my @rows;

  ## slurp up record labels and optional attributes
  foreach my $group (@{ $self->entries }) {
    my $index = $group->[0];
    my %args = $self->_array($index, 'args');
    $length = max($length, length($args{label}));
    push @rows, [$args{label}, @args{@attributes}];
  };
  $length += 3;

  ## header
  my $pattern = "#\t     %-" . $length . 's';
  $response .=  sprintf $pattern, 'record';
  foreach my $att (@attributes) {
    $response .= sprintf "%-15s", $att;
  };
  $response .= "\n# " . '-' x 60 . "\n";

  ## list
  $pattern = "\t%2d : %-" . $length . 's';
  my $i = 0;
  foreach my $row (@rows) {
    $response .= sprintf $pattern, ++$i, $row->[0];
    my $j = 1;
    foreach my $att (@attributes) {
      $response .= sprintf "%-15s", $row->[$j++];
    };
    $response .= "\n";
  };
  return $response;
};

sub slurp {
  my ($self, $which) = @_;
  ($which = q{}) if (lc($which) eq 'all');
  my @groups = @{ $self->entries };
  my @data = $self->record(1 .. $#groups+1);
  return @data;
};
{
  no warnings 'once';
  # alternate names
  *prj = \ &slurp;
}

sub record {
  my ($self, @which) = @_;
  my @groups = ();
  foreach my $g (@which) {
    my $gg = $g-1;;
    my $entries_ref = $self -> entries;
    my @this = @{ $entries_ref->[$gg] };
    push @groups, $self->_record( @this );
  };
  return (wantarray) ? @groups : $groups[0];
};
{
  no warnings 'once';
  # alternate names
  *records = \ &record;
}

sub _record {
  my ($self, $index, $groupname) = @_;
  my %args = $self->_array($index, 'args');
  my @x    = $self->_array($index, 'x');
  my @y    = $self->_array($index, 'y');

  my $data = Demeter::Data->new(group=>$groupname, from_athena=>1);
  my ($xsuff, $ysuff) = ($args{is_xmu}) ? qw(energy xmu) : qw(k chi);
  Ifeffit::put_array(join('.', $groupname, $xsuff), \@x);
  Ifeffit::put_array(join('.', $groupname, $ysuff), \@y);

  my %groupargs = ();
  foreach my $k (keys %args) {
    next if any { $k eq $_ } qw(
				 bindtag deg_tol denominator detectors
				 en_str file frozen i0 line mu_str
				 numerator old_group original_label
				 peak refsame project_marked not_data
				 bkg_switch bkg_switch2
				 is_xmu is_chi is_xanes is_xmudat
				 bkg_stan_lab
			      );
  SWITCH: {
      ($k =~ m{\A(?:lcf|peak|lr)}) and do {
	last SWITCH;
      };
      ($k eq 'titles') and do {
	last SWITCH;
      };
      ($k eq 'reference') and do {
	last SWITCH;
      };
      ($k eq 'importance') and do {
	last SWITCH;
      };
      ($k eq 'label') and do {
	$groupargs{$k} = $args{$k};
	last SWITCH;
      };

      ## back Fourier transform parameters
      ($k =~ m{\Abft_(.*)\z}) and do { # bft_win --> bft_rwindow, others are the same
	my $which = $1;
	($which = 'rwindow') if ($1 eq 'win');
	$groupargs{'bft_'.$which} = $args{$k};
	last SWITCH;
      };

      ## forward Fourier transform parameters
      ($k =~ m{\Afft_(.*)\z}) and do { # fft_win --> fft_rwindow, others are the same
	my $which = $1;
	last SWITCH if ($which eq 'kw');
	($which = 'kwindow') if ($1 eq 'win');
	if ($1 eq 'arbkw') {
	  ## do nothing with arb kw from project -- for now
	  1;
	  #$groupargs{fit_karb} = ($args{fft_arbkw}) ? 1 : 0;
	  #$groupargs{fit_karb_value} = $args{$k};
	} else {
	  $groupargs{'fft_'.$which} = $args{$k};
	};
	last SWITCH;
      };

      ## plotting parameters
      ($k =~ m{\Aplot_(.*)\z}) and do {
	if ($1 eq 'yoffset') {
	  $groupargs{'y_offset'} = $args{$k};
	} elsif ($1 eq 'scale') {
	  $groupargs{plot_multiplier} = $args{$k};
	};
	last SWITCH;
      };

      ## background and normalization parameters
      ($k =~ m{\Abkg_(.*)\z}) and do { # bft_win --> bft_rwindow, others are the same
	my $which = $1;
	($which = 'kwindow') if ($1 eq 'win');
	if (($1 =~ m{clamp[12]}) and ($args{$k} !~ m{\A\+?[0-9]+\z})) {
	  $args{$k} = $data->clamp(lc($args{$k}));
	};
	$groupargs{'bkg_'.$which} = $args{$k};
	last SWITCH;
      };

      ## is_* parameters (merge chi nor xmu xmudat xanes) = ok
      ($k =~ m{\Ais_(.*)\z}) and do {
	if (none { $1 eq $_} qw(bkg diff pixel proj qsp raw rec ref rsp)) {
	  $groupargs{$k} = $args{$k};
	};
	last SWITCH;
      };

    };
  };

  $groupargs{name} = $groupargs{label} || q{};
  delete $groupargs{label};
  $groupargs{fft_pc}   = ($args{fft_pc} eq 'None') ? 0 : 0;
  $groupargs{datatype} = ($args{is_xmu})    ? 'xmu'
                       : ($args{is_chi})    ? 'chi'
                       : ($args{is_xmudat}) ? 'xmudat'
                       : ($args{is_xanes})  ? 'xanes'
		       :                      q{};
  $groupargs{update_data} = 0;
  $data -> set(%groupargs);
  return $data;
};


## args x y i0 stddev
sub _array {
  my ($self, $index, $which) = @_;
  my $prjfile = $self->file;
  my $cpt = new Safe;
  my @array;
  my $prj = gzopen($prjfile, "rb") or die "could not open $prjfile as an Athena project\n";
  ##open A, $prjfile;
  my $count = 0;
  my $found = 0;
  my $re = '@' . $which;
  my $line = q{};
  ##foreach my $line (<A>) {
  while ($prj->gzreadline($line) > 0) {
    ++$count;
    $found = 1 if ($count == $index);
    next unless $found;
    last if ($line =~ /^\[record\]/);
    if ($line =~ /^$re/) {
      @ {$cpt->varglob('array')} = $cpt->reval( $line );
      @array = @ {$cpt->varglob('array')};
      last;
    };
  };
  $prj->gzclose();
  ##close A;
  return @array;
};


1;


=head1 NAME

Demeter::Data::Athena - Read Athena project files

=head1 VERSION

This documentation refers to Demeter version 0.2.

=head1 DESCRIPTION

This class contains methods for interacting with Athena project files.
It is not a subclass of some other Demeter method.

  $project   = Demeter::Data::Prj->new(file=>'some.prj');
  @data     = $project -> slurp;         # import all records
  ($d1, $2) = $project -> record(3, 8);  # import specific records

The script C<lsprj>, which comes with Demeter, uses this module.

See L<Demeter::Data::Athena> for Demeter's method of writing
Athena project file.

=head1 METHODS

=head2 Accessor methods

=over 4

=item C<set>

Currently, the only thing to set is C<file>.

  $prj -> set(file=>'some.prj');

Setting the file triggers reading the file.  You do not need to read
the file explicitly.

=back

=head2 Project file methods

=over 4

=item C<slurp>

Return a list containing Demeter Data objects for each group from the
project file.  This is a convenience wrapper wround the C<record>
method.

  @data_objects = $prj -> slurp

C<prj> is an alias for C<slurp>.

=item C<record>

Import a single record from the project file.

To retrieve the third group from an Athena project file:

  $data_object = $prj -> record(3);

Note that, for this method, you count the groups in the Athena project
starting with 1, where record #1 is the top-most record in the list as
displayed in Athena.

C<records> is an alias for C<record>, as in

  @data_objects = $prj -> records(3, 4, 8);

All imported records will have attributes set to values imported from
the project file.

=item C<list>

Return a listing of the labels of the groups in the project file.

  print $prj -> list;
   ==prints==>
    #     record
    # -------------------------------------------
      1 : Iron foil
      2 : Iron oxide
      3 : Iron sulfide

Optionally, a list of attributes can be passed, generating a simple
table of parameter values.

  print $prj -> list(qw(bkg_rbkg fft_kmin));
   ==prints==>
    #     record         bkg_rbkg   fft_kmin
    # -------------------------------------------
      1 : Iron foil      1.6        2.0
      2 : Iron oxide     1.0        2.0
      3 : Iron sulfide   1.0        3.0

The attributes are those for the L<Demeter::Data> object.

=back

=head1 DIAGNOSTICS

=over 4

=item C<Demeter::Data::Prj: $file does not exist>

The Athena project file cannot be found on your computer.

=item C<Demeter::Data::Prj:$file cannot be read (permissions?)>

The specified Athena project file cannot be read by Demeter, possibly
because of permissions settings.

=item C<could not open $file as an Athena project>

A problem was encountered attempting to open the Athena project file
using the L<Compress::Zlib> module.

=back

=head1 CONFIGURATION

There are no configuration options for this class.

See L<Demeter::Config> for a description of Demeter's
configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Not all Athena attributes are dealt with correctly yet -- title is the
biggie

=item *

Need to deal with chi groups, detector groups, etc.

=item *

Need to resolve interdependencies, such as background removal standard

=item *

Not dealing yet with, for instance, LCF parameters

=item *

Some information available from Ctrl-b in Athena is thrown away

=back

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