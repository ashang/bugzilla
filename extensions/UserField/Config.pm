# UserField extension for Bugzilla
# License: Mozilla Public License 2.0 (same as Bugzilla itself)
#
# This file just declares the extension to Bugzilla's extension loader.
# See Extension.pm for the actual logic.

package Bugzilla::Extension::UserField;

use 5.14.0;
use strict;
use warnings;

use constant NAME => 'UserField';

use constant REQUIRED_MODULES => [];

use constant OPTIONAL_MODULES => [];

__PACKAGE__->NAME;
