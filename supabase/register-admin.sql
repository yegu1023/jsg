-- Authentication → Users에서 생성한 운영자 이메일로 아래 주소를 바꾼 뒤 실행하세요.
-- 이 이메일은 공개 저장소에 커밋하지 않고 Supabase SQL Editor에서만 입력하세요.
insert into energy_private.admins(user_id)
select id from auth.users where lower(email)=lower('여기에_운영자_이메일_입력')
on conflict(user_id) do nothing;
-- 결과가 1개 이상인지 확인합니다. 0개면 이메일/사용자 생성 여부를 확인하세요.
select count(*) as registered_admin_count from energy_private.admins;
