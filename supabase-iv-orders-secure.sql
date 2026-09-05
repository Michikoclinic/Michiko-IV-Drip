create table if not exists public.iv_orders (
  order_id text primary key,
  lookup_token text not null,
  order_data jsonb not null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.iv_orders
  add column if not exists lookup_token text,
  add column if not exists order_data jsonb,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists created_at timestamptz not null default now();

alter table public.iv_orders enable row level security;

revoke all on table public.iv_orders from anon;
revoke all on table public.iv_orders from authenticated;

create or replace function public.save_iv_order(
  p_order_id text,
  p_lookup_token text,
  p_order_data jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(trim(p_order_id), '') = '' then
    raise exception 'order_id is required';
  end if;

  if coalesce(trim(p_lookup_token), '') = '' then
    raise exception 'lookup_token is required';
  end if;

  insert into public.iv_orders (order_id, lookup_token, order_data, updated_at)
  values (p_order_id, p_lookup_token, p_order_data, now())
  on conflict (order_id) do update
    set order_data = excluded.order_data,
        updated_at = now()
    where public.iv_orders.lookup_token = excluded.lookup_token;

  if not found then
    raise exception 'invalid lookup token for order_id %', p_order_id;
  end if;
end;
$$;

create or replace function public.get_iv_order(
  p_order_id text,
  p_lookup_token text
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select order_data
  from public.iv_orders
  where order_id = p_order_id
    and lookup_token = p_lookup_token
  limit 1;
$$;

revoke all on function public.save_iv_order(text, text, jsonb) from public;
revoke all on function public.get_iv_order(text, text) from public;
grant execute on function public.save_iv_order(text, text, jsonb) to anon;
grant execute on function public.get_iv_order(text, text) to anon;
