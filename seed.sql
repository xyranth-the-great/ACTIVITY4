-- Optional sample equipment for demoing/testing the system.
-- Run in the Supabase SQL editor AFTER schema.sql. The SQL editor runs as
-- the postgres role, so it bypasses RLS and can insert directly.

insert into equipment (code, name, category, description, status) values
  ('LAP-001', 'Dell Latitude 5440 Laptop', 'Computing', '14" business laptop, i5/16GB/512GB', 'available'),
  ('LAP-002', 'MacBook Air M2',            'Computing', '13" Apple Silicon laptop',            'available'),
  ('PRJ-001', 'Epson EB-X49 Projector',    'AV',        '3600-lumen XGA projector',            'available'),
  ('OSC-001', 'Tektronix TBS1102C',        'Electronics', '100MHz 2-channel digital oscilloscope', 'available'),
  ('MUL-001', 'Fluke 117 Multimeter',      'Electronics', 'True-RMS digital multimeter',        'maintenance'),
  ('CAM-001', 'Canon EOS M50 Camera',      'AV',        'Mirrorless camera with 15-45mm lens', 'available'),
  ('RTR-001', 'TP-Link AX1800 Router',     'Networking', 'Wi-Fi 6 router, 4x LAN',             'available'),
  ('BRD-001', 'Arduino Uno Starter Kit',   'Electronics', 'Uno R3 + breadboard + sensor pack',  'available')
on conflict (code) do nothing;

-- ---------------------------------------------------------------------
-- Bootstrapping your first Administrator
-- ---------------------------------------------------------------------
-- 1. Register a normal account through the app's Sign Up page first
--    (it will be created with role = 'requester').
-- 2. Then run, replacing the email:
--
--    update profiles set role = 'admin' where email = 'you@example.com';
--
-- Every role change after that can be done from the app's Users page
-- by that Administrator (calls admin_set_user_role()).
