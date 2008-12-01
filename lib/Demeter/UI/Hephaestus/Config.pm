package Demeter::UI::Hephaestus::Config;
use strict;
use warnings;
use Carp;
use Wx qw( :everything );

use base 'Demeter::UI::Wx::Config';

#use base 'Wx::Panel';

sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, \&target);
  $self->{echo} = $echoarea;
  $self->populate('hephaestus');

  return $self;
};

sub target {
  my ($self, $parent, $param, $value, $save) = @_;

 SWITCH: {
    ($param eq 'plotwith') and do {
      $Demeter::UI::Hephaestus::demeter->po->plot_with($value);
      last SWITCH;
    };
    ($param eq 'resource') and do {
      1;
      last SWITCH;
    };
    ($param eq 'units') and do {
      1;
      last SWITCH;
    };
    ($param eq 'xsec') and do {
      1;
      last SWITCH;
    };
    ($param eq 'ion_pressureunits') and do {
      1;
      last SWITCH;
    };
  };

  ($save)
    ? $self->{echo}->echo("Now using $value for $parent-->$param and an ini file was saved")
      : $self->{echo}->echo("Now using $value for $parent-->$param");

};


1;

=head1 NAME

Demeter::UI::Hephaestus::Config - Hephaestus' electronic transitions utility

=head1 VERSION

This documentation refers to Demeter version 0.2.

=head1 SYNOPSIS

The contents of Hephaestus' electronic transistions utility can be
added to any Wx application.

  my $page = Demeter::UI::Hephaestus::Config->new($parent,\&callback);
  $sizer -> Add($page, 1, wxGROW|wxEXPAND|wxALL, 0);

The arguments to the constructor method are a reference to the parent
in which this is placed and a reference to a method that does some
post-processing of the parameters after they are set.

C<$page> contains most of what is displayed in the main part of the
Hephaestus frame.  Only the label at the top is not included in
C<$page>.

=head1 DESCRIPTION

This utility presents a diagram explaining the electronic transitions
associated with the various fluorescence lines.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

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