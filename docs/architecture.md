# Architecture

The assignment seems small in scope, so the architecture follows that lead. The goal is to keep the boundaries clear without turning a dependency-sorting exercise into a framework showcase.

At a high level, the service accepts a job, validates it, sorts the tasks by dependency, and returns either JSON or a bash script. It never runs the commands.

## Challenge Summary

A job has a list of tasks. Each task has:

- `name`: unique task name.
- `command`: shell command as a string.
- `requires`: optional list of task names that must run first.

The app needs to do three things:

- Put tasks in a valid dependency order.
- Render that same order as JSON or a bash script.
- Be easy to run, test, and review.

Commands are plain strings here. The app sorts and renders them; it does not interpret the shell.

## Design Goals

- Keep HTTP handling separate from validation, sorting, and rendering.
- Validate early and return predictable public errors.
- Keep output deterministic when more than one valid order exists.
- Use a light Elixir stack that is easy to run and review.
- Keep the important code straightforward enough to test directly.

## Stack

- `Plug` and `Cowboy` for HTTP.
- Elixir `JSON` for JSON encoding and decoding.
- `ExUnit` for tests.

Phoenix would be more framework than this needs. There is one endpoint, one workflow, and two response formats, so `Plug` keeps the moving parts visible.

## Request Flow

```text
HTTP request
  -> ChallengeWeb.Router
  -> ChallengeWeb.JobController
  -> Challenge.Jobs.OrderJob
  -> Challenge.Jobs.Validator
  -> Challenge.Jobs.DependencyGraph
  -> Challenge.Jobs.TopologicalSorter
  -> ChallengeWeb.ResponseEncoder or Challenge.Jobs.ScriptRenderer
HTTP response
```

The boundary is intentionally simple:

- `ChallengeWeb` handles HTTP concerns: routing, JSON decoding, content negotiation, status codes, and response bodies.
- `Challenge.Jobs` handles the job itself: validation, dependency sorting, errors, and bash rendering.

## HTTP API

The service exposes one endpoint:

```http
POST /jobs
```

The request body is the challenge JSON payload. The `Accept` header chooses the response format:

- `application/json` returns the ordered task list.
- `text/x-shellscript` returns a bash script.
- Missing `Accept` or `*/*` defaults to JSON.
- Unsupported response types return `406 not_acceptable`.

Unknown paths and unsupported methods return the same `404 not_found` JSON error envelope. The route exists only as far as the public API says it exists; the domain layer does not need to know about routing failures.

## Job Model

A task has:

- `name`: a unique task name.
- `command`: a shell command string.
- `requires`: optional list of task names that must come first.

Commands are treated as opaque strings. The service orders and renders them, but does not parse, escape, or execute them.

After validation, a `Challenge.Jobs.Job` has these guarantees:

- Task names are unique.
- Every dependency points to a task in the same job.
- Missing `requires` values have been normalized to `[]`.

## Validation

`Challenge.Jobs.Validator` turns decoded JSON into domain structs. It rejects malformed job data before graph construction starts.

Validation covers the important contract rules:

- The payload must contain a top-level `tasks` list.
- Each task must have a string `name` and string `command`.
- `requires`, when present, must be a list of strings.
- Unknown fields are rejected.
- Duplicate task names are rejected.
- Duplicate dependencies are rejected.
- Dependencies must refer to known task names.

Cycle detection stays in the sorter because it naturally falls out of dependency processing.

## Dependency Sorting

`Challenge.Jobs.TopologicalSorter` uses Kahn's algorithm. The graph tracks:

- `task_by_name`
- `in_degree`
- `dependents`
- `input_index`

`input_index` is what keeps the output deterministic. When several tasks are ready at the same time, the sorter chooses the task that appeared earliest in the original request. The ready set stores `{input_index, task_name}` pairs in Erlang/OTP `:gb_sets`, so tie-breaking is stable without adding another dependency.

That gives the API one predictable answer for any acyclic job:

- Dependencies always come before the tasks that require them.
- Independent or equally-ready tasks keep their original request order.
- Cycles return `dependency_cycle`.

For more detail on the sorting choice, see [dependency-sorting.md](dependency-sorting.md).

## Rendering

Both response formats use the same ordered task list.

The JSON response returns only the fields needed after sorting:

```json
{
  "tasks": [
    {
      "name": "task-1",
      "command": "touch /tmp/file1"
    }
  ]
}
```

The bash response keeps commands exactly as provided:

```bash
#!/usr/bin/env bash
touch /tmp/file1
```

The script renderer adds the shebang and a final newline. It does not shell-escape commands because each command is already a shell snippet from the request.

## Errors

Domain errors use a stable public shape:

```json
{
  "error": {
    "code": "invalid_payload",
    "message": "Invalid request payload",
    "details": {}
  }
}
```

Public error codes:

- `malformed_json`
- `invalid_payload`
- `duplicate_task_name`
- `duplicate_dependency`
- `unknown_dependency`
- `dependency_cycle`
- `not_acceptable`
- `not_found`

Responses should not expose stack traces, module names, raw exception messages, or internal graph details.

## Testing

Most tests should exercise the domain directly, because that is where the interesting behavior lives.

Core coverage:

- Validator accepts valid payloads and rejects bad ones with stable error codes.
- Sorter handles chains, branches, independent tasks, shared dependencies, and cycles.
- Sorter preserves original request order when more than one task is ready.
- Script rendering preserves command strings and includes the shebang.
- HTTP tests cover JSON output, shell output, content negotiation, malformed JSON, validation errors, and route errors.

The key invariant: for every ordered acyclic job, each dependency appears before the task that requires it.
