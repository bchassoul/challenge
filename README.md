# Challenge

Elixir implementation for the CraftingSoftware HTTP job processing challenge.

See [docs/challenge-statement.pdf](docs/challenge-statement.pdf) for the original challenge prompt and sample payload.

## Requirements

- Elixir `~> 1.20`
- Erlang/OTP 29 or newer

## Architecture

See [docs/architecture.md](docs/architecture.md) for:

- Challenge summary.
- Proposed Elixir module boundaries.
- HTTP endpoint contracts.
- Validation and error handling strategy.
- Deterministic topological sorting approach.
- Test plan and implementation sequence.
