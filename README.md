# Challenge

An Elixir implementation of the CraftingSoftware challenge.

See [docs/challenge-statement.md](docs/challenge-statement.md) for the
challenge details, and [docs/architecture.md](docs/architecture.md)
for the implementation design.

The service accepts a JSON job payload, validates task dependencies, returns a
deterministic topological order, and can render that order as either JSON or a
bash script. It never executes the task commands.

## Requirements

- Elixir `~> 1.20`
- Erlang/OTP 29

## Quick Start

```sh
mix deps.get
mix test
mix run --no-halt
```

The service listens on `http://localhost:4000`.

Once the app is running, try the examples below with `curl` or your preferred
HTTP client.

## Test the API

The service exposes one endpoint:

```http
POST /jobs
```

Required request header:

```http
Content-Type: application/json
```

The response format is selected with `Accept`:

- `application/json`
- `text/x-shellscript`

Missing `Accept` or `Accept: */*` defaults to JSON. Successful JSON responses
contain ordered tasks.

### Success

#### 1. JSON Response

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

#### 2. Bash Script Response

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

### Errors

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

| Status | Error Code | Meaning |
| --- | --- | --- |
| `400 Bad Request` | `malformed_json` | Request body is not valid JSON. |
| `404 Not Found` | `not_found` | Route or method is not supported. |
| `406 Not Acceptable` | `not_acceptable` | Requested response format is not supported. |
| `415 Unsupported Media Type` | `unsupported_media_type` | Request `Content-Type` is missing or not JSON. |
| `422 Unprocessable Content` | `invalid_payload` | JSON is valid, but the job payload is invalid. |
| `422 Unprocessable Content` | `duplicate_task_name` | More than one task has the same name. |
| `422 Unprocessable Content` | `duplicate_dependency` | A task repeats the same dependency. |
| `422 Unprocessable Content` | `unknown_dependency` | A task requires a name not present in the job. |
| `422 Unprocessable Content` | `dependency_cycle` | Dependencies contain a cycle. |

#### Error Examples

The examples below use `curl -i` so the HTTP status is visible.

##### 1. `not_found`

```sh
curl -i http://localhost:4000/missing
```

Returns `404 Not Found` with error code `not_found`.

##### 2. `malformed_json`

```sh
curl -i -X POST http://localhost:4000/jobs \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "{\"tasks\":"
```

Returns `400 Bad Request` with error code `malformed_json`.

##### 3. `not_acceptable`

```sh
curl -i -X POST http://localhost:4000/jobs \
  -H "Content-Type: application/json" \
  -H "Accept: text/plain" \
  --data "{\"tasks\":[]}"
```

Returns `406 Not Acceptable` with error code `not_acceptable`.

##### 4. `unsupported_media_type`

```sh
curl -i -X POST http://localhost:4000/jobs \
  -H "Content-Type: text/plain" \
  -H "Accept: application/json" \
  --data "{\"tasks\":[]}"
```

Returns `415 Unsupported Media Type` with error code `unsupported_media_type`.

##### 5. `invalid_payload`

```sh
curl -i -X POST http://localhost:4000/jobs \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "{\"tasks\":\"not-a-list\"}"
```

Returns `422 Unprocessable Content` with error code `invalid_payload`.

##### 6. `duplicate_task_name`

```sh
curl -i -X POST http://localhost:4000/jobs \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "{\"tasks\":[{\"name\":\"task-1\",\"command\":\"echo one\"},{\"name\":\"task-1\",\"command\":\"echo two\"}]}"
```

Returns `422 Unprocessable Content` with error code `duplicate_task_name`.

##### 7. `duplicate_dependency`

```sh
curl -i -X POST http://localhost:4000/jobs \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "{\"tasks\":[{\"name\":\"task-1\",\"command\":\"echo one\"},{\"name\":\"task-2\",\"command\":\"echo two\",\"requires\":[\"task-1\",\"task-1\"]}]}"
```

Returns `422 Unprocessable Content` with error code `duplicate_dependency`.

##### 8. `unknown_dependency`

```sh
curl -i -X POST http://localhost:4000/jobs \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "{\"tasks\":[{\"name\":\"task-1\",\"command\":\"echo one\",\"requires\":[\"missing-task\"]}]}"
```

Returns `422 Unprocessable Content` with error code `unknown_dependency`.

##### 9. `dependency_cycle`

```sh
curl -i -X POST http://localhost:4000/jobs \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  --data "{\"tasks\":[{\"name\":\"task-1\",\"command\":\"echo one\",\"requires\":[\"task-2\"]},{\"name\":\"task-2\",\"command\":\"echo two\",\"requires\":[\"task-1\"]}]}"
```

Returns `422 Unprocessable Content` with error code `dependency_cycle`.
