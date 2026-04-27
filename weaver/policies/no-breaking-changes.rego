# Weaver policy — no breaking changes to stable attributes.
# Referenced by weaver registry diff via --policy.
#
# Rules enforced:
#   1. A stable attribute MUST NOT be removed without first being marked deprecated.
#   2. A stable attribute's type MUST NOT change.
#   3. A stable attribute's requirement_level MUST NOT increase (e.g. recommended -> required).
#   4. Renames are not a first-class concept — they appear as remove+add, which rule #1 catches.
#      Fix: keep the old attribute with `deprecated`, add the new one, emit both for one release.

package weaver.policies.schema

default allow := true

# Rule 1: removal of a stable attribute is a breaking change unless it was previously deprecated.
deny[msg] {
  some change
  change := input.changes[_]
  change.kind == "attribute_removed"
  change.previous.stability == "stable"
  not change.previous.deprecated
  msg := sprintf(
    "breaking change: stable attribute `%s` removed from group `%s`. Mark deprecated for one release cycle before removing.",
    [change.previous.id, change.group_id]
  )
}

# Rule 2: type change on a stable attribute is always breaking.
deny[msg] {
  some change
  change := input.changes[_]
  change.kind == "attribute_type_changed"
  change.previous.stability == "stable"
  msg := sprintf(
    "breaking change: type of stable attribute `%s` changed from `%v` to `%v`. Introduce a new attribute instead.",
    [change.previous.id, change.previous.type, change.current.type]
  )
}

# Rule 3: requirement_level can only weaken on stable attrs (required -> recommended allowed; reverse is breaking).
deny[msg] {
  some change
  change := input.changes[_]
  change.kind == "attribute_requirement_level_changed"
  change.previous.stability == "stable"
  change.previous.requirement_level == "recommended"
  change.current.requirement_level == "required"
  msg := sprintf(
    "breaking change: attribute `%s` tightened from recommended to required. Provide a deprecation notice and let consumers opt in.",
    [change.previous.id]
  )
}
