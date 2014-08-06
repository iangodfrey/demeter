package Demeter::UI::Athena::XDI;

use strict;
use warnings;
use Const::Fast;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_TEXT EVT_TEXT_ENTER EVT_TREE_ITEM_RIGHT_CLICK EVT_MENU);
use Demeter::UI::Athena::XDIAddParameter;
#use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($label);
$label = "File metadata";

my $tcsize = [60,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  if (not exists $INC{'Xray/XDI.pm'}) {
    $box->Add(Wx::StaticText->new($this, -1, "File metadata is not enabled on this computer.\nThe most likely reason is that the perl module Xray::XDI is not available."), 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 5);
    $box->Add(1,1,1);
  } else {


    my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize;

    ## versioning information
    my $versionbox       = Wx::StaticBox->new($this, -1, 'Versions', wxDefaultPosition, wxDefaultSize);
    my $versionboxsizer  = Wx::StaticBoxSizer->new( $versionbox, wxHORIZONTAL );
    $this->{sizer}      -> Add($versionboxsizer, 0, wxALL|wxGROW, 0);

    $this->{xdi}  = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [ 60,-1], wxTE_READONLY);
    $this->{apps} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [200,-1], wxTE_READONLY);
    $versionboxsizer -> Add(Wx::StaticText->new($this, -1, "XDI version"),  0, wxALL, 5);
    $versionboxsizer -> Add($this->{xdi}, 0, wxALL|wxALIGN_CENTER, 5);
    $versionboxsizer -> Add(Wx::StaticText->new($this, -1, "Applications"), 0, wxALL, 5);
    $versionboxsizer -> Add($this->{apps}, 1, wxALL|wxALIGN_CENTER, 5);


    ## Defined fields
    my $definedbox      = Wx::StaticBox->new($this, -1, 'XDI Metadata', wxDefaultPosition, wxDefaultSize);
    my $definedboxsizer = Wx::StaticBoxSizer->new( $definedbox, wxVERTICAL );
    $this->{sizer}     -> Add($definedboxsizer, 3, wxALL|wxGROW, 0);
    $this->{defined}    = Wx::ScrolledWindow->new($this, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);
    $definedboxsizer->Add($this->{defined}, 1, wxALL|wxGROW, 5);
    my $defbox  = Wx::BoxSizer->new( wxVERTICAL );
    $this->{defined} -> SetSizer($defbox);
    $this->{defined} -> SetScrollbars(0, 20, 0, 50);
    ## edit toggle

    $this->{tree} = Wx::TreeCtrl->new($this->{defined}, -1, wxDefaultPosition, wxDefaultSize,
				      wxTR_HIDE_ROOT|wxTR_SINGLE|wxTR_HAS_BUTTONS);
    $defbox -> Add($this->{tree}, 1, wxALL|wxGROW, 0);
    $this->{root} = $this->{tree}->AddRoot('Root');
    #EVT_TREE_ITEM_RIGHT_CLICK($this, $this->{tree}, sub{OnRightClick(@_)});

    $this->{tree}->SetFont( Wx::Font->new( $size - 1, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );


    my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
    $this->{expand}   = Wx::Button->new($this, -1, "Expand all");
    $this->{collapse} = Wx::Button->new($this, -1, "Collapse all");
    $definedboxsizer -> Add($hbox, 0, wxALL|wxGROW, 0);
    $hbox            -> Add($this->{expand},  1, wxALL|wxGROW, 5);
    $hbox            -> Add($this->{collapse}, 1, wxALL|wxGROW, 5);
    EVT_BUTTON($this, $this->{expand},   sub{$this->{tree}->ExpandAll});
    EVT_BUTTON($this, $this->{collapse}, sub{$this->{tree}->CollapseAll});

    ## extension fields
    # my $extensionbox      = Wx::StaticBox->new($this, -1, 'Extension fields', wxDefaultPosition, wxDefaultSize);
    # my $extensionboxsizer = Wx::StaticBoxSizer->new( $extensionbox, wxVERTICAL );
    # $this->{sizer}       -> Add($extensionboxsizer, 1, wxALL|wxGROW, 0);
    # $this->{extensions}   = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
    # 					      wxTE_MULTILINE|wxHSCROLL|wxTE_AUTO_URL|wxTE_RICH2);
    # $this->{extensions}  -> SetFont( Wx::Font->new( $size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
    # $extensionboxsizer->Add($this->{extensions}, 1, wxALL|wxGROW, 5);

    ## comments
    my $commentsbox      = Wx::StaticBox->new($this, -1, 'Comments', wxDefaultPosition, wxDefaultSize);
    my $commentsboxsizer = Wx::StaticBoxSizer->new( $commentsbox, wxHORIZONTAL );
    $this->{sizer}      -> Add($commentsboxsizer, 1, wxALL|wxGROW, 0);
    $this->{comments}    = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
					     wxTE_MULTILINE|wxHSCROLL|wxTE_AUTO_URL|wxTE_RICH2);
    $this->{comments}   -> SetFont( Wx::Font->new( $size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
    $commentsboxsizer->Add($this->{comments}, 1, wxALL|wxGROW, 5);

    $this->{savecomm}   = Wx::Button->new($this, -1, "Save\ncomments");
    $commentsboxsizer->Add($this->{savecomm}, 0, wxALL|wxGROW, 5);
    EVT_BUTTON($this, $this->{savecomm}, sub{ &OnSaveComments });

  };

  $this->{document} = Wx::Button->new($this, -1, 'Document section: XAS metadata');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("other.meta")});

  $this->SetSizerAndFit($box);
  return $this;
};

sub pull_values {
  my ($this, $data) = @_;
  return if ((not ($INC{'Xray/XDI.pm'}) or (not $data->xdi)));
  my @commtext = split(/\n/, $this->{comments}  ->GetValue);
  return $this;
};

my $WHITE = Wx::Colour->new(wxWHITE);
my $GRAY  = Wx::Colour->new(wxLIGHT_GREY);


## this subroutine fills the controls when an item is selected from the Group list
sub push_values {
  my ($this, $data) = @_;
  return if not $INC{'Xray/XDI.pm'};
  $this->{$_}->SetValue(q{}) foreach (qw(xdi apps comments));
  $this->{tree}->DeleteChildren($this->{root});
  return if not $data->xdi;
  my $outer_count = 0;
  foreach my $namespace ($data->xdi_families) {
    my $count = $outer_count++;
    next if ($namespace =~ m{athena|artemis}i);
    my $leaf = $this->{tree}->AppendItem($this->{root}, sprintf("%-72s", ucfirst($namespace)));
    $this->{tree} -> SetItemBackgroundColour($leaf,  ($count++ % 2) ? wxWHITE : wxLIGHT_GREY );
    foreach my $tag ($data->xdi_tags($namespace)) {
      my $value = $data->xdi_datum($namespace, $tag);
      my $string = sprintf("%-20s = %-47s", lc($tag), $value);
      my $item = $this->{tree}->AppendItem($leaf, $string);
      $this->{tree} -> SetItemBackgroundColour($item,  ($count++ % 2) ? wxWHITE : wxLIGHT_GREY );
    };
    $this->{tree}->Expand($leaf);
  };
  $this->{xdi}->SetValue($data->xdi_attribute('xdi_version'));
  $this->{apps}->SetValue($data->xdi_attribute('extra_version'));
  $this->{comments}  ->SetValue($data->xdi_attribute('comments'));
  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};


sub OnSaveComments {
  my ($this, $event) = @_;
  my $data = $::app->current_data;
  $data->xdi->comments($this->{comments}->GetValue);
  $::app->{main}->status("Saved changes to XDI comments.")
};

# const my $EDIT   => Wx::NewId();
# const my $ADD    => Wx::NewId();
# const my $DELETE => Wx::NewId();

# sub OnRightClick {
#   my ($tree, $event) = @_;
#   my $text = $tree->{tree}->GetItemData($event->GetItem)->GetData;
#   return if ($text !~ m{(\w+)\.(\w+) = (.+)});
#   my ($namespace, $parameter, $value) = ($1, $2, $3);
#   my $menu  = Wx::Menu->new(q{});
#   $menu->Append($EDIT,   "Edit ".ucfirst($namespace).".$parameter");
#   $menu->Append($ADD,    "Add a parameter to ".ucfirst($namespace)." namespace");
#   $menu->Append($DELETE, "Delete ".ucfirst($namespace).".$parameter");
#   EVT_MENU($menu, -1, sub{ $tree->DoContextMenu(@_, $namespace, $parameter, $value) });
#   $tree -> PopupMenu($menu, $event->GetPoint);

#   $event->Skip(1);
# };

# sub DoContextMenu {
#   my ($xditool, $menu, $event, $namespace, $parameter, $value) = @_;
#   my $data = $::app->current_data;
#   if ($event->GetId == $EDIT) {
#     my $method = "set_xdi_".$namespace;
#     my $ted = Wx::TextEntryDialog->new($::app->{main}, "Enter a new value for \"$namespace.$parameter\":", "$namespace.$parameter",
# 				       $value, wxOK|wxCANCEL, Wx::GetMousePosition);
#     #$::app->set_text_buffer($ted, "xdi");
#     $ted->SetValue($value);
#     if ($ted->ShowModal == wxID_CANCEL) {
#       $::app->{main}->status("Resetting XDI parameter canceled.");
#       return;
#     };
#     my $newvalue = $ted->GetValue;
#     $data->$method($parameter, $newvalue);

#   } elsif ($event->GetId == $ADD) {
#     my $method = "set_xdi_".$namespace;
#     my $addparam = Demeter::UI::Athena::XDIAddParameter->new($xditool, $data, $namespace);
#     my $response = $addparam->ShowModal;
#     if ($response eq wxID_CANCEL) {
#       $::app->{main}->status("Adding metadata canceled");
#       return;
#     };
#     return if ($addparam->{param}->GetValue =~ m{\A\s*\z});
#     #print $addparam->{param}->GetValue, "  ", $addparam->{value}->GetValue, $/;
#     $data->$method($addparam->{param}->GetValue, $addparam->{value}->GetValue);
#     undef $addparam;

#   } elsif ($event->GetId == $DELETE) {
#     my $which = ucfirst($namespace).".$parameter";
#     my $yesno = Demeter::UI::Wx::VerbDialog->new($::app->{main}, -1,
# 						 "Really delete $which?",
# 						 "Really delete $which?",
# 						 "Delete");
#     my $result = $yesno->ShowModal;
#     if ($result == wxID_NO) {
#       $::app->{main}->status("Not deleting $which");
#       return 0;
#     };
#     my $method = "delete_from_xdi_".$namespace;
#     $data->$method($parameter);
#     $::app->{main}->status("Deleted $which");
#   };
#   $xditool->push_values($data);

# };

# sub OnParameter {
#   my ($this, $param) = @_;
#   my $data = $::app->current_data;
#   my $att = 'xdi_'.$param;
#   $data->$att($this->{$param}->GetValue)
# };


1;


=head1 NAME

Demeter::UI::Athena::XDI - An XDI metadata displayer for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 SYNOPSIS

This module provides a simple, tree-based overview of XDI defined
metadata and textual interfaces to other kinds of metadata.  Metadata
can be edited, added, and deleted.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
