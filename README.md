# MOYO+ 웹사이트

기존 MOYO+ 초기 카탈로그 21개를 유지하면서 반응형 탐색 화면, 검색, 카테고리/요금/모바일/검증 필터, 상세 보기, 즐겨찾기, 인기순위, 실시간 접속자 표시, 관리자 로그인 및 사이트 CRUD/대표 이미지 업로드를 추가한 배포용 정적 웹 프로젝트입니다.

## 1. 바로 미리보기
- `index.html`을 Chrome 또는 Edge에서 열면 Supabase 연결 없이도 탐색/검색/필터/상세 보기와 브라우저 로컬 즐겨찾기를 테스트할 수 있습니다.
- 이 상태는 미리보기 모드이며 전 세계 사용자 공통 데이터나 관리자 기능은 동작하지 않습니다.

## 2. Supabase 연결 상태
- 프로젝트 URL과 브라우저용 Publishable/anon key는 `supabase-config.js`에 이미 입력되어 있습니다.
- 연결을 활성화하려면 아래 SQL 실행이 남아 있습니다.
1. Supabase Dashboard에서 프로젝트 `https://lfvfjiwdfmmlchhaklpy.supabase.co`를 엽니다.
2. SQL Editor > New query에서 `supabase-schema.sql` 파일 전체를 붙여 넣고 Run을 누릅니다.
3. Authentication > Users에서 관리자 이메일/비밀번호 계정을 생성합니다.
4. 해당 사용자의 UUID를 복사해 SQL Editor에서 아래 SQL을 실행합니다.
   `insert into public.moyo_admins(user_id) values ('관리자_UUID') on conflict do nothing;`
5. Database > Publications에서 `moyo_tools`의 UPDATE 이벤트를 Realtime에 포함합니다.
- `service_role` 또는 secret key는 브라우저 파일에 입력하지 마세요.

## 3. 관리자 기능
- 상단 관리자 버튼에서 Supabase Auth 관리자 계정으로 로그인합니다.
- 사이트 추가/수정/삭제, 카테고리/요금/모바일/검증 상태 설정, 대표 이미지(PNG/JPG/WebP, 5MB 이하) 업로드를 할 수 있습니다.
- 실제 권한은 `moyo_admins` 테이블과 RLS 정책으로 검사합니다.

## 4. Vercel 배포
1. 이 폴더의 파일을 GitHub 저장소에 업로드합니다.
2. Vercel에서 Add New > Project로 저장소를 가져옵니다.
3. Framework Preset은 Other, Build Command는 비우고 Output Directory는 `.`로 설정하거나 Vercel 기본 정적 배포를 사용합니다.
4. Deploy 후 발급된 도메인으로 접속합니다.
5. 커스텀 도메인을 연결하려면 Vercel Project > Settings > Domains에서 진행합니다.

## 5. 현재 범위와 주의사항
- 카탈로그 초기 21개 사이트는 기존 프로젝트의 항목을 유지했습니다. 요금/모바일 지원은 초기 편집용 기본값이므로 실제 게시 전 관리자가 각 서비스의 최신 조건을 확인해 주세요.
- 초기 항목은 검증 완료로 표시하지 않았습니다. 검증 필터는 관리자가 확인한 항목만 표시합니다.
- 즐겨찾기는 로그인한 사용자 계정 기준으로 저장됩니다. Supabase 미연결 시 로컬 브라우저에서만 저장됩니다.
- 관리자 계정 생성과 UUID 등록, Supabase 연결값 입력은 소유자 계정에서 직접 해야 합니다. 이 단계가 완료되기 전에는 실서비스 관리자/공유 DB가 활성화되지 않습니다.
- 개인정보 처리방침, 이용약관, 운영 연락처(현재 hello@moyo.kr 예시)는 실제 운영 전 교체/추가가 필요합니다.


## 6. 연결 점검 참고
- SQL 스키마의 초기 카탈로그 INSERT에서 `mobile_friendly` 컬럼에 NULL을 넣어 실행이 중단될 수 있는 부분을 기본값 `false`로 바로잡았습니다.
- 이 패키지는 연결 정보가 반영된 상태입니다. 다만 이 작업 환경에서는 사용자의 Supabase 계정에 로그인해 SQL을 실행하거나 실제 DB 응답을 확인할 수 없으므로, SQL 실행 및 관리자 등록 전까지 실서비스 DB 연결 완료로 간주하지 않습니다.
