-- Supabase SQL Editor에서 전체를 실행합니다. 반복 실행해도 응답을 삭제하지 않습니다.
begin;
create schema if not exists energy_private;
revoke all on schema energy_private from public, anon, authenticated;
create table if not exists energy_private.admins(user_id uuid primary key references auth.users(id) on delete cascade);
create table if not exists energy_private.question_sets(version text primary key, questions jsonb not null, created_at timestamptz not null default now());
create table if not exists energy_private.settings(id integer primary key check(id=1),version text not null references energy_private.question_sets(version));
create table if not exists energy_private.responses(id uuid primary key,scores jsonb not null,need text not null check(need in ('D','I','S','C')),version text not null references energy_private.question_sets(version),created_at timestamptz not null default now());
create index if not exists energy_response_version on energy_private.responses(version);
alter table energy_private.admins enable row level security;
alter table energy_private.question_sets enable row level security;
alter table energy_private.settings enable row level security;
alter table energy_private.responses enable row level security;
revoke all on all tables in schema energy_private from public,anon,authenticated;

create or replace function public.energy_api(action text,payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
 q jsonb; item jsonb; answer jsonb; s jsonb; v text; k text; need text; total integer; max_score integer; top_count integer;
 personal jsonb := '{"D":0,"I":0,"S":0,"C":0}';
 desired jsonb := '{"D":0,"I":0,"S":0,"C":0}';
 pairmap jsonb := '{"D":{"D":0,"I":0,"S":0,"C":0},"I":{"D":0,"I":0,"S":0,"C":0},"S":{"D":0,"I":0,"S":0,"C":0},"C":{"D":0,"I":0,"S":0,"C":0}}';
 rowdata record; prior energy_private.responses%rowtype; response_id uuid;
begin
 if octet_length(payload::text)>200000 then raise exception '요청이 너무 큽니다.'; end if;
 if action in ('admin-check','save-questions','export','question-sets') and not exists(select 1 from energy_private.admins where user_id=auth.uid()) then
  raise exception '등록된 운영자 계정으로 로그인해 주세요.';
 end if;
 if action='admin-check' then return '{"ok":true}'; end if;
 if action='questions' then
  select qs.questions,qs.version into q,v from energy_private.settings st join energy_private.question_sets qs on qs.version=st.version where st.id=1;
  if q is null then raise exception '초기 문항 SQL을 먼저 실행해 주세요.'; end if;
  return jsonb_build_object('questions',q,'version',v);
 elsif action='save-questions' then
  q:=payload->'questions';
  if jsonb_typeof(q) is distinct from 'array' then raise exception '문항 형식을 확인해 주세요.'; end if;
  if jsonb_array_length(q)<5 or jsonb_array_length(q)>100 then raise exception '문항은 5~100개여야 합니다.'; end if;
  for item in select value from jsonb_array_elements(q) loop
   if jsonb_typeof(item->'q') is distinct from 'string' or jsonb_typeof(item->'sub') is distinct from 'string' or length(trim(item->>'q'))=0 or length(trim(item->>'sub'))=0 or length(item->>'q')>250 or length(item->>'sub')>250 or jsonb_typeof(item->'a') is distinct from 'array' then raise exception '문항 내용을 확인해 주세요.'; end if;
   if jsonb_array_length(item->'a')<>4 then raise exception '답안은 네 개여야 합니다.'; end if;
   for answer in select value from jsonb_array_elements(item->'a') loop
    if jsonb_typeof(answer) is distinct from 'array' then raise exception '답안 형식을 확인해 주세요.'; end if;
    if jsonb_array_length(answer)<>2 or coalesce(answer->>0,'') not in ('D','I','S','C') or jsonb_typeof(answer->1) is distinct from 'string' or length(trim(answer->>1))=0 or length(answer->>1)>250 then raise exception '답안 내용을 확인해 주세요.'; end if;
   end loop;
   if (select count(distinct value->>0) from jsonb_array_elements(item->'a'))<>4 then raise exception '네 에너지를 각각 하나씩 연결해 주세요.'; end if;
  end loop;
  v:=md5(q::text);
  insert into energy_private.question_sets(version,questions) values(v,q) on conflict(version) do nothing;
  insert into energy_private.settings(id,version) values(1,v) on conflict(id) do update set version=excluded.version;
  return jsonb_build_object('ok',true,'version',v);
 elsif action='responses' then
  if payload->'consent' is distinct from 'true'::jsonb then raise exception '집계 동의가 필요합니다.'; end if;
  response_id:=(payload->>'id')::uuid;s:=payload->'scores';need:=payload->>'need';v:=payload->>'version';
  if response_id is null or jsonb_typeof(s) is distinct from 'object' or coalesce(need,'') not in ('D','I','S','C') then raise exception '응답 내용을 확인해 주세요.'; end if;
  if (select count(*) from jsonb_object_keys(s))<>4 then raise exception '점수 형식을 확인해 주세요.'; end if;
  total:=0;
  foreach k in array array['D','I','S','C'] loop
   if jsonb_typeof(s->k) is distinct from 'number' or (s->>k) !~ '^[0-5]$' then raise exception '점수를 확인해 주세요.'; end if;
   total:=total+(s->>k)::integer;
  end loop;
  if total<>5 or not exists(select 1 from energy_private.question_sets where version=v) then raise exception '게임 점수 또는 문항 버전을 확인해 주세요.'; end if;
  insert into energy_private.responses(id,scores,need,version) values(response_id,s,need,v) on conflict(id) do nothing;
  select * into prior from energy_private.responses where id=response_id;
  if prior.scores<>s or prior.need<>need or prior.version<>v then raise exception '이미 완료된 참여입니다.'; end if;
  return '{"ok":true}';
 elsif action='stats' then
  total:=0;
  for rowdata in select scores,r.need,count(*)::integer n from energy_private.responses r where coalesce(payload->>'version','')='' or r.version=payload->>'version' group by scores,r.need loop
   s:=rowdata.scores;need:=rowdata.need;total:=total+rowdata.n;
   desired:=jsonb_set(desired,array[need],to_jsonb((desired->>need)::numeric+rowdata.n));
   select max(value::integer) into max_score from jsonb_each_text(s);
   select count(*) into top_count from jsonb_each_text(s) where value::integer=max_score;
   foreach k in array array['D','I','S','C'] loop
    if (s->>k)::integer=max_score then
     personal:=jsonb_set(personal,array[k],to_jsonb((personal->>k)::numeric+rowdata.n::numeric/top_count));
     pairmap:=jsonb_set(pairmap,array[k,need],to_jsonb((pairmap->k->>need)::numeric+rowdata.n::numeric/top_count));
    end if;
   end loop;
  end loop;
  return jsonb_build_object('total',total,'personal',personal,'desired',desired,'pairs',pairmap,'updatedAt',now(),'versions',coalesce((select jsonb_agg(t) from (select version,count(*) n from energy_private.responses group by version order by max(created_at) desc)t),'[]'::jsonb));
 elsif action='export' then
  return coalesce((select jsonb_agg(t) from(select r.id,r.scores,r.need,r.version,r.created_at from energy_private.responses r order by r.created_at)t),'[]'::jsonb);
 elsif action='question-sets' then
  return coalesce((select jsonb_agg(t) from(select version,questions,created_at from energy_private.question_sets order by created_at)t),'[]'::jsonb);
 end if;
 raise exception '알 수 없는 요청입니다.';
end $$;
revoke all on function public.energy_api(text,jsonb) from public,anon,authenticated;
grant execute on function public.energy_api(text,jsonb) to anon,authenticated;
commit;
