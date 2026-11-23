# QuickParking Smart Parking Management System

QuickParking is a Flutter and Supabase smart parking project for an MSc IT Semester 3 submission. It provides separate customer and administrator modules with responsive Material 3 layouts for Android, tablet, web, and Windows.

## Backend

- Supabase Auth for customer and admin authentication
- Supabase PostgreSQL for application data
- Supabase Realtime for bookings, slots, dashboards, and in-app notifications
- Supabase Storage for parking-location images
- PostgreSQL Row Level Security for customer/admin authorization
- PostgreSQL functions for atomic booking, payment, cancellation, and QR verification

No Firebase service is required.

## Features

Customer features include registration, login, password reset, parking search, live slot status, date/time booking, automatic pricing, UPI payment QR, invoice download, booking QR confirmation, history, profile, notifications, and complaints.

Admin features include a separate login, analytics dashboard, customer/location/slot/booking/payment management, QR entry and exit verification, daily/monthly/yearly reports, rates, image uploads, complaints, and demo data.

## Structure

```text
lib/
  core/
  models/
  providers/
  screens/
    admin/
    auth/
    customer/
  services/
supabase/
  schema.sql
```

## Database Tables

- `users`
- `admins`
- `parking_locations`
- `parking_slots`
- `bookings`
- `payments`
- `notifications`
- `complaints`

## Quick Start

Local demo credentials:

- Customer: `customer@gmail.com` / `customer123`
- Admin: `admin@gmail.com` / `admin123`

Read [SUPABASE_SETUP.md](SUPABASE_SETUP.md), then run:

```powershell
flutter pub get
flutter run -d chrome --dart-define-from-file=supabase.env.json
```

The complete database schema, RLS policies, Storage policies, Realtime publication, triggers, indexes, and RPC functions are in `supabase/schema.sql`.
