-- Estrutura inicial do Exército de Alameda.
-- Execute somente após revisar no projeto Supabase correto.
-- RLS fica habilitado e sem políticas permissivas por padrão.

create extension if not exists pgcrypto;

create table if not exists public.sectors (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
insert into public.sectors(name) values ('Setor Sul')
on conflict (name) do nothing;

create table if not exists public.ranks (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  hierarchy_level integer not null unique,
  active boolean not null default true
);
insert into public.ranks(name, hierarchy_level) values
('Recruta',1),('Soldado',2),('Sargento',3),('Primeiro-Sargento',4),
('Sargento-Mor',5),('Tenente',6),('Capitão',7),('Major',8),
('Coronel',9),('Major-General',10)
on conflict do nothing;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  qra text not null unique,
  rank_id uuid references public.ranks(id),
  sector_id uuid references public.sectors(id),
  requested_sector_id uuid references public.sectors(id),
  role text not null default 'member'
    check (role in ('member','sector_command','command','super_admin')),
  status text not null default 'pending'
    check (status in ('pending','active','inactive','on_leave','vacation','rejected','dismissed','blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.activity_types (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  points_per_unit integer not null default 1 check (points_per_unit >= 0),
  active boolean not null default true
);
insert into public.activity_types(name, points_per_unit) values
('Rondas externas',1),('Rondas ostensivas',1),('Blitz/operações',1),
('Operações conjuntas',1),('Treinamentos',1),('Atividades de portão',1),
('Roubo de arsenal',1),('Evento de drone',1),('PVP',3),('Outras atividades',1)
on conflict (name) do nothing;

create table if not exists public.weekly_cycles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'open'
    check (status in ('open','closed','archived')),
  check (ends_at > starts_at)
);

create table if not exists public.activity_records (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id),
  sector_id uuid not null references public.sectors(id),
  activity_type_id uuid not null references public.activity_types(id),
  cycle_id uuid references public.weekly_cycles(id),
  activity_date date not null default current_date,
  quantity integer not null default 1 check (quantity > 0),
  status text not null default 'pending'
    check (status in ('pending','approved','rejected')),
  description text,
  observation text,
  points_awarded integer not null default 0 check (points_awarded >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  sector_id uuid references public.sectors(id),
  starts_at timestamptz not null,
  ends_at timestamptz,
  status text not null default 'scheduled'
    check (status in ('scheduled','in_progress','completed','cancelled')),
  created_at timestamptz not null default now()
);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id),
  member_id uuid not null references public.profiles(id),
  status text not null default 'absent'
    check (status in ('present','absent','justified')),
  created_at timestamptz not null default now(),
  unique(event_id, member_id)
);

create table if not exists public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id),
  request_type text not null check (request_type in ('vacation','leave','absence')),
  starts_on date not null,
  ends_on date not null,
  reason text,
  status text not null default 'pending'
    check (status in ('pending','approved','rejected','cancelled')),
  created_at timestamptz not null default now(),
  check (ends_on >= starts_on)
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null,
  sector_id uuid references public.sectors(id),
  published boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id),
  title text not null,
  message text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id),
  action text not null,
  table_name text not null,
  record_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_profiles_sector on public.profiles(sector_id);
create index if not exists idx_profiles_status on public.profiles(status);
create index if not exists idx_activity_member on public.activity_records(member_id);
create index if not exists idx_activity_cycle on public.activity_records(cycle_id);
create index if not exists idx_events_sector_date on public.events(sector_id, starts_at);

alter table public.sectors enable row level security;
alter table public.ranks enable row level security;
alter table public.profiles enable row level security;
alter table public.activity_types enable row level security;
alter table public.weekly_cycles enable row level security;
alter table public.activity_records enable row level security;
alter table public.events enable row level security;
alter table public.attendance enable row level security;
alter table public.leave_requests enable row level security;
alter table public.announcements enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

-- Sem políticas permissivas: usuários não recebem acesso até as políticas
-- por função/setor serem implementadas e testadas.
