-- MOYO+ Supabase 초기 스키마
-- Supabase SQL Editor에서 전체 실행하세요.
create extension if not exists pgcrypto;

create table if not exists public.moyo_tools (
  id text primary key,
  name text not null,
  category text not null,
  sub text default '',
  description text default '',
  url text not null,
  kind text not null default 'tool',
  tags text[] not null default '{}',
  price_type text not null default '확인 필요',
  mobile_friendly boolean not null default false,
  verified boolean not null default false,
  verified_at date,
  image_url text default '',
  favorite_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 기존 MVP 스키마가 이미 존재하는 경우를 위한 비파괴 컬럼 보강
alter table public.moyo_tools add column if not exists sub text default '';
alter table public.moyo_tools add column if not exists description text default '';
alter table public.moyo_tools add column if not exists kind text not null default 'tool';
alter table public.moyo_tools add column if not exists tags text[] not null default '{}';
alter table public.moyo_tools add column if not exists price_type text not null default '확인 필요';
alter table public.moyo_tools add column if not exists mobile_friendly boolean not null default false;
alter table public.moyo_tools add column if not exists verified boolean not null default false;
alter table public.moyo_tools add column if not exists verified_at date;
alter table public.moyo_tools add column if not exists image_url text default '';
alter table public.moyo_tools add column if not exists created_at timestamptz not null default now();
alter table public.moyo_tools add column if not exists updated_at timestamptz not null default now();

create table if not exists public.moyo_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.moyo_user_favorites (
  tool_id text not null references public.moyo_tools(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(tool_id,user_id)
);

alter table public.moyo_tools enable row level security;
alter table public.moyo_admins enable row level security;
alter table public.moyo_user_favorites enable row level security;

drop policy if exists "public read tools" on public.moyo_tools;
create policy "public read tools" on public.moyo_tools for select using (true);
drop policy if exists "admin insert tools" on public.moyo_tools;
create policy "admin insert tools" on public.moyo_tools for insert to authenticated with check (exists(select 1 from public.moyo_admins a where a.user_id=auth.uid()));
drop policy if exists "admin update tools" on public.moyo_tools;
create policy "admin update tools" on public.moyo_tools for update to authenticated using (exists(select 1 from public.moyo_admins a where a.user_id=auth.uid())) with check (exists(select 1 from public.moyo_admins a where a.user_id=auth.uid()));
drop policy if exists "admin delete tools" on public.moyo_tools;
create policy "admin delete tools" on public.moyo_tools for delete to authenticated using (exists(select 1 from public.moyo_admins a where a.user_id=auth.uid()));

drop policy if exists "read own favorites" on public.moyo_user_favorites;
create policy "read own favorites" on public.moyo_user_favorites for select to authenticated using (auth.uid()=user_id);
drop policy if exists "insert own favorites" on public.moyo_user_favorites;
create policy "insert own favorites" on public.moyo_user_favorites for insert to authenticated with check (auth.uid()=user_id);
drop policy if exists "delete own favorites" on public.moyo_user_favorites;
create policy "delete own favorites" on public.moyo_user_favorites for delete to authenticated using (auth.uid()=user_id);

drop policy if exists "read admin self" on public.moyo_admins;
create policy "read admin self" on public.moyo_admins for select to authenticated using (auth.uid()=user_id);

create or replace function public.refresh_moyo_favorite_count()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' then
    update public.moyo_tools set favorite_count=(select count(*) from public.moyo_user_favorites where tool_id=new.tool_id) where id=new.tool_id;
    return new;
  elsif tg_op='DELETE' then
    update public.moyo_tools set favorite_count=(select count(*) from public.moyo_user_favorites where tool_id=old.tool_id) where id=old.tool_id;
    return old;
  end if;
  return null;
end; $$;
drop trigger if exists moyo_fav_ins on public.moyo_user_favorites;
create trigger moyo_fav_ins after insert on public.moyo_user_favorites for each row execute function public.refresh_moyo_favorite_count();
drop trigger if exists moyo_fav_del on public.moyo_user_favorites;
create trigger moyo_fav_del after delete on public.moyo_user_favorites for each row execute function public.refresh_moyo_favorite_count();

create or replace function public.set_moyo_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists moyo_tools_updated_at on public.moyo_tools;
create trigger moyo_tools_updated_at before update on public.moyo_tools for each row execute function public.set_moyo_updated_at();

-- 공개 이미지 버킷. 업로드/삭제는 관리자만 가능.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('moyo-images','moyo-images',true,5242880,array['image/png','image/jpeg','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/png','image/jpeg','image/webp'];
drop policy if exists "public view moyo images" on storage.objects;
create policy "public view moyo images" on storage.objects for select using(bucket_id='moyo-images');
drop policy if exists "admin upload moyo images" on storage.objects;
create policy "admin upload moyo images" on storage.objects for insert to authenticated with check(bucket_id='moyo-images' and exists(select 1 from public.moyo_admins a where a.user_id=auth.uid()));
drop policy if exists "admin update moyo images" on storage.objects;
create policy "admin update moyo images" on storage.objects for update to authenticated using(bucket_id='moyo-images' and exists(select 1 from public.moyo_admins a where a.user_id=auth.uid())) with check(bucket_id='moyo-images' and exists(select 1 from public.moyo_admins a where a.user_id=auth.uid()));
drop policy if exists "admin delete moyo images" on storage.objects;
create policy "admin delete moyo images" on storage.objects for delete to authenticated using(bucket_id='moyo-images' and exists(select 1 from public.moyo_admins a where a.user_id=auth.uid()));

-- 21개 초기 사이트 데이터
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('sansa','산사','가상공간','종교·명상','온라인에서 사찰의 분위기를 경험하는 가상공간.','https://sansa.space/','virtual',array['사찰','불교','명상' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('spatial','Spatial','가상공간','소통·창작','창작자가 만든 3D 공간과 가상 경험을 둘러보는 플랫폼.','https://www.spatial.io/','virtual',array['3D','월드','커뮤니티' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('vrchat','VRChat','가상공간','소통·아바타','이용자가 만든 가상 월드에서 아바타로 소통하는 플랫폼.','https://hello.vrchat.com/','virtual',array['아바타','월드' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('roblox','Roblox','가상공간','게임·체험','이용자 제작 게임과 체험형 가상공간 플랫폼.','https://www.roblox.com/','virtual',array['게임','체험' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('gather','Gather','가상공간','모임·협업','아바타로 이동하며 대화하고 협업하는 온라인 공간.','https://www.gather.town/','virtual',array['모임','협업' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('decentraland','Decentraland','가상공간','가상세계','브라우저에서 탐색하는 분산형 가상세계 플랫폼.','https://decentraland.org/','virtual',array['가상세계','전시' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('oncyber','OnCyber','가상공간','전시·갤러리','디지털 아트와 전시를 위한 3D 가상 갤러리.','https://oncyber.io/','virtual',array['전시','미술' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('recroom','Rec Room','가상공간','게임·소셜','게임과 소셜 활동을 함께 즐기는 가상 경험 플랫폼.','https://recroom.com/','virtual',array['게임','소셜' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('excalidraw','Excalidraw','생산성','온라인 화이트보드','손그림 느낌의 다이어그램과 아이디어를 만드는 도구.','https://excalidraw.com/','tool',array['화이트보드','다이어그램' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('tldraw','tldraw','생산성','무한 캔버스','브라우저에서 아이디어와 흐름을 자유롭게 그리는 캔버스.','https://www.tldraw.com/','tool',array['캔버스','스케치' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('photopea','Photopea','디자인','온라인 이미지 편집','브라우저에서 이미지와 PSD 파일을 편집하는 도구.','https://www.photopea.com/','tool',array['이미지','PSD' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('removebg','remove.bg','디자인','배경 제거','이미지의 배경을 자동으로 제거하는 온라인 도구.','https://www.remove.bg/','tool',array['이미지','배경제거' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('canva','Canva','디자인','콘텐츠 제작','프레젠테이션과 포스터 등 디자인 콘텐츠 제작 플랫폼.','https://www.canva.com/','tool',array['디자인','템플릿' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('regex101','regex101','개발','정규식 테스트','정규표현식을 작성하고 테스트하는 개발 도구.','https://regex101.com/','tool',array['정규식','테스트' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('jsonformatter','JSON Formatter','개발','JSON 정리·검증','JSON 데이터를 정리하고 검증하는 도구.','https://jsonformatter.org/','tool',array['JSON','개발' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('codepen','CodePen','개발','프론트엔드 실험실','HTML·CSS·JavaScript를 작성하고 공유하는 플랫폼.','https://codepen.io/','tool',array['HTML','CSS','JavaScript' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('stackblitz','StackBlitz','개발','온라인 개발환경','브라우저에서 프로젝트를 실행하고 공유하는 개발 환경.','https://stackblitz.com/','tool',array['코딩','IDE' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('mermaid','Mermaid Live Editor','생산성','다이어그램 생성','텍스트로 흐름도와 다이어그램을 만드는 도구.','https://mermaid.live/','tool',array['다이어그램','흐름도' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('wolframalpha','WolframAlpha','교육','지식·계산','수학과 과학 등 다양한 분야의 질문을 계산·분석하는 엔진.','https://www.wolframalpha.com/','tool',array['수학','과학' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('desmos','Desmos','교육','그래프 계산기','함수 그래프와 수학 개념을 시각적으로 탐구하는 도구.','https://www.desmos.com/calculator','tool',array['수학','그래프' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;
insert into public.moyo_tools(id,name,category,sub,description,url,kind,tags,price_type,mobile_friendly,verified,verified_at,image_url) values ('earth','Google Earth','탐험','가상 지구 탐험','위성 이미지와 3D 지형으로 세계 곳곳을 탐험하는 서비스.','https://earth.google.com/web/','tool',array['지도','여행' ]::text[],'확인 필요',false,false,null,'') on conflict(id) do nothing;

-- 관리자 계정 등록 방법:
-- 1) Supabase Authentication > Users에서 관리자 이메일로 계정을 생성합니다.
-- 2) 아래 YOUR_AUTH_USER_UUID를 해당 사용자의 UUID로 바꿔 실행합니다.
-- insert into public.moyo_admins(user_id) values ('YOUR_AUTH_USER_UUID') on conflict do nothing;
-- Realtime: Database > Publications에서 public.moyo_tools 테이블의 UPDATE 이벤트를 활성화하세요.
