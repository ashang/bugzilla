# UserField — a Bugzilla extension for user-picker custom fields

Turns a "Free Text" custom field into a Bugzilla user picker: the value
must be an existing account's login, and typing into it gets the same
autocomplete dropdown used by Assignee / CC / QA Contact.

It does **not** patch any core Bugzilla file. It only uses the extension
hook mechanism, so upgrading Bugzilla won't touch it (though a major
version bump could still change the hook names — see "Compatibility"
below).

## Why not a native "User" field type?

Stock Bugzilla's custom-field types are just: Bug ID, Large Text Box,
Free Text, Multiple-Selection Box, Drop Down, Date/Time. A native "User"
type has been requested since 2005 (Bugzilla Bug 287332) but has never
been merged — the patches that exist touch Bugzilla core files directly
and were never fully reviewed in. This extension gets the same practical
result (a field that only accepts real Bugzilla logins, with
autocomplete) without touching core files at all, by layering on top of
a plain Free Text field.

## Install

1. Copy this `UserField` folder into Bugzilla's `extensions/` directory,
   so you end up with `extensions/UserField/Extension.pm`, etc.
2. In Bugzilla, go to **Administration → Custom Fields → Add a new
   custom field**, and create a field with **Type = Free Text** (e.g.
   name it `cf_owner`). This is the field your users will actually see
   and fill in — don't look for a "User" type, it doesn't exist.
3. Open `Extension.pm` and add the field's name to the `USER_FIELDS`
   list near the top:

   ```perl
   use constant USER_FIELDS => qw(
     cf_owner
     cf_another_user_field
   );
   ```

4. From the Bugzilla root, run:

   ```
   ./checksetup.pl
   ```

   so Bugzilla registers the extension and recompiles its templates.
5. If you run Bugzilla under mod_perl, restart Apache (plain CGI
   deployments don't need this).
6. In **Administration → Parameters → User Matching**, make sure
   `ajax_user_autocompletion` is **On**. This is the same switch that
   controls autocomplete on the built-in Assignee/CC fields — if it's
   off, this extension's field will still validate correctly, it just
   won't show the autocomplete dropdown.

That's it — the field will now appear on the bug-creation page, the
bug-edit page, and the bulk-edit ("show multiple bugs") page with
autocomplete, and any value you try to save (from the web UI,
`email_in.pl`, or the REST/XML-RPC API) is checked against Bugzilla's
user list.

## How it works

- `Extension.pm`
  - `object_validators` — plugs a validator into `Bugzilla::Bug` for
    each field in `USER_FIELDS`. It resolves the typed value to an
    existing account via `Bugzilla::User->check()` and normalizes it to
    the canonical login name, or throws Bugzilla's standard "no such
    user" error.
  - `template_before_process` — when `bug/field.html.tmpl` is about to
    render, it hands it the list of field names to treat specially.
- `template/en/default/hook/bug/field-end_field_column.html.tmpl` —
  Bugzilla's stock `bug/field.html.tmpl` already calls
  `Hook.process('end_field_column')` after rendering each field. For
  fields in `USER_FIELDS`, this hook template loads
  `web/js/userfield.js` once per page and calls
  `UserFieldAutocomplete.init(fieldName)` for that field.
- `web/js/userfield.js` — a small, dependency-free autocomplete widget.
  It does **not** use Bugzilla's built-in YUI-based
  `YAHOO.bugzilla.userAutocomplete` (`js/field.js`) — some installs
  don't load that on every page the way stock Bugzilla does, so this
  extension is fully self-contained instead. It calls `jsonrpc.cgi`
  directly via `fetch()`, `POST`ing a `User.get` request with
  `{match: [query]}`. It must be `POST`, not `GET` — Bugzilla's
  JSON-RPC server intentionally rejects cookie-based login on `GET`
  requests (to stop cross-site data leaks via JSONP), so `POST` with
  `credentials: 'same-origin'` is what lets it authenticate using the
  browser's existing Bugzilla session cookie.

Everything here was checked against Bugzilla 5.2's actual source
(`Bugzilla/Object.pm`, `Bugzilla/Bug.pm`,
`template/en/default/bug/field.html.tmpl`,
`Bugzilla/WebService/User.pm`, `Bugzilla/WebService/Server/JSONRPC.pm`,
`Bugzilla/Auth/Login/Cookie.pm`), not guessed from memory.

## Limitations / things to extend yourself

- **One login per field**, like Assignee/QA Contact — not a multi-user
  list like CC. Look at the `multiple` handling in
  `global/userselect.html.tmpl` and `YAHOO.bugzilla.userAutocomplete.init`
  if you need that.
- **No group restriction** — any Bugzilla account can be entered. To
  restrict to a group, add a check in `_check_user_field` in
  `Extension.pm`:
  ```perl
  my $user = Bugzilla::User->check($value);
  $user->in_group('your_group')
    or ThrowUserError('userfield_not_in_group', {field => $field});
  return $user->login;
  ```
- **Read-only display** just shows the raw login string, not "Real Name
  <email>" the way Assignee does. Cosmetic only.
- **Field list lives in code**, not an admin-configurable parameter. If
  you want admins to add/remove user-fields without editing Perl, wrap
  `USER_FIELDS` in a proper Bugzilla Parameter via the
  `config_add_panels` hook instead.
- No special handling was added for the Advanced Search form — the
  field is searchable as plain text, not with the "is one of my bugs"
  style operators the built-in user fields get.

## Compatibility

Verified against Bugzilla 5.2 (the current stable branch as of writing).
The hooks used (`object_validators`, `template_before_process`, and the
`end_field_column` template hook point in `bug/field.html.tmpl`) have
existed for many major versions and are documented, stable extension
APIs — but if you're on a much older Bugzilla (4.x or earlier), diff
your copy of `template/en/default/bug/field.html.tmpl` against this
version's to confirm the `Hook.process('end_field_column')` call is
present before relying on this.
