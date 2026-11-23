begin;

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

  select * into v_booking
  from public.bookings
  where id = p_booking_id
  for update;
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

revoke all on function public.create_booking_and_pay(
  uuid, uuid, timestamptz, integer, text, text
) from public;

grant execute on function public.create_booking_and_pay(
  uuid, uuid, timestamptz, integer, text, text
) to authenticated;

commit;
