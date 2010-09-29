package Demeter::UI::Athena::Group;

use Demeter;
use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Athena::ChangeDatatype;

use List::Util qw(min);

use Wx qw(:everything);
use base qw( Exporter );
our @EXPORT = qw(Rename Copy Remove change_datatype);

sub Rename {
  my ($app, $newname) = @_;
  return if $app->is_empty;

  my $data = $app->current_data;
  my $name = $data->name;
  (my $realname = $name) =~ s{\A\s*(Ref\s+)}{};
  my $is_ref = $1;

  if (not $newname) {
    my $ted = Wx::TextEntryDialog->new($app->{main}, "Enter a new name for \"$name\":", "Rename \"$name\"", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
    $ted->SetValue($name);
    if ($ted->ShowModal == wxID_CANCEL) {
      $app->{main}->status("Renaming cancelled.");
      return;
    };
    $newname = $ted->GetValue;
  };

  my $prefix = ($is_ref) ? "  Ref " : q{};
  $data->name($prefix.$newname);
  $app->{main}->{list}->SetString($app->current_index, $prefix.$newname);
  if (($data->reference) and ($data->reference->name =~ m{\A\s*(?:Ref\s+)?$realname\s*\z})) {
    my $prefix = ($is_ref) ? q{} : "  Ref ";
    $data->reference->name($prefix.$newname);
    foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
      next if ($app->{main}->{list}->GetClientData($i) ne $data->reference);
      $app->{main}->{list}->SetString($i, $prefix.$newname);
    };
  };
  $app->OnGroupSelect;
  $app->modified(1);
  $app->{main}->status("Renamed $name to $newname");
};

sub Copy {
  my ($app, $newname) = @_;
  return if $app->is_empty;

  my $data = $app->current_data;
  my $clone = $data->clone;
  $clone->name("Copy of ".$data->name);
  my $index = $app->current_index;
  if ($index == $app->{main}->{list}->GetCount-1) {
    $app->{main}->{list}->Append($clone->name, $clone);
  } else {
    $app->{main}->{list}->Insert($clone->name, $index+1, $clone);
  };
  $app->modified(1);
  $app->{main}->status("Copied ".$data->name);
};

sub Remove {
  my ($app, $how) = @_;
  $how ||= 'current';
  return if $app->is_empty;

  my $message = q{};
  my $i;
  if ($how eq 'current') {
    $i = $app->current_index;
    $message = "Removed ".$app->current_data->name;
    remove_one($app, $i);
    if ($app->{main}->{list}->GetCount > 0) {
      $i = min($i, $app->{main}->{list}->GetCount-1);
      $app->{main}->{list}->SetSelection($i);
      $app->OnGroupSelect(0,0);
    };
    $app->modified(1);
  } elsif ($how eq 'marked') {
    $i = $app->current_index;
    $message = "Removed marked groups";
    foreach my $j (reverse (0 .. $app->{main}->{list}->GetCount-1)) {
      if ($app->{main}->{list}->IsChecked($j)) {
	remove_one($app, $j);
	$i = $j;
      };
    };
    if ($app->{main}->{list}->GetCount > 0) {
      $i = min($i, $app->{main}->{list}->GetCount-1);
      $app->{main}->{list}->SetSelection($i);
      $app->OnGroupSelect(0,0);
    };
    $app->modified(1);
  } elsif ($how eq 'all') {
    $message = "Discarded entire project";
    if ($app->{modified}) {
      ## offer to save project....
      my $yesno = Wx::MessageDialog->new($app->{main},
					 "Save this project before exiting?",
					 "Save project?",
					 wxYES_NO|wxCANCEL|wxYES_DEFAULT|wxICON_QUESTION);
      my $result = $yesno->ShowModal;
      if ($result == wxID_CANCEL) {
	$app->{main}->status("Not exiting Athena after all.");
	return 0;
      };
      $app -> Export('all', $app->{main}->{currentproject}) if $result == wxID_YES;
    };
    foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
      my $this = $app->{main}->{list}->GetClientData($i);
      $this->dispose("erase \@group ".$this->group);
      $this->DEMOLISH;
    };
    $app->{main}->{list}->Clear;
    $app->Clear;
  };

  if ($app->is_empty) {
    $app->{main}->{Main}->zero_values;
    $app->{main}->{Main}->mode(0,0,0);
    $app->{selected} = -1;
    $app->modified(0);
  };
  $app->{main}->status($message);
};

sub remove_one {
  my ($app, $i) = @_;
  my $data = $app->{main}->{list}->GetClientData($i);
  $data->dispose("erase \@group ".$data->group);
  $data->DEMOLISH;
  $app->{main}->{list}->Delete($i); # this calls the selection event on the new item
};


sub change_datatype {
  my ($app) = @_;
  my $cdt = Demeter::UI::Athena::ChangeDatatype->new($app->{main}, $app);
  my $result = $cdt -> ShowModal;
  if ($result == wxID_CANCEL) {
    $app->{main}->status("Not changing datatype.");
    return;
  };

  my $newtype = ($cdt->{to}->GetSelection == 0) ? 'xmu'
              : ($cdt->{to}->GetSelection == 1) ? 'xanes'
              : ($cdt->{to}->GetSelection == 2) ? 'norm'
              : ($cdt->{to}->GetSelection == 3) ? 'chi'
              : ($cdt->{to}->GetSelection == 4) ? 'xmudat'
	      :                                   'xmu';
  if ($cdt->{how}->GetSelection == 0) {
    $app->current_data->datatype($newtype);
    $app->{main}->status("Changed current group's data type to $newtype");
  } else {
    foreach my $j (0 .. $app->{main}->{list}->GetCount-1) {
      if ($app->{main}->{list}->IsChecked($j)) {
	$app->{main}->{list}->GetClientData($j)->datatype($newtype);
      };
    };
    $app->{main}->status("Changed all marked groups to data type $newtype");
  };
  $app->modified(1);
  $app->{main}->{Main}->mode($app->current_data, 1, 0);
};

1;
