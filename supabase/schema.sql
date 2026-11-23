-- QuickParking Supabase schema
-- Run this entire file once in Supabase Dashboard > SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default 'Customer',
  email text not null default '',
  phone text not null default '',
  role text not null default 'customer' check (role = 'customer'),
  profile_image_url text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.admins (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default 'Admin',
  email text not null default '',
  phone text not null default '',
  role text not null default 'admin' check (role = 'admin'),
  profile_image_url text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.parking_locations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text not null,
  city text not null,
  description text not null default '',
  contact_number text not null default '',
  base_rate numeric(10, 2) not null default 0 check (base_rate >= 0),
  total_slots integer not null default 0 check (total_slots >= 0),
  available_slots integer not null default 0 check (available_slots >= 0),
  opening_hours text not null default '24/7',
  image_url text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.parking_slots (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references public.parking_locations(id) on delete cascade,
  slot_number text not null,
  floor text not null default 'Ground',
  type text not null default 'paid' check (type in ('free', 'paid')),
  status text not null default 'available' check (status in ('available', 'occupied', 'reserved')),
  vehicle_type text not null default 'Car' check (vehicle_type in ('Car', 'Bike', 'EV')),
  rate_per_hour numeric(10, 2) not null default 0 check (rate_per_hour >= 0),
  current_booking_id uuid,
  created_at timestamptz not null default now(),
  unique (location_id, slot_number)
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  booking_code text not null unique,
  user_id uuid not null references auth.users(id) on delete cascade,
  location_id uuid not null references public.parking_locations(id) on delete restrict,
  location_name text not null,
  slot_id uuid not null references public.parking_slots(id) on delete restrict,
  slot_number text not null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  duration_hours integer not null check (duration_hours between 1 and 24),
  status text not null default 'reserved' check (
    status in ('reserved', 'confirmed', 'active', 'completed', 'cancelled')
  ),
  amount numeric(10, 2) not null default 0 check (amount >= 0),
  payment_status text not null default 'pending' check (payment_status in ('pending', 'paid', 'failed', 'refunded')),
  qr_payload text not null,
  vehicle_number text not null,
  created_at timestamptz not null default now(),
  checked_in_at timestamptz,
  checked_out_at timestamptz
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric(10, 2) not null check (amount >= 0),
  method text not null default 'UPI',
  status text not null default 'success' check (status in ('success', 'failed', 'refunded')),
  paid_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  message text not null,
  type text not null default 'general',
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.complaints (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  message text not null,
  status text not null default 'open' check (status in ('open', 'in_progress', 'resolved', 'closed')),
  created_at timestamptz not null default now()
);

create index if not exists parking_slots_location_idx on public.parking_slots(location_id, slot_number);
create index if not exists bookings_user_start_idx on public.bookings(user_id, start_time desc);
create index if not exists bookings_start_idx on public.bookings(start_time desc);
create index if not exists notifications_user_created_idx on public.notifications(user_id, created_at desc);
create index if not exists complaints_created_idx on public.complaints(created_at desc);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.users (id, name, email, phone)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'name', ''), 'Customer'),
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'phone', '')
  )
  on conflict (id) do update set
    name = excluded.name,
    email = excluded.email,
    phone = excluded.phone;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.remove_customer_profile_for_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.users where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_admin_profile_created on public.admins;
create trigger on_admin_profile_created
  after insert on public.admins
  for each row execute function public.remove_customer_profile_for_admin();

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admins where id = (select auth.uid())
  );
$$;

alter table public.users enable row level security;
alter table public.admins enable row level security;
alter table public.parking_locations enable row level security;
alter table public.parking_slots enable row level security;
alter table public.bookings enable row level security;
alter table public.payments enable row level security;
alter table public.notifications enable row level security;
alter table public.complaints enable row level security;

revoke all on table public.users, public.admins, public.parking_locations,
  public.parking_slots, public.bookings, public.payments,
  public.notifications, public.complaints from anon, authenticated;

grant select, update, delete on public.users to authenticated;
grant select, update, delete on public.admins to authenticated;
grant select, insert, update, delete on public.parking_locations to authenticated;
grant select, insert, update, delete on public.parking_slots to authenticated;
grant select, update on public.bookings to authenticated;
grant select on public.payments to authenticated;
grant select, update on public.notifications to authenticated;
grant select, insert, update on public.complaints to authenticated;

drop policy if exists users_select on public.users;
create policy users_select on public.users for select to authenticated
using ((select auth.uid()) = id or (select public.is_admin()));

drop policy if exists users_update on public.users;
create policy users_update on public.users for update to authenticated
using ((select auth.uid()) = id or (select public.is_admin()))
with check ((select auth.uid()) = id or (select public.is_admin()));

drop policy if exists users_delete on public.users;
create policy users_delete on public.users for delete to authenticated
using ((select public.is_admin()));

drop policy if exists admins_select on public.admins;
create policy admins_select on public.admins for select to authenticated
using ((select auth.uid()) = id or (select public.is_admin()));

drop policy if exists admins_update on public.admins;
create policy admins_update on public.admins for update to authenticated
using ((select auth.uid()) = id or (select public.is_admin()))
with check ((select auth.uid()) = id or (select public.is_admin()));

drop policy if exists admins_delete on public.admins;
create policy admins_delete on public.admins for delete to authenticated
using ((select public.is_admin()));

drop policy if exists locations_read on public.parking_locations;
create policy locations_read on public.parking_locations for select to authenticated
using (true);

drop policy if exists locations_admin_write on public.parking_locations;
create policy locations_admin_write on public.parking_locations for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists slots_read on public.parking_slots;
create policy slots_read on public.parking_slots for select to authenticated
using (true);

drop policy if exists slots_admin_write on public.parking_slots;
create policy slots_admin_write on public.parking_slots for all to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists bookings_read on public.bookings;
create policy bookings_read on public.bookings for select to authenticated
using ((select auth.uid()) = user_id or (select public.is_admin()));

drop policy if exists bookings_admin_update on public.bookings;
create policy bookings_admin_update on public.bookings for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

drop policy if exists payments_read on public.payments;
create policy payments_read on public.payments for select to authenticated
using ((select auth.uid()) = user_id or (select public.is_admin()));

drop policy if exists notifications_read on public.notifications;
create policy notifications_read on public.notifications for select to authenticated
using ((select auth.uid()) = user_id or (select public.is_admin()));

drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists complaints_read on public.complaints;
create policy complaints_read on public.complaints for select to authenticated
using ((select auth.uid()) = user_id or (select public.is_admin()));

drop policy if exists complaints_insert on public.complaints;
create policy complaints_insert on public.complaints for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists complaints_admin_update on public.complaints;
create policy complaints_admin_update on public.complaints for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

create or replace function public.create_booking(
  p_location_id uuid,
  p_slot_id uuid,
  p_start_time timestamptz,
  p_duration_hours integer,
  p_vehicle_number text
)
returns public.bookings
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_location public.parking_locations;
  v_slot public.parking_slots;
  v_booking public.bookings;
  v_booking_id uuid := gen_random_uuid();
  v_booking_code text;
  v_amount numeric(10, 2);
begin
  if v_user_id is null then
    raise exception 'Please log in before booking a slot.';
  end if;
  if p_duration_hours is null or p_duration_hours not between 1 and 24 then
    raise exception 'Duration must be between 1 and 24 hours.';
  end if;
  if coalesce(trim(p_vehicle_number), '') !~ '^[A-Za-z0-9]{10}$' then
    raise exception 'Vehicle number must contain exactly 10 letters and numbers.';
  end if;
  if p_start_time is null or p_start_time < now() - interval '1 minute' then
    raise exception 'Please select a future booking date and time.';
  end if;

  select * into v_location
  from public.parking_locations
  where id = p_location_id
  for update;
  if not found then
    raise exception 'Parking location not found.';
  end if;

  select * into v_slot
  from public.parking_slots
  where id = p_slot_id
  for update;
  if not found or v_slot.location_id <> p_location_id then
    raise exception 'Selected parking slot is invalid.';
  end if;
  if v_slot.status <> 'available' then
    raise exception 'Selected slot is no longer available.';
  end if;

  v_amount := case
    when v_slot.type = 'free' then 0
    when v_slot.rate_per_hour > 0 then v_slot.rate_per_hour * p_duration_hours
    else v_location.base_rate * p_duration_hours
  end;
  v_booking_code := 'QP' || upper(substr(replace(v_booking_id::text, '-', ''), 1, 8));

  insert into public.bookings (
    id, booking_code, user_id, location_id, location_name, slot_id,
    slot_number, start_time, end_time, duration_hours, status, amount,
    payment_status, qr_payload, vehicle_number
  ) values (
    v_booking_id, v_booking_code, v_user_id, v_location.id, v_location.name,
    v_slot.id, v_slot.slot_number, p_start_time,
    p_start_time + make_interval(hours => p_duration_hours), p_duration_hours,
    'reserved', v_amount, 'pending',
    'BOOKING:' || v_booking_code || '|ID:' || v_booking_id || '|SLOT:' || v_slot.slot_number,
    upper(trim(p_vehicle_number))
  ) returning * into v_booking;

  update public.parking_slots
  set status = 'reserved', current_booking_id = v_booking_id
  where id = v_slot.id;

  update public.parking_locations
  set available_slots = greatest(available_slots - 1, 0)
  where id = v_location.id;

  insert into public.notifications (user_id, title, message, type)
  values (
    v_user_id,
    'Booking created',
    'Your parking slot ' || v_slot.slot_number || ' at ' || v_location.name || ' has been reserved.',
    'booking'
  );

  return v_booking;
end;
$$;

create or replace function public.record_demo_payment(
  p_booking_id uuid,
  p_method text default 'UPI'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'Booking not found.';
  end if;
  if v_booking.user_id <> auth.uid() and not public.is_admin() then
    raise exception 'You cannot pay for this booking.';
  end if;
  if v_booking.status in ('cancelled', 'completed') then
    raise exception 'This booking cannot be paid.';
  end if;

  insert into public.payments (booking_id, user_id, amount, method, status)
  values (v_booking.id, v_booking.user_id, v_booking.amount, coalesce(nullif(p_method, ''), 'UPI'), 'success')
  on conflict (booking_id) do update set
    method = excluded.method,
    status = 'success',
    paid_at = now();

  update public.bookings
  set payment_status = 'paid', status = 'confirmed'
  where id = v_booking.id;

  insert into public.notifications (user_id, title, message, type)
  values (
    v_booking.user_id,
    'Payment successful',
    'Payment received for booking ' || v_booking.booking_code || '. Your QR pass is ready.',
    'payment'
  );
end;
$$;

create or replace function public.create_booking_and_pay(
  p_location_id uuid,
  p_slot_id uuid,
  p_start_time timestamptz,
  p_duration_hours integer,
  p_vehicle_number text,
  p_method text default 'UPI'
)
returns public.bookings
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
begin
  if coalesce(p_method, '') not in ('UPI', 'Pay at Parking') then
    raise exception 'Invalid payment method.';
  end if;

  v_booking := public.create_booking(
    p_location_id,
    p_slot_id,
    p_start_time,
    p_duration_hours,
    p_vehicle_number
  );
  perform public.record_demo_payment(v_booking.id, p_method);

  select * into v_booking
  from public.bookings
  where id = v_booking.id;
  return v_booking;
end;
$$;

create or replace function public.verify_booking_flow(
  p_booking_code text,
  p_check_in boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.';
  end if;

  select * into v_booking
  from public.bookings
  where upper(booking_code) = upper(trim(p_booking_code))
  for update;
  if not found then
    raise exception 'Booking code not found.';
  end if;

  if p_check_in then
    if v_booking.payment_status <> 'paid' or v_booking.status <> 'confirmed' then
      raise exception 'Only a paid, confirmed booking can be checked in.';
    end if;
    update public.bookings set status = 'active', checked_in_at = now() where id = v_booking.id;
    update public.parking_slots set status = 'occupied' where id = v_booking.slot_id;
  else
    if v_booking.status <> 'active' then
      raise exception 'Only an active booking can be checked out.';
    end if;
    update public.bookings set status = 'completed', checked_out_at = now() where id = v_booking.id;
    update public.parking_slots
      set status = 'available', current_booking_id = null
      where id = v_booking.slot_id;
    update public.parking_locations
      set available_slots = least(total_slots, available_slots + 1)
      where id = v_booking.location_id;
  end if;

  insert into public.notifications (user_id, title, message, type)
  values (
    v_booking.user_id,
    case when p_check_in then 'Vehicle checked in' else 'Vehicle checked out' end,
    case
      when p_check_in then 'Your booking ' || v_booking.booking_code || ' has been verified for entry.'
      else 'Your booking ' || v_booking.booking_code || ' has been closed successfully.'
    end,
    'verification'
  );
end;
$$;

create or replace function public.update_booking_status(
  p_booking_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_slot public.parking_slots;
  v_old_holds_slot boolean;
  v_new_holds_slot boolean;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.';
  end if;
  if p_status not in ('reserved', 'confirmed', 'active', 'completed', 'cancelled') then
    raise exception 'Invalid booking status.';
  end if;

  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found then
    raise exception 'Booking not found.';
  end if;

  if p_status = v_booking.status then
    return;
  end if;
  if v_booking.status in ('completed', 'cancelled') then
    raise exception 'Completed or cancelled bookings cannot be reopened.';
  end if;
  if p_status = 'active' and v_booking.payment_status <> 'paid' then
    raise exception 'Only a paid booking can be marked active.';
  end if;

  select * into v_slot
  from public.parking_slots
  where id = v_booking.slot_id
  for update;
  if not found then
    raise exception 'Parking slot not found.';
  end if;

  v_old_holds_slot := v_booking.status not in ('completed', 'cancelled');
  v_new_holds_slot := p_status not in ('completed', 'cancelled');

  if v_new_holds_slot then
    if v_slot.current_booking_id is not null
       and v_slot.current_booking_id <> v_booking.id then
      raise exception 'The parking slot belongs to another booking.';
    end if;
    if not v_old_holds_slot and v_slot.status <> 'available' then
      raise exception 'The parking slot is no longer available.';
    end if;

    update public.parking_slots
    set status = case when p_status = 'active' then 'occupied' else 'reserved' end,
        current_booking_id = v_booking.id
    where id = v_booking.slot_id;

    if not v_old_holds_slot then
      update public.parking_locations
      set available_slots = greatest(available_slots - 1, 0)
      where id = v_booking.location_id;
    end if;
  elsif v_old_holds_slot and v_slot.current_booking_id = v_booking.id then
    update public.parking_slots
    set status = 'available', current_booking_id = null
    where id = v_booking.slot_id;
    update public.parking_locations
    set available_slots = least(total_slots, available_slots + 1)
    where id = v_booking.location_id;
  end if;

  update public.bookings
  set status = p_status,
      checked_in_at = case
        when p_status = 'active' then coalesce(checked_in_at, now())
        else checked_in_at
      end,
      checked_out_at = case
        when p_status = 'completed' then coalesce(checked_out_at, now())
        else checked_out_at
      end
  where id = p_booking_id;
end;
$$;

create or replace function public.seed_demo_data()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_city_id uuid;
  v_mall_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Admin access required.';
  end if;
  if exists (select 1 from public.parking_locations) then
    return;
  end if;

  insert into public.parking_locations (
    name, address, city, description, contact_number, base_rate,
    total_slots, available_slots, opening_hours
  ) values (
    'City Centre Parking', 'MG Road, Downtown', 'Ahmedabad',
    'Covered smart parking with CCTV and EV charging.', '+91 98989 00001',
    30, 6, 6, '06:00 AM - 11:30 PM'
  ) returning id into v_city_id;

  insert into public.parking_locations (
    name, address, city, description, contact_number, base_rate,
    total_slots, available_slots, opening_hours
  ) values (
    'Riverfront Mall Parking', 'Sabarmati Riverfront', 'Ahmedabad',
    'Multi-level parking close to shopping and entertainment.', '+91 98989 00002',
    40, 6, 6, '24/7'
  ) returning id into v_mall_id;

  insert into public.parking_slots (
    location_id, slot_number, floor, type, status, vehicle_type, rate_per_hour
  ) values
    (v_city_id, 'A1', 'Ground', 'paid', 'available', 'Car', 30),
    (v_city_id, 'A2', 'Ground', 'paid', 'available', 'Car', 30),
    (v_city_id, 'A3', 'Ground', 'free', 'available', 'Bike', 0),
    (v_city_id, 'E1', 'First', 'paid', 'available', 'EV', 45),
    (v_city_id, 'B1', 'First', 'paid', 'available', 'Car', 30),
    (v_city_id, 'B2', 'First', 'paid', 'available', 'Car', 30),
    (v_mall_id, 'M1', 'Basement 1', 'paid', 'available', 'Car', 40),
    (v_mall_id, 'M2', 'Basement 1', 'paid', 'available', 'Car', 40),
    (v_mall_id, 'M3', 'Basement 1', 'paid', 'available', 'Bike', 20),
    (v_mall_id, 'M4', 'Basement 2', 'paid', 'available', 'Car', 40),
    (v_mall_id, 'M5', 'Basement 2', 'paid', 'available', 'EV', 55),
    (v_mall_id, 'M6', 'Basement 2', 'free', 'available', 'Bike', 0);
end;
$$;

revoke all on function public.handle_new_user() from public;
revoke all on function public.remove_customer_profile_for_admin() from public;
revoke all on function public.is_admin() from public;
revoke all on function public.create_booking(uuid, uuid, timestamptz, integer, text) from public;
revoke all on function public.record_demo_payment(uuid, text) from public;
revoke all on function public.create_booking_and_pay(uuid, uuid, timestamptz, integer, text, text) from public;
revoke all on function public.verify_booking_flow(text, boolean) from public;
revoke all on function public.update_booking_status(uuid, text) from public;
revoke all on function public.seed_demo_data() from public;

grant execute on function public.is_admin() to authenticated;
grant execute on function public.create_booking(uuid, uuid, timestamptz, integer, text) to authenticated;
grant execute on function public.record_demo_payment(uuid, text) to authenticated;
grant execute on function public.create_booking_and_pay(uuid, uuid, timestamptz, integer, text, text) to authenticated;
grant execute on function public.verify_booking_flow(text, boolean) to authenticated;
grant execute on function public.update_booking_status(uuid, text) to authenticated;
grant execute on function public.seed_demo_data() to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'parking-images',
  'parking-images',
  true,
  2097152,
  array['image/jpeg', 'image/png', 'image/gif', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists parking_images_read on storage.objects;
create policy parking_images_read on storage.objects for select
using (bucket_id = 'parking-images');

drop policy if exists profile_images_user_insert on storage.objects;
create policy profile_images_user_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'parking-images'
  and name like ('profile-images/' || (select auth.uid())::text || '/%')
);

drop policy if exists profile_images_user_update on storage.objects;
create policy profile_images_user_update on storage.objects for update to authenticated
using (
  bucket_id = 'parking-images'
  and name like ('profile-images/' || (select auth.uid())::text || '/%')
)
with check (
  bucket_id = 'parking-images'
  and name like ('profile-images/' || (select auth.uid())::text || '/%')
);

drop policy if exists profile_images_user_delete on storage.objects;
create policy profile_images_user_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'parking-images'
  and name like ('profile-images/' || (select auth.uid())::text || '/%')
);

drop policy if exists parking_images_admin_insert on storage.objects;
create policy parking_images_admin_insert on storage.objects for insert to authenticated
with check (bucket_id = 'parking-images' and (select public.is_admin()));

drop policy if exists parking_images_admin_update on storage.objects;
create policy parking_images_admin_update on storage.objects for update to authenticated
using (bucket_id = 'parking-images' and (select public.is_admin()))
with check (bucket_id = 'parking-images' and (select public.is_admin()));

drop policy if exists parking_images_admin_delete on storage.objects;
create policy parking_images_admin_delete on storage.objects for delete to authenticated
using (bucket_id = 'parking-images' and (select public.is_admin()));

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'users', 'admins', 'parking_locations', 'parking_slots',
    'bookings', 'payments', 'notifications', 'complaints'
  ]
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end;
$$;
