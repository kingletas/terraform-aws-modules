# The conventions in CONTRIBUTING.md, as rules a machine decides.
#
# checkov and tflint judge the infrastructure these modules build. These rules
# judge the code: whether a module can be used twice, whether a plan stays
# stable when something is removed, and whether a value that looks like a
# credential is treated as one.
#
# Run with --combine, so a rule can read a variable's declared type in
# variables.tf and its use in main.tf as one input.
#
# Every rule here is silent on this repository today and has a fixture in
# tests/fixture proving it still refuses. A rule that has never been watched
# refuse decides nothing.

package terraform.conventions

files := input

module_file contains file if {
	some file in files
	startswith(file.path, "modules/")
}

declared_variable contains {"path": file.path, "name": name, "body": body} if {
	some file in files
	some name, bodies in object.get(file, ["contents", "variable"], {})
	some body in bodies
}

declared_block contains {"path": file.path, "kind": kind, "type": type, "name": name, "body": body} if {
	some file in files
	some kind in ["resource", "data"]
	some type, named in object.get(file, ["contents", kind], {})
	some name, bodies in named
	some body in bodies
}

provider_requirement contains {"path": file.path, "name": name, "spec": spec} if {
	some file in files
	some block in object.get(file, ["contents", "terraform"], [])
	some providers in object.get(block, "required_providers", [])
	some name, spec in providers
}

# --- a module may not carry a provider block ---

deny contains msg if {
	some file in module_file
	object.get(file, ["contents", "provider"], null) != null
	msg := sprintf("%s declares a provider block. A module with its own provider cannot be used twice in one configuration.", [file.path])
}

# --- every required provider states a version ---

deny contains msg if {
	some requirement in provider_requirement
	not requirement.spec.version
	msg := sprintf("%s requires the %s provider with no version constraint.", [requirement.path, requirement.name])
}

# --- a library says what it tolerates, so a module states a range ---

deny contains msg if {
	some requirement in provider_requirement
	startswith(requirement.path, "modules/")
	version := requirement.spec.version
	not contains(version, ">=")
	not contains(version, "~>")
	msg := sprintf("%s pins the %s provider to %q. A module says what it tolerates, so state a range.", [requirement.path, requirement.name, version])
}

# --- a collection is keyed by name, not by position ---
#
# The target is count set to a length, which makes one instance per element.
# The idiom `length(x) > 0 ? 1 : 0` is the opposite thing, a single optional
# resource, and is not flagged.

deny contains msg if {
	some block in declared_block
	expression := block.body.count
	startswith(expression, "${length(")
	not contains(expression, "?")
	msg := sprintf("%s: %s.%s.%s counts a length. count renumbers every element after a removal, which turns one deletion into a rebuild. Key a for_each by name instead.", [block.path, block.kind, block.type, block.name])
}

# --- a map is not keyed by the index of a list ---
#
# A key becomes a resource address once the map reaches a for_each, on the
# resource or through a module input, so `for index, cidr in local.cidrs :
# format("net%d", index) => ...` re-addresses every entry after a removal.
#
# The test is the iteration variable's name, which is how a list index is
# spelled; a comprehension over a map binds the key and is not flagged. The
# match stops at the first `=`, so the rule misses more than it invents.

index_name := ["index", "idx", "i", "position"]

keyed_by_index(expression) if {
	some name in index_name
	regex.match(sprintf(`for\s+%s\s*,\s*\w+\s+in\b[^=]*\b%s\b[^=]*=>`, [name, name]), expression)
}

deny contains msg if {
	some file in files
	walk(file.contents, [path, expression])
	is_string(expression)
	keyed_by_index(expression)
	where := concat(".", [part | some part in path; is_string(part)])
	msg := sprintf("%s: %s is keyed by the index of a list. A key becomes a resource address, and an index re-numbers every entry after a removal, so deleting one rebuilds the rest. Key by a name the caller chooses.", [file.path, where])
}

# --- existence is decided by a bool or an object, never by a null string ---

string_variable contains variable.name if {
	some variable in declared_variable
	object.get(variable, ["body", "type"], "") == "${string}"
}

deny contains msg if {
	some block in declared_block
	some name in string_variable
	contains(block.body.count, sprintf("var.%s == null", [name]))
	msg := sprintf("%s: %s.%s.%s decides whether it exists by whether the string var.%s is null. Terraform cannot know a value from another resource is non-null until apply, so this plan fails exactly when that value comes from the same plan. Use a bool, or an object whose nullness is known.", [block.path, block.kind, block.type, block.name, name])
}

# --- anything that looks like a credential is marked sensitive ---
#
# The name must end in a credential word and the variable must be a plain
# string. `manage_master_password` is a bool, `password_length` is a number and
# `write_private_key_to` is a path, and none of them carries a secret.

credential_word := ["password", "secret", "token", "private_key", "access_key", "api_key", "passphrase"]

deny contains msg if {
	some variable in declared_variable
	some word in credential_word
	endswith(variable.name, word)
	object.get(variable, ["body", "type"], "") == "${string}"
	object.get(variable, ["body", "sensitive"], false) != true
	msg := sprintf("%s: variable %q is not marked sensitive. An unmarked value is printed in plan output and in CI logs.", [variable.path, variable.name])
}

# --- every module declares its versions, inputs and outputs in the same places ---

module_dir contains dir if {
	some file in module_file
	parts := split(file.path, "/")
	dir := concat("/", array.slice(parts, 0, 2))
}

module_has(dir, name) if {
	some file in files
	file.path == sprintf("%s/%s", [dir, name])
}

deny contains msg if {
	some dir in module_dir
	some required in ["versions.tf", "variables.tf", "outputs.tf"]
	not module_has(dir, required)
	msg := sprintf("%s has no %s. Every module declares its versions, its inputs and its outputs in the same three places.", [dir, required])
}
