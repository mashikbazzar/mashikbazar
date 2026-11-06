-- Run this entire file in Supabase SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.categories(id uuid primary key default gen_random_uuid(),name_bn text not null,name_en text,sort_order int not null default 0,active boolean not null default true);
create table if not exists public.brands(id uuid primary key default gen_random_uuid(),name text not null unique,active boolean not null default true);
create table if not exists public.products(id uuid primary key default gen_random_uuid(),category_id uuid references public.categories(id),name_bn text not null,name_en text,unit text not null default 'পিস',price numeric(12,2) check(price is null or price>=0),image_url text,active boolean not null default true,sort_order int not null default 0,created_at timestamptz not null default now());
create table if not exists public.product_brands(product_id uuid references public.products(id) on delete cascade,brand_id uuid references public.brands(id),primary key(product_id,brand_id));
create table if not exists public.packages(id uuid primary key default gen_random_uuid(),name_bn text not null,name_en text,family_size int not null check(family_size in(2,3,4,5,6,8)),tier text not null default 'Standard',description_bn text,price numeric(12,2) check(price is null or price>=0),active boolean not null default false,sort_order int not null default 0);
create table if not exists public.package_items(id uuid primary key default gen_random_uuid(),package_id uuid not null references public.packages(id) on delete cascade,product_id uuid not null references public.products(id),brand_id uuid references public.brands(id),quantity numeric(12,3) not null check(quantity>0));
create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade,full_name text,phone text,created_at timestamptz not null default now());
create table if not exists public.admin_users(user_id uuid primary key references auth.users(id) on delete cascade,created_at timestamptz not null default now());
create table if not exists public.orders(id uuid primary key default gen_random_uuid(),order_no text unique not null,customer_id uuid references auth.users(id),customer_name text not null,phone text not null,district text not null default 'হবিগঞ্জ',upazila text not null,area text,address text not null,note text,subtotal numeric(12,2) not null default 0,status text not null default 'New Order' check(status in('New Order','Contacted','Confirmed','Preparing','Out for Delivery','Delivered','Cancelled')),created_at timestamptz not null default now());
create table if not exists public.order_items(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id) on delete cascade,product_id uuid references public.products(id),product_name text not null,brand_id uuid references public.brands(id),brand_name text,quantity numeric(12,3) not null check(quantity>0),unit text not null,unit_price numeric(12,2),line_total numeric(12,2));
create index if not exists orders_customer_idx on public.orders(customer_id,created_at desc);
create index if not exists products_sort_idx on public.products(sort_order);
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.admin_users where user_id=auth.uid()); $$;

-- Guest + authenticated checkout; price is read and subtotal calculated server-side.
create or replace function public.place_order(p_order jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_id uuid:=gen_random_uuid();v_no text;v jsonb;v_product public.products%rowtype;v_qty numeric;v_sub numeric:=0;v_items jsonb:='[]'::jsonb;v_brand text;
begin
 if length(trim(coalesce(p_order->>'customer_name','')))<2 then raise exception 'নাম সঠিকভাবে লিখুন';end if;
 if length(regexp_replace(coalesce(p_order->>'phone',''),'\s','','g'))<8 then raise exception 'সঠিক মোবাইল নম্বর দিন';end if;
 if coalesce(p_order->>'address','')='' or coalesce(p_order->>'upazila','')='' then raise exception 'সম্পূর্ণ ঠিকানা দিন';end if;
 v_no:='MB-'||to_char(now() at time zone 'Asia/Dhaka','YYYY')||'-'||upper(substr(replace(v_id::text,'-',''),1,8));
 insert into public.orders(id,order_no,customer_id,customer_name,phone,district,upazila,area,address,note)
 values(v_id,v_no,auth.uid(),trim(p_order->>'customer_name'),regexp_replace(p_order->>'phone','\s','','g'),trim(p_order->>'district'),trim(p_order->>'upazila'),nullif(trim(p_order->>'area'),''),trim(p_order->>'address'),nullif(trim(p_order->>'note'),''));
 for v in select * from jsonb_array_elements(coalesce(p_order->'items','[]'::jsonb)) loop
  v_qty:=(v->>'quantity')::numeric;if v_qty<=0 or v_qty>10000 then raise exception 'পরিমাণ সঠিক নয়';end if;
  select * into v_product from public.products where id=(v->>'product_id')::uuid and active=true;
  if not found then raise exception 'একটি পণ্য আর পাওয়া যাচ্ছে না';end if;
  v_brand:=nullif(v->>'brand_name','');if v_product.price is not null then v_sub:=v_sub+v_product.price*v_qty;end if;
  insert into public.order_items(order_id,product_id,product_name,brand_id,brand_name,quantity,unit,unit_price,line_total)
  values(v_id,v_product.id,v_product.name_bn,nullif(v->>'brand_id','')::uuid,v_brand,v_qty,v_product.unit,v_product.price,case when v_product.price is null then null else v_product.price*v_qty end);
  v_items:=v_items||jsonb_build_array(jsonb_build_object('product_name',v_product.name_bn,'brand_name',v_brand,'quantity',v_qty,'unit',v_product.unit,'unit_price',v_product.price,'line_total',case when v_product.price is null then null else v_product.price*v_qty end));
 end loop;
 if jsonb_array_length(coalesce(p_order->'items','[]'::jsonb))=0 then raise exception 'কার্ট খালি';end if;
 update public.orders set subtotal=v_sub where id=v_id;
 return jsonb_build_object('id',v_id,'order_no',v_no,'subtotal',v_sub,'items',v_items);
end;$$;
create or replace function public.track_order(p_order_no text,p_phone text) returns jsonb language sql security definer set search_path=public as $$
 select jsonb_build_object('order_no',o.order_no,'status',o.status,'created_at',o.created_at) from public.orders o
 where o.order_no=trim(p_order_no) and regexp_replace(o.phone,'\s','','g')=regexp_replace(trim(p_phone),'\s','','g') limit 1;
$$;

alter table public.categories enable row level security;alter table public.brands enable row level security;alter table public.products enable row level security;alter table public.product_brands enable row level security;alter table public.packages enable row level security;alter table public.package_items enable row level security;alter table public.profiles enable row level security;alter table public.admin_users enable row level security;alter table public.orders enable row level security;alter table public.order_items enable row level security;
create policy "read categories" on public.categories for select using(active or is_admin());
create policy "read brands" on public.brands for select using(active or is_admin());
create policy "read products" on public.products for select using(active or is_admin());
create policy "read product brands" on public.product_brands for select using(exists(select 1 from public.products p where p.id=product_id and p.active) or is_admin());
create policy "read packages" on public.packages for select using(active or is_admin());
create policy "read package items" on public.package_items for select using(exists(select 1 from public.packages p where p.id=package_id and p.active) or is_admin());
create policy "own profile" on public.profiles for select using(id=auth.uid() or is_admin());
create policy "own profile update" on public.profiles for update using(id=auth.uid()) with check(id=auth.uid());
create policy "self admin read" on public.admin_users for select using(user_id=auth.uid());
create policy "own orders" on public.orders for select using(customer_id=auth.uid() or is_admin());
create policy "admin order update" on public.orders for update using(is_admin()) with check(is_admin());
create policy "own order items" on public.order_items for select using(exists(select 1 from public.orders o where o.id=order_id and (o.customer_id=auth.uid() or is_admin())));
create policy "admin categories" on public.categories for all using(is_admin()) with check(is_admin());
create policy "admin brands" on public.brands for all using(is_admin()) with check(is_admin());
create policy "admin products" on public.products for all using(is_admin()) with check(is_admin());
create policy "admin product brands" on public.product_brands for all using(is_admin()) with check(is_admin());
create policy "admin packages" on public.packages for all using(is_admin()) with check(is_admin());
create policy "admin package items" on public.package_items for all using(is_admin()) with check(is_admin());
grant execute on function public.place_order(jsonb) to anon,authenticated;
grant execute on function public.track_order(text,text) to anon,authenticated;
grant execute on function public.is_admin() to anon,authenticated;
