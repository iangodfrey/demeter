package  Demeter::UI::Artemis::ShowText;

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use strict;
use warnings;

use Wx qw( :everything );
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_LISTBOX EVT_BUTTON EVT_RADIOBOX EVT_CHOICE);


sub new {
  my ($class, $parent, $content, $title) = @_;

  my $this = $class->SUPER::new($parent, -1, $title,
				Wx::GetMousePosition, [475,350],
				wxMINIMIZE_BOX|wxCLOSE_BOX|wxCAPTION|wxSYSTEM_MENU|wxRESIZE_BORDER
			       );
  my $vbox  = Wx::BoxSizer->new( wxVERTICAL );

  my $text = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
			       wxVSCROLL|wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxNO_BORDER);
  $text -> SetFont(Wx::Font->new( 10, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $text -> SetValue($content);
  $vbox  -> Add($text, 1, wxGROW|wxALL, 5);
  my $button = Wx::Button->new($this, wxID_OK, q{}, wxDefaultPosition, wxDefaultSize, 0,);
  $vbox -> Add($button, 0, wxGROW|wxALL, 5);


  $this -> SetSizer( $vbox );
  return $this;
};

sub ShouldPreventAppExit {
  0
};

1;
