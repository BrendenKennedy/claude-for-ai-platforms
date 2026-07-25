---
name: caching-and-queues
description: >
  Caches, queues, and streams — Redis, Kafka, SQS/Pub-Sub — and the delivery semantics you actually
  get. Carries: cache invalidation and the stampede, TTL discipline, cache-aside vs write-through,
  **idempotency keys because at-least-once is the real guarantee and "exactly-once" is mostly
  marketing**, dead-letter queues and the poison-message loop, consumer groups, partition keys and
  what ordering really promises, backpressure and why unbounded queues just move the failure, and
  why a queue in front of an LLM call is usually right. Load when adding a cache, choosing a
  broker, designing an async workflow, or debugging duplicate/lost/stuck messages. Triggers: redis,
  memcached, cache, cache invalidation, TTL, stampede, kafka, rabbitmq, SQS, pubsub, celery, queue,
  message broker, consumer group, partition, offset, dead letter queue, DLQ, idempotency, exactly
  once, at least once, backpressure, retry, duplicate messages, stuck queue, event streaming.
  Timeouts and circuit breakers are `reliability-sre` R4; agent budget caps are `ai-security.md` AI9.
---

# caching-and-queues — the guarantees you get, not the ones on the box

**Pinned:** redis, kafka, celery — unpinned · authored 2026-07 · run `/skill-update
caching-and-queues` once a broker is chosen.

> On-demand: load this when work becomes asynchronous or a read becomes expensive. Timeouts, retries
> with backoff, and circuit breakers on the *calling* side are `reliability-sre` (`R4`); per-run
> token/cost/depth caps for agents are canon (`ai-security.md` `AI9`); scheduled DAGs are
> `workflow-orchestration`. Network posture and credentials for these stores are `platform-security.md`
> `P11` — Redis in particular ships with no authentication and is the single most-exposed data store
> on the internet.

## When this applies

Adding a cache. Choosing a broker. Designing an async workflow. Debugging duplicate, lost, or stuck
messages.

## Caching

**Cache when the read is expensive and staleness is acceptable — and be explicit about how stale.**
"It's cached" without a stated staleness budget is a correctness decision made by accident.

| Pattern | How | Use when |
|---|---|---|
| **Cache-aside** | App checks cache, misses, loads, writes back | Default. Simple, resilient to cache loss |
| **Write-through** | Write goes to cache and store together | Reads must be fresh immediately |
| **Write-behind** | Write to cache, flush later | High write volume, tolerant of loss. Risky |

**The stampede is the failure that takes a service down.** A popular key expires, a thousand
concurrent requests all miss, and all thousand hit the database at once. Defences:

- **Jittered TTLs** — never expire a whole class of keys at the same instant.
- **A lock on recompute** — one request rebuilds; the rest wait briefly or serve stale.
- **Early/probabilistic refresh** — recompute *before* expiry, with probability rising as the TTL
  approaches, so the refresh is spread out.

**Invalidation** is the hard part and worth choosing deliberately: TTL-only (simple, always somewhat
stale), explicit invalidation on write (fresh, easy to miss a path), or **versioned keys** —
`user:42:v7` — where a version bump makes every old key unreachable and it expires on its own. The
last is usually the most robust because there is no invalidation call to forget.

**For LLM systems specifically:** cache embeddings (deterministic per model+text — a large,
easy win), and cache completions on an exact prompt hash *only* if `temperature=0` and the prompt
carries no per-user data. **Never cache across a tenant boundary** (`data-governance.md` `D8`) — a
cache key that omits the tenant is a cross-tenant data leak with excellent latency.

## Delivery semantics — get this right and most bugs disappear

| Guarantee | Reality |
|---|---|
| At-most-once | Fire and forget. Messages are lost |
| **At-least-once** | **What you actually get.** Duplicates happen |
| Exactly-once | Not achievable end-to-end across systems. Where a broker claims it, it means *within its own boundary* under specific configuration — the moment your consumer touches an external system, it's at-least-once again |

**So: make consumers idempotent.** This is the single most valuable thing in this skill.

```python
def handle(msg):
    key = msg.idempotency_key           # producer-supplied, stable across retries
    # Atomic claim — SET NX returns false if this key was already handled
    if not redis.set(f"processed:{key}", "1", nx=True, ex=86_400):
        return                          # already done; ack and move on
    try:
        do_the_work(msg)
    except Exception:
        redis.delete(f"processed:{key}")  # let a retry happen
        raise
```

Or, better where the work is a database write: make the *write itself* idempotent —
`INSERT ... ON CONFLICT DO NOTHING` on a natural key. Then duplicates are free and you need no
separate ledger.

**Ack only after the work is done**, never on receipt. Acking on receipt converts at-least-once into
at-most-once and loses messages on crash.

## Queues and brokers

| | Redis (Streams/Lists) | Kafka | SQS / Pub-Sub |
|---|---|---|---|
| Model | In-memory, optional persistence | Durable log, replayable | Managed queue |
| Strength | Simple, fast, already there | Replay, high throughput, multiple independent consumers | No ops, scales itself |
| Ordering | Per-stream | Per-partition | FIFO queues only, with throughput limits |
| Pick when | Modest scale, Redis already present | Event streaming, replay matters, many consumers | You're on that cloud and want no operational burden |

**Ordering is narrower than people assume.** Kafka orders *within a partition*, and the partition
key decides which. Order by entity — user id, conversation id — so related messages land together;
a random key means no useful ordering at all. Global ordering means one partition, which means no
parallelism.

**Dead-letter queues, and the poison-message loop.** A message that always fails will be retried
forever, blocking the partition or consuming the whole worker pool. Set `maxReceiveCount`, route to
a DLQ, and — this is the part that gets skipped — **alert on DLQ depth and actually read it**. A DLQ
nobody monitors is a silent data-loss queue.

**Backpressure.** An unbounded queue does not absorb overload, it *hides* it: the queue grows,
latency grows without bound, and the system fails later and worse. Bound the queue and reject or
shed when full (`reliability-sre` `R5`) — a fast, clear failure beats an unbounded wait.

## Queues in front of LLM calls

Usually the right shape, for reasons that are specific to this workload:

- Generations take seconds to minutes — far longer than a comfortable HTTP request.
- Provider rate limits are real; a queue lets you smooth against them instead of failing.
- Retries with backoff belong on the consumer side (`R4`), not in a user's browser.
- It gives you one place to enforce the concurrency and cost caps `ai-security.md` `AI9` requires.

Watch two things: **never hold a database connection across the generation** (`relational-stores` —
it exhausts the pool), and give the user a real status channel rather than a spinner over a queue
they can't see.

## Gotchas

- **Redis with no authentication, reachable from anywhere.** Canon `P11`. This is the most reliably
  exploited data-store misconfiguration there is; it is found by internet-wide scanning within hours.
- **Redis as a cache and as a queue and as a lock and as the session store**, one instance, no
  eviction policy — then `maxmemory` evicts your queue. Separate the concerns, or at least the
  databases, and set an eviction policy that matches each use (`noeviction` for queues).
- **Cache key without the tenant.** A cross-tenant leak that looks like good performance (`D8`).
- **Caching a non-deterministic completion.** With `temperature > 0` you're caching one sample and
  serving it as though it were the distribution.
- **Acking before the work completes.** Loses messages on crash.
- **No DLQ, or a DLQ nobody reads.**
- **Assuming the broker's "exactly-once" covers your side effects.** It doesn't.
- **Unbounded queue growth treated as resilience.** It's deferred failure with worse symptoms.
