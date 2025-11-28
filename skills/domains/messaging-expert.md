---
name: messaging-expert
description: Message queues and event streaming expert. Keywords: kafka, rabbitmq, redis-streams, pubsub, event-driven, async, queues, messaging
---

# MESSAGING EXPERT

**Persona:** Viktor Petrov, Distributed Systems Engineer specializing in high-throughput event architectures

---

## CORE PRINCIPLES

### 1. Async by Default
Use messaging for anything that doesn't need immediate response. Decouple producers from consumers.

### 2. Idempotency is Non-Negotiable
Messages can be delivered multiple times. Design consumers to handle duplicates safely.

### 3. Dead Letter Queues Save Lives
Always have a place for failed messages. Monitor and alert on DLQ growth.

### 4. Ordering Matters (Sometimes)
Know when order matters and partition accordingly. Don't assume global ordering.

### 5. Backpressure is Your Friend
Design systems to handle slow consumers gracefully. Don't let queues grow unbounded.

---

## QUALITY CHECKLIST

### Critical (MUST)
- [ ] Idempotent message handlers
- [ ] Dead letter queue configured
- [ ] Message acknowledgment after processing
- [ ] Retry logic with exponential backoff
- [ ] Monitoring on queue depth
- [ ] Graceful shutdown (finish current message)

### Important (SHOULD)
- [ ] Message schema versioning
- [ ] Consumer lag alerting
- [ ] Message tracing/correlation IDs
- [ ] Circuit breaker for downstream calls
- [ ] Batch processing where appropriate

---

## CODE PATTERNS

### Recommended: Kafka Producer (TypeScript)
```typescript
import { Kafka, Producer, CompressionTypes } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'my-service',
  brokers: ['kafka-1:9092', 'kafka-2:9092'],
});

const producer = kafka.producer({
  allowAutoTopicCreation: false,
  transactionTimeout: 30000,
});

async function publishEvent<T>(topic: string, key: string, event: T): Promise<void> {
  await producer.send({
    topic,
    compression: CompressionTypes.GZIP,
    messages: [{
      key,  // Ensures ordering for same key
      value: JSON.stringify({
        id: crypto.randomUUID(),
        timestamp: Date.now(),
        data: event,
      }),
      headers: {
        'correlation-id': getCorrelationId(),
        'source': 'my-service',
      },
    }],
  });
}

// Good: Batch publishing
async function publishBatch<T>(topic: string, events: Array<{ key: string; data: T }>) {
  await producer.send({
    topic,
    compression: CompressionTypes.GZIP,
    messages: events.map(e => ({
      key: e.key,
      value: JSON.stringify({
        id: crypto.randomUUID(),
        timestamp: Date.now(),
        data: e.data,
      }),
    })),
  });
}
```

### Recommended: Kafka Consumer with Idempotency
```typescript
import { Kafka, Consumer, EachMessagePayload } from 'kafkajs';

const consumer = kafka.consumer({
  groupId: 'my-consumer-group',
  sessionTimeout: 30000,
  heartbeatInterval: 3000,
});

// Idempotency store (Redis or DB)
const processedMessages = new Set<string>();

async function handleMessage({ topic, partition, message }: EachMessagePayload) {
  const messageId = message.headers?.['message-id']?.toString();

  // Idempotency check
  if (messageId && await isProcessed(messageId)) {
    console.log(`Skipping duplicate message: ${messageId}`);
    return;
  }

  try {
    const event = JSON.parse(message.value!.toString());

    // Process the event
    await processEvent(event);

    // Mark as processed
    if (messageId) {
      await markProcessed(messageId);
    }
  } catch (error) {
    // Don't commit offset, message will be redelivered
    throw error;
  }
}

await consumer.subscribe({ topic: 'events', fromBeginning: false });
await consumer.run({
  eachMessage: handleMessage,
  autoCommit: true,
  autoCommitInterval: 5000,
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  await consumer.disconnect();
  process.exit(0);
});
```

### Recommended: RabbitMQ with DLQ
```typescript
import amqp from 'amqplib';

async function setupQueues(channel: amqp.Channel) {
  // Dead letter exchange
  await channel.assertExchange('dlx', 'direct', { durable: true });
  await channel.assertQueue('dead-letter-queue', { durable: true });
  await channel.bindQueue('dead-letter-queue', 'dlx', 'failed');

  // Main queue with DLQ
  await channel.assertQueue('orders', {
    durable: true,
    arguments: {
      'x-dead-letter-exchange': 'dlx',
      'x-dead-letter-routing-key': 'failed',
      'x-message-ttl': 86400000,  // 24 hours
    },
  });
}

async function consumeWithRetry(channel: amqp.Channel) {
  await channel.consume('orders', async (msg) => {
    if (!msg) return;

    const retryCount = (msg.properties.headers?.['x-retry-count'] || 0) as number;

    try {
      const order = JSON.parse(msg.content.toString());
      await processOrder(order);
      channel.ack(msg);
    } catch (error) {
      if (retryCount < 3) {
        // Retry with backoff
        const delay = Math.pow(2, retryCount) * 1000;
        setTimeout(() => {
          channel.publish('', 'orders', msg.content, {
            headers: { 'x-retry-count': retryCount + 1 },
          });
          channel.ack(msg);
        }, delay);
      } else {
        // Send to DLQ
        channel.nack(msg, false, false);
      }
    }
  });
}
```

### Recommended: Event Schema Versioning
```typescript
// Good: Versioned event schemas
interface EventEnvelope<T> {
  id: string;
  version: string;  // Schema version
  type: string;
  timestamp: number;
  source: string;
  correlationId?: string;
  data: T;
}

// Version handlers
const handlers: Record<string, (data: unknown) => OrderCreated> = {
  '1.0': (data) => data as OrderCreatedV1,
  '2.0': (data) => {
    const v2 = data as OrderCreatedV2;
    return { ...v2, items: v2.lineItems };  // Transform to current schema
  },
};

function parseEvent(raw: string): OrderCreated {
  const envelope = JSON.parse(raw) as EventEnvelope<unknown>;
  const handler = handlers[envelope.version];
  if (!handler) throw new Error(`Unknown version: ${envelope.version}`);
  return handler(envelope.data);
}
```

### Avoid: Common Anti-patterns
```typescript
// Bad: No idempotency
async function handleOrderCreated(order: Order) {
  await chargeCustomer(order.customerId, order.total);  // Charges multiple times on retry!
}

// Good: Idempotent with deduplication
async function handleOrderCreated(order: Order) {
  const paymentId = `order-${order.id}`;  // Idempotency key
  await chargeCustomer(order.customerId, order.total, paymentId);
}

// Bad: Sync call in message handler
async function handleEvent(event: Event) {
  const result = await fetch('https://slow-api.com/process', {...});  // Blocks consumer!
}

// Good: Fire and forget, or use separate queue
async function handleEvent(event: Event) {
  await publishToQueue('api-calls', { url: '...', body: event });  // Async processing
}

// Bad: No backpressure
while (true) {
  const messages = await fetchMessages(1000);
  messages.forEach(m => processSync(m));  // Memory explosion
}

// Good: Controlled concurrency
await consumer.run({
  eachMessage: handleMessage,
  partitionsConsumedConcurrently: 3,  // Limit parallelism
});
```

---

## COMMON MISTAKES

### 1. Not Handling Poison Messages
**Why bad:** One bad message blocks entire queue
**Fix:** Retry limit + DLQ

```typescript
// Good: Poison message handling
if (retryCount > MAX_RETRIES) {
  logger.error('Poison message detected', { messageId, error });
  await publishToDLQ(message);
  return;  // Don't block queue
}
```

### 2. Losing Messages on Crash
**Why bad:** Data loss
**Fix:** Acknowledge only after processing

```typescript
// Bad: Ack before processing
channel.ack(msg);
await processMessage(msg);  // Crash here = lost message

// Good: Ack after processing
await processMessage(msg);
channel.ack(msg);
```

### 3. Unbounded Queue Growth
**Why bad:** Memory exhaustion, increasing latency
**Fix:** Backpressure, TTL, monitoring

```typescript
// Good: Queue limits in RabbitMQ
await channel.assertQueue('tasks', {
  arguments: {
    'x-max-length': 10000,
    'x-overflow': 'reject-publish',  // Or 'drop-head'
  },
});
```

### 4. No Consumer Lag Monitoring
**Why bad:** Silent backlog growth
**Fix:** Monitor and alert

```typescript
// Kafka consumer lag check
const admin = kafka.admin();
const offsets = await admin.fetchOffsets({ groupId: 'my-group', topics: ['events'] });
// Compare with latest offsets and alert if lag > threshold
```

---

## DECISION TREE

```
Choosing a messaging system:
├── Need exactly-once semantics? → Kafka with transactions
├── Complex routing patterns? → RabbitMQ
├── Simple pub/sub? → Redis Pub/Sub
├── Persistent streams? → Kafka or Redis Streams
├── Cloud-native? → AWS SQS/SNS, GCP Pub/Sub
└── Low latency, high throughput? → Kafka or NATS

Message acknowledgment:
├── Processing idempotent? → Auto-commit is OK
├── Processing has side effects? → Manual ack after completion
├── Need exactly-once? → Use transactions
└── Batch processing? → Ack after batch completes

Partitioning strategy:
├── Need ordering per entity? → Partition by entity ID
├── Need global ordering? → Single partition (limits throughput)
├── Load balancing priority? → Round-robin (no key)
└── Geographic locality? → Partition by region
```

---

## MONITORING CHECKLIST

```
Queue Health:
□ Queue depth (messages waiting)
□ Consumer lag (Kafka)
□ Processing rate (messages/sec)
□ Error rate
□ DLQ size
□ Average processing time

Alerts to set up:
□ Queue depth > threshold for > 5 min
□ Consumer lag increasing
□ DLQ receiving messages
□ Consumer disconnected
□ Processing errors spike
□ Message age > TTL threshold
```

---

*Generated by NONSTOP Skill Creator*
