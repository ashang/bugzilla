# UserField — a Bugzilla extension for user-picker custom fields

Turns a "Free Text" custom field into a Bugzilla user picker: it's shown
as a `<select>` dropdown listing every Bugzilla user, exactly like
Assignee / QA Contact look when Administration → Parameters → User
Matching → `usemenuforusers` is switched on, and the value is validated
against Bugzilla's user list no matter how it was submitted (web UI,
`email_in.pl`, REST/XML-RPC).

It does **not** patch any core Bugzilla file — it only uses the extension
hook mechanism, so upgrading Bugzilla won't touch it.

## Why not a native "User" field type?

Stock Bugzilla's custom-field types are just: Bug ID, Large Text Box,
Free Text, Multiple-Selection Box, Drop Down, Date/Time. A native "User"
type has been requested since 2005 (Bugzilla Bug 287332) but has never
been merged — the patches that exist touch Bugzilla core files directly
and were never fully reviewed in. This extension gets the same practical
result — a field that only accepts real Bugzilla logins, shown as a
dropdown of users — without touching core files at all, by layering on
top of a plain Free Text field.

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

That's it — the field will now appear as a `<select>` dropdown on the
bug-creation page, the bug-edit page, and the bulk-edit ("show multiple
bugs") page, and any value saved (from the web UI, `email_in.pl`, or the
REST/XML-RPC API) is checked against Bugzilla's user list.

## How it works

- `Extension.pm`
  - `object_validators` — plugs a validator into `Bugzilla::Bug` for
    each field in `USER_FIELDS`. It resolves the submitted value to an
    existing account via `Bugzilla::User->check()` and normalizes it to
    the canonical login name, or throws Bugzilla's standard "no such
    user" error. This matters even though the dropdown itself only ever
    submits real logins — it's what keeps `email_in.pl` and the API
    honest.
  - `template_before_process` — when `bug/field.html.tmpl` is about to
    render, it hands it the list of field names to treat specially.
- `template/en/default/hook/bug/field-end_field_column.html.tmpl` —
  Bugzilla's stock `bug/field.html.tmpl` already calls
  `Hook.process('end_field_column')` after rendering each field. For
  fields in `USER_FIELDS`, this hook template prints a `<select>`
  populated from `user.get_userlist` — Bugzilla's own "every visible
  user" list, the exact same one Assignee/QA Contact use — and disables
  the plain `<input>` that was already rendered above it, so only the
  `<select>`'s value gets submitted.

Everything here was checked against Bugzilla 5.2's actual source
(`Bugzilla/Object.pm`, `Bugzilla/Bug.pm`,
`template/en/default/bug/field.html.tmpl`,
`template/en/default/global/userselect.html.tmpl`, `Bugzilla/User.pm`'s
`get_userlist`), not guessed from memory.

## Limitations / things to extend yourself

- **One login per field**, like Assignee/QA Contact — not a multi-user
  list like CC. A true multi-select would need `<select multiple>` in
  the hook template plus changing `_check_user_field` in `Extension.pm`
  to validate a list of logins instead of one.
- **No group restriction** — the dropdown lists every enabled account,
  same as Assignee/QA Contact (respecting `usevisibilitygroups` if
  that's on at your site). To restrict to a group, filter the list in
  the hook template and also check `$user->in_group('your_group')` in
  `_check_user_field` so the restriction holds for the API too. See the
  comment block at the top of `Extension.pm` for the exact spot.
- **Read-only display** just shows the raw login string, not "Real Name
  <email>" the way Assignee does. Cosmetic only.
- **Field list lives in code**, not an admin-configurable parameter. If
  you want admins to add/remove user-fields without editing Perl, wrap
  `USER_FIELDS` in a proper Bugzilla Parameter via the
  `config_add_panels` hook instead.
- If your user list is large, a single `<select>` with everyone in it
  gets unwieldy fast — there's no search-as-you-type in a plain
  dropdown. If that turns out to be a problem, an autocomplete text box
  (calling Bugzilla's JSON-RPC `User.get` as you type) is the better
  fit; that's a different implementation of the hook template, not
  covered by this version.

## Compatibility

Verified against Bugzilla 5.2 (the current stable branch as of writing).
The hooks used (`object_validators`, `template_before_process`, and the
`end_field_column` template hook point in `bug/field.html.tmpl`) have
existed for many major versions and are documented, stable extension
APIs — but if you're on a much older Bugzilla (4.x or earlier), diff
your copy of `template/en/default/bug/field.html.tmpl` against this
version's to confirm the `Hook.process('end_field_column')` call is
present before relying on this.
