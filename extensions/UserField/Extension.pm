# UserField extension for Bugzilla
# License: Mozilla Public License 2.0 (same as Bugzilla itself)
#
# Turns one or more existing "Free Text" custom fields (type cf_xxx) into a
# user picker: the value must be the login name of an existing Bugzilla
# account, and the field gets the same autocomplete widget used for
# Assignee / CC / QA Contact.
#
# HOW IT WORKS
#   1. object_validators  - whenever a bug is created or edited (through the
#      web UI, email_in.pl, or the REST/XML-RPC API), the value entered for
#      each field listed in USER_FIELDS is resolved against Bugzilla's user
#      list and normalised to a canonical login name. An invalid login
#      throws Bugzilla's normal "no such user" error.
#   2. template_before_process - tells bug/field.html.tmpl which fields are
#      "user fields", by injecting a lookup hash into the template variables.
#   3. template/en/default/hook/bug/field-end_field_column.html.tmpl
#      - the actual hook template. For fields listed in USER_FIELDS, it
#      prints the small piece of HTML/JS needed to attach Bugzilla's
#      built-in YUI user-autocomplete widget (the same one used by the
#      Assignee/CC/QA Contact fields) to the plain text input that
#      bug/field.html.tmpl already rendered for the FREETEXT field type.
#
# INSTALLATION
#   1. Copy this whole "UserField" directory into Bugzilla's extensions/
#      directory, so you end up with extensions/UserField/Extension.pm etc.
#   2. In Administration -> Custom Fields, create a "Free Text" field
#      (e.g. cf_owner). Do NOT try to select a "User" type - it doesn't
#      exist in stock Bugzilla; Free Text is correct here.
#   3. Add the field's name to the USER_FIELDS list below.
#   4. Run ./checksetup.pl from the Bugzilla root once, so Bugzilla picks
#      up the new extension and recompiles its templates.
#   5. Restart Apache/mod_perl if you run Bugzilla under mod_perl (plain
#      CGI installs don't need a restart).
#   6. Make sure Administration -> Parameters -> "User Matching" ->
#      ajax_user_autocompletion is switched On (it is by default on most
#      installs) - that parameter is what turns on the autocomplete widget
#      at all, even for the built-in Assignee/CC fields.
#
# LIMITATIONS
#   - One login per field (like Assignee/QA Contact), not a multi-user list
#     like CC. If you need a multi-user field, the "field_type == FIELD_TYPE_MULTI_SELECT" 
#     branch of userselect.html.tmpl combined with the "multiple" flag on
#     the autocomplete widget is the place to start extending this.
#   - No group restriction (any Bugzilla account can be entered). If you
#     need to restrict to a group, resolve the login in _check_user_field
#     below and additionally check $user->in_group('your_group') there.
#   - The value is stored as plain text (the field is a real FREETEXT
#     field), so advanced search operators specific to user fields (like
#     "is one of my bugs") don't apply - only text search operators do.

package Bugzilla::Extension::UserField;

use 5.14.0;
use strict;
use warnings;

use parent qw(Bugzilla::Extension);

use Bugzilla::User;
use Bugzilla::Util qw(trim);

our $VERSION = '1.0';

# ---------------------------------------------------------------------
# EDIT THIS: the names of the Free Text custom fields that should behave
# as user pickers. Each name must already exist as a Free Text custom
# field (Administration -> Custom Fields) before you add it here.
# ---------------------------------------------------------------------
use constant USER_FIELDS => qw(
  cf_owner
);

# --- Validation -------------------------------------------------------
# Runs for bug creation *and* bug edits, from the UI, email_in.pl, and
# the REST/XML-RPC API, because it plugs into Bugzilla::Object's shared
# validator table.
sub object_validators {
  my ($self, $args) = @_;
  my ($class, $validators) = @$args{qw(class validators)};

  return unless $class->isa('Bugzilla::Bug');

  foreach my $field_name (USER_FIELDS) {
    $validators->{$field_name} = \&_check_user_field;
  }
}

sub _check_user_field {
  my ($invocant, $value, $field) = @_;

  $value = defined($value) ? trim($value) : '';
  return '' if $value eq '';

  # Throws a standard Bugzilla "there is no user with that login" error
  # if $value doesn't match an existing account. Returns the canonical
  # login name (not whatever casing/whitespace the user typed).
  my $user = Bugzilla::User->check($value);
  return $user->login;
}

# --- Template wiring ---------------------------------------------------
# bug/field.html.tmpl is included once per field, for every field, on the
# bug creation page, the bug edit page, and the bulk-view page. We only
# need to tell it which field names are "user fields"; the actual widget
# markup lives in the hook template.
sub template_before_process {
  my ($self, $args) = @_;
  my ($vars, $file) = @$args{qw(vars file)};

  return unless $file eq 'bug/field.html.tmpl';

  $vars->{user_field_hash} ||= {map { $_ => 1 } USER_FIELDS};
}

__PACKAGE__->NAME;
