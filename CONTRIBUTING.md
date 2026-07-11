# Contributing

Keep behavior deterministic across supported MoonBit targets. Add black-box tests for every new public rule feature, document unsupported RFC 5545 clauses, and run the full command set in README before opening a pull request.

Do not add system-clock or timezone dependencies to the core package. Such behavior belongs in an explicitly optional adapter package with documented DST policy.
