import { createClient } from 'npm:@supabase/supabase-js@2';
import webPush from 'npm:web-push@3.6.7';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const schedulerSecret = Deno.env.get('SCHEDULER_SECRET') ?? '';
const vapidPublicKey = Deno.env.get('VAPID_PUBLIC_KEY') ?? '';
const vapidPrivateKey = Deno.env.get('VAPID_PRIVATE_KEY') ?? '';
const vapidSubject = Deno.env.get('VAPID_SUBJECT') ?? 'mailto:admin@example.com';

const MAX_BATCHES = 50;
const BATCH_SIZE = 20;
const RETRYABLE_STATUSES = new Set([429, 500, 502, 503, 504]);

type Delivery = {
  id: string;
  user_id: string;
  reminder_id: string | null;
  subscription_id: string | null;
  local_date: string;
  scheduled_for: string;
  attempt: number;
  payload: { title: string; body: string; url: string };
  endpoint: string | null;
  p256dh: string | null;
  auth: string | null;
  reminder_ok: boolean;
  task_ok: boolean;
  task_done: boolean;
};

const supabase = createClient(supabaseUrl, supabaseServiceKey);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function statusCodeOf(error: unknown): number {
  const value = (error as { statusCode?: number } | null)?.statusCode;
  return typeof value === 'number' ? value : 0;
}

async function markResult(
  deliveryId: string,
  status: 'sent' | 'skipped' | 'failed',
  error?: string,
  permanent = false,
): Promise<void> {
  const { error: markError } = await supabase.rpc('reminder_mark_result', {
    p_delivery_id: deliveryId,
    p_status: status,
    p_error: error ?? null,
    p_permanent: permanent,
  });
  if (markError) {
    console.error('mark_result failed', deliveryId, markError.message);
  }
}

async function expireSubscription(subscriptionId: string | null): Promise<void> {
  if (!subscriptionId) return;
  const { error } = await supabase.rpc('reminder_expire_subscription', {
    p_subscription_id: subscriptionId,
  });
  if (error) {
    console.error('expire_subscription failed', subscriptionId, error.message);
  }
}

async function registerSuccess(subscriptionId: string | null): Promise<void> {
  if (!subscriptionId) return;
  const { error } = await supabase
    .from('push_subscriptions')
    .update({ last_success_at: new Date().toISOString(), failure_count: 0 })
    .eq('id', subscriptionId);
  if (error) {
    console.error('register_success failed', subscriptionId, error.message);
  }
}

async function registerFailure(subscriptionId: string | null): Promise<void> {
  if (!subscriptionId) return;
  const { data, error } = await supabase
    .from('push_subscriptions')
    .select('failure_count')
    .eq('id', subscriptionId)
    .maybeSingle();
  if (error || !data) return;
  await supabase
    .from('push_subscriptions')
    .update({ failure_count: (data.failure_count ?? 0) + 1 })
    .eq('id', subscriptionId);
}

async function processDelivery(delivery: Delivery): Promise<'sent' | 'skipped' | 'failed'> {
  if (!delivery.endpoint || !delivery.p256dh || !delivery.auth) {
    await expireSubscription(delivery.subscription_id);
    await markResult(delivery.id, 'skipped', 'subscription_expired', true);
    return 'skipped';
  }

  if (!delivery.reminder_ok || !delivery.task_ok) {
    await markResult(delivery.id, 'skipped', 'task_inactive_or_removed', true);
    return 'skipped';
  }

  if (delivery.task_done) {
    await markResult(delivery.id, 'skipped', 'task_completed_today', true);
    return 'skipped';
  }

  try {
    await webPush.sendNotification(
      {
        endpoint: delivery.endpoint,
        keys: { p256dh: delivery.p256dh, auth: delivery.auth },
      },
      JSON.stringify(delivery.payload),
      { TTL: 14400, urgency: 'high' },
    );
    await markResult(delivery.id, 'sent');
    await registerSuccess(delivery.subscription_id);
    return 'sent';
  } catch (error) {
    const status = statusCodeOf(error);
    const message = `web_push_${status || 'network'}: ${(error as Error)?.message ?? 'unknown'}`;

    if (status === 404 || status === 410) {
      await expireSubscription(delivery.subscription_id);
      await markResult(delivery.id, 'failed', message, true);
      return 'failed';
    }

    await registerFailure(delivery.subscription_id);

    if (status === 0 || RETRYABLE_STATUSES.has(status)) {
      await markResult(delivery.id, 'failed', message, false);
      return 'failed';
    }

    await markResult(delivery.id, 'failed', message, true);
    return 'failed';
  }
}

Deno.serve(async (request) => {
  if (!supabaseUrl || !supabaseServiceKey) {
    return json({ error: 'server_not_configured' }, 500);
  }
  if (!schedulerSecret || !vapidPublicKey || !vapidPrivateKey) {
    return json({ error: 'push_not_configured' }, 500);
  }

  const authHeader = request.headers.get('Authorization') ?? '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (token !== schedulerSecret && token !== supabaseServiceKey) {
    return json({ error: 'unauthorized' }, 401);
  }

  const workerId = `dispatch-${crypto.randomUUID().slice(0, 8)}`;

  webPush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

  const { data: enqueued, error: enqueueError } = await supabase.rpc(
    'reminder_enqueue_due',
  );
  if (enqueueError) {
    return json({ error: 'enqueue_failed', details: enqueueError.message }, 500);
  }

  let sent = 0;
  let skipped = 0;
  let failed = 0;

  for (let batchIndex = 0; batchIndex < MAX_BATCHES; batchIndex++) {
    const { data: batch, error: claimError } = await supabase.rpc(
      'reminder_claim_batch',
      { p_limit: BATCH_SIZE, p_worker: workerId },
    );
    if (claimError) {
      console.error('claim_failed', claimError.message);
      break;
    }
    if (!batch || batch.length === 0) {
      break;
    }

    for (const raw of batch as Delivery[]) {
      const result = await processDelivery(raw);
      if (result === 'sent') sent++;
      else if (result === 'skipped') skipped++;
      else failed++;
    }
  }

  return json({ enqueued: enqueued ?? 0, sent, skipped, failed });
});
