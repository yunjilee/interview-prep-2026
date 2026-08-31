# System Design Notes

## Core Concepts

### Latency

Latency generally increases as an operation moves farther from the current
process. Remote dependencies also introduce more variability and more ways for
a request to fail.

```text
Same process                 fastest
    |
Same machine / RAM
    |
Same-region Redis
    |
Same-region service
    |
Cross-region service
    |
External API                 slowest and most unpredictable
```

Typical orders of magnitude:

| Operation | Rough latency |
| --- | ---: |
| CPU / in-process memory lookup | ns–µs |
| Redis / cache in same region | ~0.2–2 ms |
| Simple indexed database query | ~1–10 ms |
| More complex database query | ~10–100+ ms |
| Service-to-service call in the same region | ~1–10 ms |
| Cross-region network call | ~50–200+ ms |
| External API call | ~50 ms–seconds |
| LLM inference | Hundreds of ms–many seconds |

These are rules of thumb, not guarantees. Payload size, network conditions,
query complexity, cache hit rate, load, and provider behavior can all change
the observed latency.

## Questions

