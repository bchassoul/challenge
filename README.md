# Challenge

Elixir implementation of the CraftingSoftware HTTP job processing challenge.

The service accepts a JSON job payload, validates task dependencies, returns a
deterministic dependency-safe task order, and can render that order as either
JSON or a bash script. It never executes the task commands.

See [docs/challenge-statement.md](docs/challenge-statement.md) for the copied
challenge prompt and sample payload. See [docs/architecture.md](docs/architecture.md)
for the implementation design.

## Requirements

- Elixir `~> 1.20`
- Erlang/OTP 27, 28, or 29

## Setup

Install dependencies:

```sh
mix deps.get
```

Run the test suite:

```sh
mix test
```

Start the HTTP service:

```sh
mix run --no-halt
```

The service listens on `http://localhost:4000`.

## API

```http
POST /jobs
```

Required request header:

```http
Content-Type: application/json
```

Response format is selected with `Accept`:

- `application/json`
- `text/x-shellscript`

Missing `Accept` or `Accept: */*` defaults to JSON.

## JSON Response

```sh
curl -s -X POST http://localhost:4000/jobs \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "{\"tasks\":[{\"name\":\"task-1\",\"command\":\"touch /tmp/file1\"},{\"name\":\"task-2\",\"command\":\"cat /tmp/file1\",\"requires\":[\"task-3\"]},{\"name\":\"task-3\",\"command\":\"echo 'Hello World!' > /tmp/file1\",\"requires\":[\"task-1\"]},{\"name\":\"task-4\",\"command\":\"rm /tmp/file1\",\"requires\":[\"task-2\",\"task-3\"]}]}" | jq
```

Expected response:

```json
{
  "tasks": [
    {
      "command": "touch /tmp/file1",
      "name": "task-1"
    },
    {
      "command": "echo 'Hello World!' > /tmp/file1",
      "name": "task-3"
    },
    {
      "command": "cat /tmp/file1",
      "name": "task-2"
    },
    {
      "command": "rm /tmp/file1",
      "name": "task-4"
    }
  ]
}
```

## Bash Response

```sh
curl -s -X POST http://localhost:4000/jobs \
  -H "Content-Type: application/json" \
  -H "Accept: text/x-shellscript" \
  --data "{\"tasks\":[{\"name\":\"task-1\",\"command\":\"touch /tmp/file1\"},{\"name\":\"task-2\",\"command\":\"cat /tmp/file1\",\"requires\":[\"task-3\"]},{\"name\":\"task-3\",\"command\":\"echo 'Hello World!' > /tmp/file1\",\"requires\":[\"task-1\"]},{\"name\":\"task-4\",\"command\":\"rm /tmp/file1\",\"requires\":[\"task-2\",\"task-3\"]}]}"
```

Expected response:

```bash
#!/usr/bin/env bash
touch /tmp/file1
echo 'Hello World!' > /tmp/file1
cat /tmp/file1
rm /tmp/file1
```

## Errors

Errors use a stable JSON envelope:

```json
{
  "error": {
    "code": "invalid_payload",
    "message": "Invalid request payload",
    "details": {}
  }
}
```

Important HTTP error cases:

- `400 malformed_json`: request body is not valid JSON.
- `406 not_acceptable`: requested response format is not supported.
- `415 unsupported_media_type`: request `Content-Type` is missing or not JSON.
- `422 invalid_payload`: JSON is valid, but the job payload is invalid.
- `422 dependency_cycle`: dependencies contain a cycle.

Example invalid payload:

```sh
curl -s -X POST http://localhost:4000/jobs \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "{\"tasks\":\"not-a-list\"}" | jq
```

Expected response:

```json
{
  "error": {
    "code": "invalid_payload",
    "details": {
      "path": "$.tasks"
    },
    "message": "Field must be a list."
  }
}
```
