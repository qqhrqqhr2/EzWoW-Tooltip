# Changelog - EzWoW - Tooltip

## v1.1.0
- 드래그 시 마우스 포인터와 아이콘/프레임 좌표가 어긋나거나 벌어지는 스케일 오차(`EffectiveScale`) 및 초기 점프 현상 수정
- **모듈 아키텍처 재설계 (`Core/`, `Data/`, `Modules/`, `UI/`) 및 성능 개선**:
  - `Core/Base.lua`, `Core/EventBus.lua`, `Core/Platform.lua`, `Core/Locales.lua`, `Core/UIKit.lua`, `Core/Init.lua`
  - `Data/Defaults.lua`, `Data/SourceDB.lua`
  - `Modules/AnchorPosition.lua`, `Modules/AuctionAndMerchant.lua`, `Modules/AuraCasterAndPTR.lua`, `Modules/CardStyle.lua`, `Modules/ItemAndQuestExtras.lua`, `Modules/LinksAndIDs.lua`, `Modules/ModelPreview.lua`, `Modules/SourceAndCollection.lua`, `Modules/TalentInspector.lua`, `Modules/UnitInfo.lua`, `Modules/UnitTacticalExtras.lua`
  - `UI/OptionsWindow.lua`
- **신규 확장 기능**:
  - 유닛 전술 정보(`UnitTacticalExtras`): 현재 탑승 탈것(`showMount`), 이동 속도 %(`showSpeed`), 시전 주문 및 위협 수준 %(`showCastAndThreat`), NPC 추적 정보(`showNpcTracking`) 추가
  - 아이템·상점 확장(`SourceAndCollection`, `AuctionAndMerchant`): 내장 획득처 DB(`showSourceInfo`), 수집 상태(`showCollectionStatus`), 한·영 이중 이름(`showDualName`), 경매장/상점 시세(`showAuctionPrice`), 상점 잡동사니 자동 판매(`autoSellJunk`) 및 장비 자동 수리(`autoRepair`) 추가
  - 오라 시전자 표시(`showAuraCaster`) 및 툴팁 부동소수점 수치 자동 보정(`AuraCasterAndPTR`) 추가
  - `/eztooltip`, `/ezwowtooltip`, `/툴팁` 슬래시 명령어 바인딩 수정 및 보강

## v1.0.0
- `EzWoWStyle` 라임 그린(`#AEE26A`) 툴팁 스킨, 위치 제어, 장비 점수·특성 조사, 3D 모델 미리보기, 8개 언어 실시간 전환 출시
