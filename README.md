# TEAM ENERGY · GitHub Pages + Supabase

참가자는 QR로 로그인 없이 5문항을 선택합니다. 결과 설명과 실제 활동 소개 후, 팀에서 더 발휘되길 바라는 에너지를 선택합니다. 집계 동의 시 두 응답을 함께 저장합니다. 현황판은 3초 간격으로 갱신됩니다.

**이 파일은 Cloudflare용이 아닙니다. 기존 deploy.yml은 사용하지 않습니다.**

처음 연결은 [처음부터 연결하기.md](처음부터%20연결하기.md)를 따라 진행하세요. 프로그램 설치나 명령어 실행은 필요 없습니다.

## 구성

- `docs/`: GitHub Pages에 공개할 참가자·현황판·운영자·설정 화면, 사진
- `supabase/schema.sql`: 데이터 저장과 접근 권한, 집계 API
- `supabase/seed-questions.sql`: 초기 12문항
- `supabase/register-admin.sql`: 운영자 계정 권한 등록
- `docs/config.js`: Supabase 공개 연결 정보와 선택 상담 링크

## 사용 주소

계정 `yegu1023`, 저장소 이름 `jsg`로 만들고 Pages 배포가 성공한 경우:

- 참가자: https://yegu1023.github.io/jsg/
- 모니터: https://yegu1023.github.io/jsg/dashboard.html
- 운영자: https://yegu1023.github.io/jsg/admin.html
- 연결 설정: https://yegu1023.github.io/jsg/setup.html

주소는 아직 배포되지 않았습니다. 다른 저장소 이름을 사용하면 경로와 QR도 바꿔야 합니다. 현재 `docs/join-qr.png`는 위 참가자 주소용입니다.

## 수정 포인트

- 질문·답안·에너지 연결: 운영자 화면에서 편집 후 전체 저장. 모든 기기의 다음 게임부터 적용.
- 초기 문항: `seed-questions.sql`. `questions.js`만 수정해도 서버 문항은 바뀌지 않습니다.
- 결과 해설·조직 조합·상담 문구: `docs/app.js`
- 색·글자·배치: `docs/style.css`, `docs/live.css`
- 프로그램 사진: `docs/assets/board.png`, `reflection.png`
- 상담 링크: 설정 화면에서 입력해 config.js 교체. 미입력 시 부스 상담 안내 표시.

## 운영 및 한계

운영자 이메일·비밀번호는 Supabase Auth에서 관리합니다. 관리자 토큰은 브라우저 메모리에서만 유지되며 새로고침하면 다시 로그인합니다. 참가자는 로그인할 필요가 없습니다. 익명 사용자는 집계와 문항만 읽을 수 있고, 개별 응답 CSV·문항 버전 기록·수정은 별도 등록된 운영자에게만 허용합니다.

개인 이름·전화번호·회사명은 수집하지 않습니다. 쿠폰 추첨·발송 기능은 포함하지 않았습니다. 반복 참여는 별도 건으로 집계되므로 고유 인원 수와 다릅니다. 공개 참여 주소에는 자동화된 허위 제출 차단 기능이 없으므로 행사 밖 대규모 유입에 대비하려면 추가 보호가 필요합니다.

집계 동점은 균등 분할합니다. 서로 다른 문항 버전은 현황판 필터로 구분합니다. 무작위 5문항의 총점만 저장하므로 문항별 답변·정식 행동유형검사·대표성 있는 연구 표본은 아닙니다. 동의 없이 마치면 응답을 저장하지 않습니다. 삭제·보관 기간은 연구소 운영 기준에 따라 정하세요.

기존 chatgpt.site 응답은 자동 이전되지 않습니다. 기존 운영자 화면에서 CSV를 내려받아 보관할 수 있습니다. 문항 JSON은 새 운영자 화면에 불러올 수 있습니다.

## 공식 참고

- https://supabase.com/docs/guides/getting-started/api-keys
- https://supabase.com/docs/guides/database/functions
- https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
