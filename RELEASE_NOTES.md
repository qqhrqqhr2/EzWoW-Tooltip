# v2.0.20

### 한국어
- 데이터 공유 현황 창을 추가했습니다. `/공유` 또는 `/ezshare`로 열면 받은 기록, 보낸 사람, 보낸 기록, 종류별 현황과 새로 받은 기록만 따로 볼 수 있습니다.
- 공유 데이터를 채널로도 보내 더 빨리 퍼지게 했습니다.
- 데이터 채널의 사용자 명단이 새로 갱신되지 않아 일부 사용자와 귓속말로 공유 기록을 주고받지 못하던 문제를 고쳤습니다.
- 퀘스트 보상, 트레이너가 가르치는 주문, 오브젝트 이름도 다른 사용자와 공유합니다.
- 게임패드: 전투가 끝나면 EzWoW 창이 패드 조작을 가져가던 문제를 고쳤습니다. 전투 전에 EzWoW 창을 조작하던 경우에만 되돌립니다.
- 다른 사람에게 걸린 버프의 시전자가 내 버프를 건 사람으로 잘못 나오던 문제를 고쳤습니다.
- "캐릭터별 설정 저장"을 켜면 경매장 가격 기록이 캐릭터마다 복사되어 저장 파일이 커지던 문제를 고쳤습니다. 이미 복사된 것은 정리합니다.
- 유닛 프레임에서 연 버프 툴팁에도 주문 ID, 아이콘, 탈것 정보가 나옵니다. "ID 항상 표시"를 켜면 NPC ID도 나옵니다.
- 내 캐릭터 툴팁을 띄워 두는 동안 특성을 계속 다시 계산하던 부담을 줄였습니다.
- Best Gear Finder 정보 줄이 툴팁에서 "…"로 잘리던 문제를 고쳤습니다.
- 공유 기록을 설치된 EzWoW 애드온 중 최대 2개에만 저장해 접속·다시 불러오기가 빨라지고 저장 파일이 작아집니다. 업데이트 후 게임을 한 번 완전히 다시 시작하면 적용됩니다.

### English
- Added a data sharing window. Open it with `/ezshare` to see received records, players, sent records, totals by kind, and only the newly received records.
- Shared data is now also sent through the channel, so it spreads faster.
- Fixed shared records not being exchanged by whisper with some players because the data channel's player list was not refreshed.
- Quest rewards, trainer spells and object names are now shared with other players too.
- Gamepad: EzWoW windows no longer take over the pad after combat; it returns only if you were using an EzWoW window before the fight.
- Fixed buffs on other players showing the caster of your own buff.
- Fixed "per-character settings" copying auction price records into every character's save file. Existing copies are cleaned up.
- Aura tooltips opened from unit frames now get the spell ID, icon and mount info. "Always show IDs" now also shows NPC IDs.
- Your own talents are no longer recomputed on every refresh of your tooltip.
- Fixed Best Gear Finder lines being cut with "…" in tooltips.
- Shared records are now saved by at most 2 of your installed EzWoW addons, so logins and reloads are faster and save files smaller. Takes effect after one full game restart following the update.
