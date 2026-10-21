--===========================================================================
-- EzWoW - Tooltip
-- UI/OptionsWindow.lua : Multi-Tab EzWoW Style Tooltip Configuration Window & Static Mover
--===========================================================================
local addonName, ns = ...

local SettingsDialog = ns.SettingsDialog or {}
ns.SettingsDialog = SettingsDialog
local compat = ns.compat
local addon = EzWoW_Tooltip
local EventDispatcher = ns.events

local DONATE_URL = "https://buymeacoffee.com/qqhrqqhr2"
local ICON_PATH  = "Interface\\AddOns\\EzWoW-Tooltip\\Media\\Icon"

local Theme = {
    bg     = { 0.071, 0.094, 0.122, 0.97 }, 
    bgSub  = { 0.114, 0.157, 0.192, 0.96 }, 
    border = { 0.204, 0.298, 0.357, 1.00 }, 
    accent = { 0.682, 0.886, 0.416, 1.00 }, 
    text   = { 0.929, 0.957, 0.969, 1.00 }, 
    muted  = { 0.655, 0.725, 0.773, 1.00 }, 
    warn   = { 0.906, 0.486, 0.439, 1.00 }, 
}

local LANG_OPTIONS = {
    { "auto", "Auto" },
    { "koKR", "한국어" },
    { "enUS", "English" },
    { "deDE", "Deutsch" },
    { "frFR", "Français" },
    { "esES", "Español" },
    { "ruRU", "Русский" },
    { "zhCN", "简体中文" },
    { "zhTW", "繁體中文" },
}

local LANG_ALIASES = {
    auto = "auto", ["자동"] = "auto",
    ko = "koKR", kokr = "koKR",
    en = "enUS", enus = "enUS", engb = "enUS",
    de = "deDE", dede = "deDE",
    fr = "frFR", frfr = "frFR",
    es = "esES", eses = "esES", esmx = "esES",
    ru = "ruRU", ruru = "ruRU",
    cn = "zhCN", zhcn = "zhCN",
    tw = "zhTW", zhtw = "zhTW",
}

local L_EN = {
    subtitle        = "Tooltip Styling & Extended Info · Drag header to move",
    language        = "Language",
    langAuto        = "Auto",
    borderStyle     = "Border",
    borderAngular   = "Angular",
    borderDefault   = "Default",
    secGeneral      = "General & Appearance",
    scale           = "Scale",
    opacity         = "Opacity",
    mask            = "Top glossy highlight",
    fadeOut         = "Fade out smoothly",
    skinMore        = "Skin dropdown & extra menus (/reload)",
    perChar         = "Save settings per character",
    secAnchor       = "Position & Combat",
    position        = "Anchor",
    posCursorRight  = "Follow Cursor",
    posCursor       = "Follow Cursor",
    posDefault      = "Game Default",
    posStatic       = "Static Point",
    dirTopLeft      = "↖ Top Left",
    dirTopCenter    = "↑ Top Center",
    dirTopRight     = "↗ Top Right",
    dirBottomLeft   = "↙ Bottom Left",
    dirBottomCenter = "↓ Bottom Center",
    dirBottomRight  = "↘ Bottom Right",
    moveStatic      = "Adjust Static Position",
    hideCombat      = "Hide in combat",
    returnCombat    = "Default pos in combat",
    returnUnitFrame = "Use default position on unit frames",
    secUnit         = "Units · Extended Info · Health Bar",
    classBorder     = "Player class border",
    npcBorder       = "NPC reaction border",
    showTarget      = "Show target of target",
    showTargetBy    = "Show party members targeting unit",
    showModel       = "Show 3D unit model",
    showTalent      = "Show player talents",
    showItemLevel   = "Show player item level",
    showMount       = "Show current mount info",
    showSpeed       = "Show movement speed",
    showRoleScore   = "Show PvP honor rank",
    showCastThreat  = "Show casting & threat %",
    showNpcTrack    = "NPC spawn time, layer & drops",
    hideIssueReport = "Hide Issue Reporter & F6 bug hint",
    grayDead        = "Gray out dead units",
    hpText          = "Show health numbers",
    hpHeight        = "HP Bar",
    secItem         = "Items · Spells · Sources · Merchant QoL",
    itemBorder      = "Item quality border",
    questBorder     = "Quest difficulty border",
    showIcons       = "Show item & spell icons",
    showIds         = "Always show IDs (off: Shift/Alt)",
    showSource      = "Show item & quest acquisition source",
    showCollect     = "Gear, mount, recipe & quest status",
    showBagCount    = "Show owned item count (Bag/Bank)",
    showItemDetails = "Show max stack & vendor price",
    showAuraCaster  = "Show buff & debuff caster",
    showAuctionPrice = "Show saved Auction House price",
    scanAuctionBtn  = "Update AH Prices (Saved: %d)",
    showDualName    = "Show Korean/English dual names",
    autoSellJunk    = "Auto-sell grey junk at merchant",
    autoRepair      = "Auto-repair all gear at merchant",
    chatLinkHover   = "Show tooltip when hovering chat links",
    reset           = "Reset Defaults",
    resetDone       = "Settings restored to defaults.",
    donate          = "Support · Copy Link",
    copyTitle       = "Support Link · Ctrl + C to copy",
    hint            = "EzWoW - Tooltip 0.2.0  ·  Open settings: /ezt  ·  Drag header to move",
    panelDesc       = "Customizes character, NPC, item, spell, and quest tooltips and displays useful info such as target, talents, sources, collection status, and AH prices.",
    panelOpen       = "Settings (/ezt)",
    panelHint       = "Type /ezt, /eztooltip or /ezwowtooltip in chat at any time.",
    targetByLabel   = "Targeted By",
    talentLabel     = "Talents",
    noTalent        = "No Talents",
    staticBoxHint   = "Drag this box to place the static tooltip. Click a corner to set its growth anchor.",
}

local LOCALES = {
    enUS = L_EN,
    koKR = setmetatable({
        subtitle        = "툴팁 꾸미기 및 확장 정보 · 상단 제목 표시줄을 드래그해 창 이동",
        language        = "언어",
        langAuto        = "자동",
        borderStyle     = "테두리",
        borderAngular   = "직각",
        borderDefault   = "기본",
        secGeneral      = "일반 · 외형",
        scale           = "툴팁 크기",
        opacity         = "배경 투명도",
        mask            = "툴팁 상단 광택 효과",
        fadeOut         = "서서히 사라지기",
        skinMore        = "드롭다운 · 부가 메뉴 스킨 적용 (/reload)",
        perChar         = "캐릭터별 설정 따로 저장",
        secAnchor       = "표시 위치 · 전투",
        position        = "위치",
        posCursorRight  = "마우스 따라가기",
        posCursor       = "마우스 따라가기",
        posDefault      = "게임 기본 위치",
        posStatic       = "고정 위치",
        dirTopLeft      = "↖ 상단 왼쪽",
        dirTopCenter    = "↑ 상단 중앙",
        dirTopRight     = "↗ 상단 오른쪽",
        dirBottomLeft   = "↙ 하단 왼쪽",
        dirBottomCenter = "↓ 하단 중앙",
        dirBottomRight  = "↘ 하단 오른쪽",
        moveStatic      = "고정 위치 조절",
        hideCombat      = "전투 중 툴팁 숨기기",
        returnCombat    = "전투 중 기본 위치로 전환",
        returnUnitFrame = "유닛 프레임 위에서 기본 위치 사용",
        secUnit         = "유닛 · 확장 정보 · 체력 바",
        classBorder     = "플레이어 직업색 테두리",
        npcBorder       = "NPC 우호도색 테두리",
        showTarget      = "대상의 대상 표시",
        showTargetBy    = "대상을 선택한 파티원 표시",
        showModel       = "3D 캐릭터 모델 표시",
        showTalent      = "플레이어 특성 표시",
        showItemLevel   = "플레이어 아이템 레벨 표시",
        showMount       = "탑승 중인 탈것 표시",
        showSpeed       = "이동 속도(%) 표시",
        showRoleScore   = "PvP 명예 계급 표시",
        showCastThreat  = "시전 스킬 · 위협 수준(%) 표시",
        showNpcTrack    = "NPC 생존시간 · 위상 · 드랍 추적",
        hideIssueReport = "이슈 리포터 창 · F6 제보 문구 숨김",
        grayDead        = "죽은 대상 회색 표시",
        hpText          = "체력 수치 표시",
        hpHeight        = "체력바 높이",
        secItem         = "아이템 · 주문 · 획득처 · 수집 · 상점 편의",
        itemBorder      = "아이템 품질색 테두리",
        questBorder     = "퀘스트 난이도색 테두리",
        showIcons       = "아이템 · 주문 아이콘 표시",
        showIds         = "ID 항상 표시 (끄면 Shift/Alt)",
        showSource      = "아이템 · 퀘스트 획득처 정보 표시",
        showCollect     = "장비 · 탈것 · 도안 · 퀘스트 수집 상태",
        showBagCount    = "아이템 보유 수량 표시 (가방/은행)",
        showItemDetails = "최대 겹침(Shift) · 상점 판매가 표시",
        showAuraCaster  = "버프 · 디버프 시전자 표시",
        showAuctionPrice = "경매장 저장 시세 표시 (개당/묶음)",
        scanAuctionBtn  = "경매장 시세 갱신 (저장: %d개)",
        showDualName    = "한글 · 영문 이름 병기 표시",
        autoSellJunk    = "상점 방문 시 회색 잡템 자동 판매",
        autoRepair      = "상점 방문 시 모든 장비 자동 수리",
        chatLinkHover   = "채팅창 링크에 마우스를 올리면 툴팁 표시",
        reset           = "기본값 복원",
        resetDone       = "설정을 기본값으로 복원했습니다.",
        donate          = "후원하기 · 링크 복사",
        copyTitle       = "후원 주소 · Ctrl + C 로 복사",
        hint            = "EzWoW - Tooltip 0.2.0  ·  설정 열기: /ezt  ·  상단 제목을 드래그해 창 이동",
        panelDesc       = "캐릭터·NPC·아이템·주문·퀘스트 툴팁의 외형을 깔끔하게 다듬고 대상, 특성, 획득처, 수집 상태, 경매장 시세 등 유용한 정보를 함께 표시합니다.",
        panelOpen       = "설정 (/ezt)",
        panelHint       = "채팅창에 /ezt, /eztooltip 또는 /ezwowtooltip을 입력해도 열립니다.",
        targetByLabel   = "이 대상을 선택한 파티원",
        talentLabel     = "특성",
        noTalent        = "특성 없음",
        staticBoxHint   = "상자를 드래그해 고정 툴팁 위치를 지정하세요. 모서리 점을 눌러 기준점을 바꿀 수 있습니다.",
    }, { __index = L_EN }),
    deDE = setmetatable({
        subtitle        = "Tooltip-Stil & Infos · Titel ziehen zum Bewegen",
        language        = "Sprache",
        langAuto        = "Auto",
        borderStyle     = "Rahmen",
        borderAngular   = "Eckig",
        borderDefault   = "Standard",
        secGeneral      = "Allgemein & Aussehen",
        scale           = "Größe",
        opacity         = "Deckkraft",
        mask            = "Glanzeffekt oben",
        fadeOut         = "Sanft ausblenden",
        skinMore        = "Dropdown- & Zusatzmenüs gestalten (/reload)",
        perChar         = "Pro Charakter speichern",
        secAnchor       = "Position & Kampf",
        position        = "Position",
        posCursorRight  = "Mauszeiger folgen",
        posCursor       = "Mauszeiger folgen",
        posDefault      = "Spielstandard",
        posStatic       = "Feste Position",
        dirTopLeft      = "↖ Oben links",
        dirTopCenter    = "↑ Oben mitte",
        dirTopRight     = "↗ Oben rechts",
        dirBottomLeft   = "↙ Unten links",
        dirBottomCenter = "↓ Unten mitte",
        dirBottomRight  = "↘ Unten rechts",
        moveStatic      = "Feste Pos. anpassen",
        hideCombat      = "Im Kampf ausblenden",
        returnCombat    = "Im Kampf Standardposition",
        returnUnitFrame = "Auf Einheitenfenstern Standardposition",
        secUnit         = "Einheiten & Lebensleiste",
        classBorder     = "Spieler-Klassenrahmen",
        npcBorder       = "NSC-Reaktionsrahmen",
        showTarget      = "Ziel des Ziels zeigen",
        showTargetBy    = "Anvisiert von Gruppe zeigen",
        showModel       = "3D-Modell anzeigen",
        showTalent      = "Spieler-Talente zeigen",
        showItemLevel   = "Gegenstandsstufe zeigen",
        showMount       = "Aktuelles Reittier zeigen",
        showSpeed       = "Bewegungstempo zeigen",
        showRoleScore   = "PvP-Ehrenrang zeigen",
        showCastThreat  = "Zauber & Bedrohung %",
        showNpcTrack    = "NSC-Lebenszeit, Ebene & Beute",
        hideIssueReport = "Fehlermelder & F6-Hinweis ausblenden",
        grayDead        = "Tote Ziele ausgrauen",
        hpText          = "Lebenspunkte-Zahlen zeigen",
        hpHeight        = "LP-Höhe",
        secItem         = "Gegenstände · Zauber · Sammlung & Händler",
        itemBorder      = "Gegenstands-Qualitätsrahmen",
        questBorder     = "Quest-Schwierigkeitsrahmen",
        showIcons       = "Item- & Zaubersymbole zeigen",
        showIds         = "IDs immer zeigen (sonst Shift/Alt)",
        showSource      = "Herkunft (Beute/Quest/Händler)",
        showCollect     = "Ausrüstungs-, Reittier-, Rezept- & Queststatus",
        showBagCount    = "Besitzanzahl (Tasche/Bank)",
        showItemDetails = "Max. Stapel & Händlerpreis",
        showAuraCaster  = "Auslöser von Stärk./Schwäch.",
        showAuctionPrice = "Gespeicherten Auktionspreis zeigen",
        scanAuctionBtn  = "AH-Preise aktualisieren (%d)",
        showDualName    = "Zweisprachige Namen anzeigen",
        autoSellJunk    = "Grauen Schrott automatisch verkaufen",
        autoRepair      = "Ausrüstung automatisch reparieren",
        chatLinkHover   = "Tooltip beim Überfahren von Chat-Links",
        reset           = "Standardwerte",
        resetDone       = "Einstellungen zurückgesetzt.",
        donate          = "Unterstützen · Link",
        copyTitle       = "Unterstützungslink · Strg + C zum Kopieren",
        hint            = "EzWoW - Tooltip 0.2.0  ·  Einstellungen: /ezt",
        panelDesc       = "Passt Tooltips für Spieler, NSCs, Gegenstände, Zauber und Quests an und zeigt nützliche Infos wie Ziel, Talente, Symbole und IDs.",
        panelOpen       = "Einstellungen (/ezt)",
        panelHint       = "Jederzeit im Chat mit /ezt, /eztooltip oder /ezwowtooltip aufrufbar.",
        targetByLabel   = "Anvisiert von",
        talentLabel     = "Talente",
        noTalent        = "Keine Talente",
    }, { __index = L_EN }),
    frFR = setmetatable({
        subtitle        = "Style et infos d'infobulle · Glisser le titre",
        language        = "Langue",
        langAuto        = "Auto",
        borderStyle     = "Bordure",
        borderAngular   = "Angulaire",
        borderDefault   = "Défaut",
        secGeneral      = "Général & Apparence",
        scale           = "Échelle",
        opacity         = "Opacité",
        mask            = "Reflet supérieur",
        fadeOut         = "Fondu de fermeture",
        skinMore        = "Habiller menus déroulants (/reload)",
        perChar         = "Sauvegarde par personnage",
        secAnchor       = "Position & Combat",
        position        = "Position",
        posCursorRight  = "Suivre le curseur",
        posCursor       = "Suivre le curseur",
        posDefault      = "Position par défaut",
        posStatic       = "Position fixe",
        dirTopLeft      = "↖ Haut gauche",
        dirTopCenter    = "↑ Haut centre",
        dirTopRight     = "↗ Haut droite",
        dirBottomLeft   = "↙ Bas gauche",
        dirBottomCenter = "↓ Bas centre",
        dirBottomRight  = "↘ Bas droite",
        moveStatic      = "Ajuster pos. fixe",
        hideCombat      = "Masquer en combat",
        returnCombat    = "Pos. par défaut en combat",
        returnUnitFrame = "Pos. par défaut sur portraits d'unité",
        secUnit         = "Unités & Barre de vie",
        classBorder     = "Bordure de classe (joueur)",
        npcBorder       = "Bordure de réaction (PNJ)",
        showTarget      = "Afficher la cible de la cible",
        showTargetBy    = "Afficher ciblé par le groupe",
        showModel       = "Modèle 3D de l'unité",
        showTalent      = "Afficher les talents",
        showItemLevel   = "Niveau d'objet du joueur",
        showMount       = "Monture actuelle",
        showSpeed       = "Vitesse de déplacement",
        showRoleScore   = "Rang d'honneur JcJ",
        showCastThreat  = "Incantation et menace %",
        showNpcTrack    = "Temps PNJ, couche et butin",
        hideIssueReport = "Masquer rapport de bug et raccourci F6",
        grayDead        = "Griser les cibles mortes",
        hpText          = "Texte des points de vie",
        hpHeight        = "Haut. PV",
        secItem         = "Objets · Sorts · Collection & Marchand",
        itemBorder      = "Bordure de qualité d'objet",
        questBorder     = "Bordure de difficulté de quête",
        showIcons       = "Icônes d'objets et de sorts",
        showIds         = "Toujours afficher l'ID (Maj/Alt)",
        showSource      = "Source d'obtention (butin/quête)",
        showCollect     = "État d'équipement, monture, recette et quête",
        showBagCount    = "Quantité possédée (sac/banque)",
        showItemDetails = "Pile max. et prix marchand",
        showAuraCaster  = "Lanceur des améliorations/affaibl.",
        showAuctionPrice = "Afficher le prix de l'HV enregistré",
        scanAuctionBtn  = "Actualiser prix HV (%d)",
        showDualName    = "Afficher les noms bilingues",
        autoSellJunk    = "Vendre auto. les objets gris",
        autoRepair      = "Réparer auto. l'équipement",
        chatLinkHover   = "Infobulle au survol des liens du chat",
        reset           = "Réinitialiser",
        resetDone       = "Paramètres par défaut restaurés.",
        donate          = "Soutenir · Copier lien",
        copyTitle       = "Lien de soutien · Ctrl + C pour copier",
        hint            = "EzWoW - Tooltip 0.2.0  ·  Ouvrir : /ezt",
        panelDesc       = "Personnalise les infobulles des joueurs, PNJ, objets, sorts et quêtes et affiche des infos utiles (cible, talents, icônes, ID).",
        panelOpen       = "Options (/ezt)",
        panelHint       = "Tapez /ezt, /eztooltip ou /ezwowtooltip dans le chat.",
        targetByLabel   = "Ciblé par",
        talentLabel     = "Talents",
        noTalent        = "Aucun talent",
    }, { __index = L_EN }),
    esES = setmetatable({
        subtitle        = "Estilo e info de descripciones · Arrastra el título",
        language        = "Idioma",
        langAuto        = "Auto",
        borderStyle     = "Borde",
        borderAngular   = "Recto",
        borderDefault   = "Clásico",
        secGeneral      = "General y Apariencia",
        scale           = "Escala",
        opacity         = "Opacidad",
        mask            = "Brillo superior",
        fadeOut         = "Desvanecer suavemente",
        skinMore        = "Estilizar menús desplegables (/reload)",
        perChar         = "Ajustes por personaje",
        secAnchor       = "Posición y Combate",
        position        = "Posición",
        posCursorRight  = "Seguir al cursor",
        posCursor       = "Seguir al cursor",
        posDefault      = "Por defecto",
        posStatic       = "Posición fija",
        dirTopLeft      = "↖ Arriba izq.",
        dirTopCenter    = "↑ Arriba centro",
        dirTopRight     = "↗ Arriba der.",
        dirBottomLeft   = "↙ Abajo izq.",
        dirBottomCenter = "↓ Abajo centro",
        dirBottomRight  = "↘ Abajo der.",
        moveStatic      = "Ajustar pos. fija",
        hideCombat      = "Ocultar en combate",
        returnCombat    = "Pos. normal en combate",
        returnUnitFrame = "Pos. normal en marcos de unidad",
        secUnit         = "Unidades y Barra de salud",
        classBorder     = "Borde de clase (jugador)",
        npcBorder       = "Borde de reacción (PNJ)",
        showTarget      = "Mostrar objetivo del objetivo",
        showTargetBy    = "Mostrar quién lo selecciona",
        showModel       = "Mostrar modelo 3D",
        showTalent      = "Mostrar talentos",
        showItemLevel   = "Nivel de objeto del jugador",
        showMount       = "Montura actual",
        showSpeed       = "Velocidad de movimiento",
        showRoleScore   = "Rango de honor JcJ",
        showCastThreat  = "Lanzamiento y amenaza %",
        showNpcTrack    = "Tiempo PNJ, capa y botín",
        hideIssueReport = "Ocultar informe de errores y atajo F6",
        grayDead        = "Objetivos muertos en gris",
        hpText          = "Mostrar números de salud",
        hpHeight        = "Alto PS",
        secItem         = "Objetos · Hechizos · Colección y Mercader",
        itemBorder      = "Borde de calidad de objeto",
        questBorder     = "Borde de dificultad de misión",
        showIcons       = "Iconos de objetos y hechizos",
        showIds         = "Mostrar siempre ID (Mayús/Alt)",
        showSource      = "Fuente de obtención (botín/misión)",
        showCollect     = "Estado de equipo, montura, receta y misión",
        showBagCount    = "Cantidad poseída (bolsa/banco)",
        showItemDetails = "Pila máx. y precio de venta",
        showAuraCaster  = "Lanzador de beneficios/perjuicios",
        showAuctionPrice = "Mostrar precio guardado de subasta",
        scanAuctionBtn  = "Actualizar precios (%d)",
        showDualName    = "Mostrar nombres bilingües",
        autoSellJunk    = "Vender objetos grises automáticamente",
        autoRepair      = "Reparar equipo automáticamente",
        chatLinkHover   = "Mostrar tooltip al pasar sobre enlaces del chat",
        reset           = "Restablecer",
        resetDone       = "Ajustes restablecidos por defecto.",
        donate          = "Apoyar · Copiar enlace",
        copyTitle       = "Enlace de apoyo · Ctrl + C para copiar",
        hint            = "EzWoW - Tooltip 0.2.0  ·  Abrir: /ezt",
        panelDesc       = "Personaliza las descripciones de jugadores, PNJ, objetos, hechizos y misiones mostrando información útil (objetivo, talentos, iconos, ID).",
        panelOpen       = "Opciones (/ezt)",
        panelHint       = "Escribe /ezt, /eztooltip o /ezwowtooltip en el chat.",
        targetByLabel   = "Objetivo de",
        talentLabel     = "Talentos",
        noTalent        = "Sin talentos",
    }, { __index = L_EN }),
    ruRU = setmetatable({
        subtitle        = "Стиль и инфо подсказок · Перетащите заголовок",
        language        = "Язык",
        langAuto        = "Авто",
        borderStyle     = "Рамка",
        borderAngular   = "Прямая",
        borderDefault   = "Стандарт",
        secGeneral      = "Общие и Внешний вид",
        scale           = "Масштаб",
        opacity         = "Прозрачн.",
        mask            = "Верхний блик",
        fadeOut         = "Плавное затухание",
        skinMore        = "Стиль для выпадающих меню (/reload)",
        perChar         = "Настройки для персонажа",
        secAnchor       = "Позиция и Бой",
        position        = "Позиция",
        posCursorRight  = "За курсором",
        posCursor       = "За курсором",
        posDefault      = "По умолчанию",
        posStatic       = "Фиксированная",
        dirTopLeft      = "↖ Сверху слева",
        dirTopCenter    = "↑ Сверху центр",
        dirTopRight     = "↗ Сверху справа",
        dirBottomLeft   = "↙ Снизу слева",
        dirBottomCenter = "↓ Снизу центр",
        dirBottomRight  = "↘ Снизу справа",
        moveStatic      = "Настроить позицию",
        hideCombat      = "Скрывать в бою",
        returnCombat    = "Стандарт. поз. в бою",
        returnUnitFrame = "Стандарт. поз. на рамках юнитов",
        secUnit         = "Юниты и Полоса здоровья",
        classBorder     = "Рамка цвета класса",
        npcBorder       = "Рамка отношения НИП",
        showTarget      = "Цель цели",
        showTargetBy    = "Кто держит в цели",
        showModel       = "3D-модель персонажа",
        showTalent      = "Таланты игрока",
        showItemLevel   = "Уровень предметов игрока",
        showMount       = "Текущий транспорт",
        showSpeed       = "Скорость передвижения",
        showRoleScore   = "Ранг чести PvP",
        showCastThreat  = "Заклинание и угроза %",
        showNpcTrack    = "Время жизни НИП, слой и добыча",
        hideIssueReport = "Скрыть отчет об ошибке и подсказку F6",
        grayDead        = "Серый цвет для мертвых",
        hpText          = "Числа здоровья",
        hpHeight        = "Высота ОЗ",
        secItem         = "Предметы · Заклинания · Коллекция и Торговец",
        itemBorder      = "Рамка качества предмета",
        questBorder     = "Рамка сложности задания",
        showIcons       = "Значки предметов и заклинаний",
        showIds         = "Всегда показывать ID (Shift/Alt)",
        showSource      = "Источник получения (дроп/задание)",
        showCollect     = "Статус экипировки, транспорта, рецептов и заданий",
        showBagCount    = "Количество в сумках и банке",
        showItemDetails = "Макс. стак и цена продажи",
        showAuraCaster  = "Источник баффов и дебаффов",
        showAuctionPrice = "Показывать сохраненную цену аукциона",
        scanAuctionBtn  = "Обновить цены (%d)",
        showDualName    = "Двуязычные названия (КО/АНГ)",
        autoSellJunk    = "Автопродажа серого хлама",
        autoRepair      = "Авторемонт всей экипировки",
        chatLinkHover   = "Подсказка при наведении на ссылки в чате",
        reset           = "Сбросить",
        resetDone       = "Настройки сброшены по умолчанию.",
        donate          = "Поддержать · Ссылка",
        copyTitle       = "Ссылка поддержки · Ctrl + C для копирования",
        hint            = "EzWoW - Tooltip 0.2.0  ·  Открыть: /ezt",
        panelDesc       = "Настраивает подсказки для игроков, НИП, предметов, заклинаний и заданий, отображая цель, таланты, значки и ID.",
        panelOpen       = "Настройки (/ezt)",
        panelHint       = "Введите /ezt, /eztooltip или /ezwowtooltip в чате.",
        targetByLabel   = "Цель для",
        talentLabel     = "Таланты",
        noTalent        = "Нет талантов",
    }, { __index = L_EN }),
    zhCN = setmetatable({
        subtitle        = "鼠标提示美化与信息扩展 · 拖动标题栏移动",
        language        = "语言",
        langAuto        = "自动",
        borderStyle     = "边框",
        borderAngular   = "直角",
        borderDefault   = "默认",
        secGeneral      = "常规与外观",
        scale           = "缩放大小",
        opacity         = "背景透明度",
        mask            = "顶部高光效果",
        fadeOut         = "平滑淡出隐藏",
        skinMore        = "美化下拉菜单与附加框体 (/reload)",
        perChar         = "按角色独立保存配置",
        secAnchor       = "显示位置与战斗",
        position        = "位置",
        posCursorRight  = "跟随鼠标游标",
        posCursor       = "跟随鼠标游标",
        posDefault      = "系统默认位置",
        posStatic       = "固定锚点位置",
        dirTopLeft      = "↖ 左上方",
        dirTopCenter    = "↑ 正上方",
        dirTopRight     = "↗ 右上方",
        dirBottomLeft   = "↙ 左下方",
        dirBottomCenter = "↓ 正下方",
        dirBottomRight  = "↘ 右下方",
        moveStatic      = "调整固定位置",
        hideCombat      = "战斗中隐藏提示",
        returnCombat    = "战斗中恢复默认位置",
        returnUnitFrame = "在单位框体上使用默认位置",
        secUnit         = "单位 · 扩展信息 · 生命条",
        classBorder     = "玩家职业染色边框",
        npcBorder       = "NPC声望染色边框",
        showTarget      = "显示目标的目标",
        showTargetBy    = "显示选中该目标的队友",
        showModel       = "显示3D角色模型",
        showTalent      = "显示玩家天赋",
        showItemLevel   = "显示玩家装等",
        showMount       = "显示当前坐骑信息",
        showSpeed       = "显示移动速度",
        showRoleScore   = "显示PvP荣誉军衔",
        showCastThreat  = "显示施法与仇恨百分比",
        showNpcTrack    = "NPC存活时间 · 位面 · 掉落追踪",
        hideIssueReport = "隐藏问题报告窗口与 F6 快捷键提示",
        grayDead        = "死亡目标灰色显示",
        hpText          = "显示生命值数字",
        hpHeight        = "生命条高度",
        secItem         = "物品 · 法术 · 获取来源 · 收集与商人",
        itemBorder      = "物品品质染色边框",
        questBorder     = "任务难度染色边框",
        showIcons       = "显示物品与法术图标",
        showIds         = "始终显示ID (关闭时按Shift/Alt)",
        showSource      = "显示物品与任务获取来源",
        showCollect     = "显示装备/坐骑/配方/任务收集状态",
        showBagCount    = "显示物品拥有数量 (包/行)",
        showItemDetails = "显示最大堆叠与商人售价",
        showAuraCaster  = "显示增益与减益施放者",
        showAuctionPrice = "显示保存的拍卖行价格",
        scanAuctionBtn  = "更新拍卖行价格 (已存:%d)",
        showDualName    = "同时显示韩文与英文名称",
        autoSellJunk    = "访问商人时自动出售灰色垃圾",
        autoRepair      = "访问商人时自动修理所有装备",
        chatLinkHover   = "鼠标指向聊天链接时显示提示",
        reset           = "恢复默认",
        resetDone       = "已恢复默认设置。",
        donate          = "赞助支持 · 复制链接",
        copyTitle       = "赞助链接 · 按 Ctrl + C 复制",
        hint            = "EzWoW - Tooltip 0.2.0  ·  打开设置：/ezt",
        panelDesc       = "美化角色、NPC、物品、法术与任务鼠标提示，并显示目标、天赋、图标与ID等实用信息。",
        panelOpen       = "设置 (/ezt)",
        panelHint       = "随时在聊天框输入 /ezt, /eztooltip 或 /ezwowtooltip 打开设置。",
        targetByLabel   = "被关注",
        talentLabel     = "天赋",
        noTalent        = "无天赋",
    }, { __index = L_EN }),
    zhTW = setmetatable({
        subtitle        = "滑鼠提示美化與資訊擴充 · 拖曳標題列移動",
        language        = "語言",
        langAuto        = "自動",
        borderStyle     = "邊框",
        borderAngular   = "直角",
        borderDefault   = "預設",
        secGeneral      = "一般與外觀",
        scale           = "縮放大小",
        opacity         = "背景透明度",
        mask            = "頂部高光效果",
        fadeOut         = "平滑淡出隱藏",
        skinMore        = "美化下拉選單與附加框架 (/reload)",
        perChar         = "依角色獨立儲存設定",
        secAnchor       = "顯示位置與戰鬥",
        position        = "位置",
        posCursorRight  = "跟隨滑鼠游標",
        posCursor       = "跟隨滑鼠游標",
        posDefault      = "系統預設位置",
        posStatic       = "固定錨點位置",
        dirTopLeft      = "↖ 左上方",
        dirTopCenter    = "↑ 正上方",
        dirTopRight     = "↗ 右上方",
        dirBottomLeft   = "↙ 左下方",
        dirBottomCenter = "↓ 正下方",
        dirBottomRight  = "↘ 右下方",
        moveStatic      = "調整固定位置",
        hideCombat      = "戰鬥中隱藏提示",
        returnCombat    = "戰鬥中恢復預設位置",
        returnUnitFrame = "在單位框架上使用預設位置",
        secUnit         = "單位 · 擴充資訊 · 生命條",
        classBorder     = "玩家職業染色邊框",
        npcBorder       = "NPC聲望染色邊框",
        showTarget      = "顯示目標的目標",
        showTargetBy    = "顯示選中該目標的隊友",
        showModel       = "顯示3D角色模型",
        showTalent      = "顯示玩家天賦",
        showItemLevel   = "顯示玩家裝等",
        showMount       = "顯示當前坐騎資訊",
        showSpeed       = "顯示移動速度",
        showRoleScore   = "顯示PvP榮譽軍階",
        showCastThreat  = "顯示施法與仇恨百分比",
        showNpcTrack    = "NPC存活時間 · 位面 · 掉落追蹤",
        hideIssueReport = "隱藏問題回報視窗與 F6 快捷鍵提示",
        grayDead        = "死亡目標灰色顯示",
        hpText          = "顯示生命值數字",
        hpHeight        = "生命條高度",
        secItem         = "物品 · 法術 · 獲取來源 · 收集與商人",
        itemBorder      = "物品品質染色邊框",
        questBorder     = "任務難度染色邊框",
        showIcons       = "顯示物品與法術圖示",
        showIds         = "始終顯示ID (關閉時按Shift/Alt)",
        showSource      = "顯示物品與任務獲取來源",
        showCollect     = "顯示裝備/坐騎/配方/任務收集狀態",
        showBagCount    = "顯示物品擁有數量 (包/行)",
        showItemDetails = "顯示最大堆疊與商人售價",
        showAuraCaster  = "顯示增益與減益施放者",
        showAuctionPrice = "顯示已儲存的拍賣場價格",
        scanAuctionBtn  = "更新拍賣場價格 (已存:%d)",
        showDualName    = "同時顯示韓文與英文名稱",
        autoSellJunk    = "造訪商人時自動出售灰色垃圾",
        autoRepair      = "造訪商人時自動修理所有裝備",
        chatLinkHover   = "滑鼠指向聊天連結時顯示提示",
        reset           = "恢復預設",
        resetDone       = "已恢復預設設定。",
        donate          = "贊助支持 · 複製連結",
        copyTitle       = "贊助連結 · 按 Ctrl + C 複製",
        hint            = "EzWoW - Tooltip 0.2.0  ·  打開設定：/ezt",
        panelDesc       = "美化角色、NPC、物品、法術與任務滑鼠提示，並顯示目標、天賦、圖示與ID等實用資訊。",
        panelOpen       = "設定 (/ezt)",
        panelHint       = "隨時在聊天框輸入 /ezt, /eztooltip 或 /ezwowtooltip 打開設定。",
        targetByLabel   = "被關注",
        talentLabel     = "天賦",
        noTalent        = "無天賦",
    }, { __index = L_EN }),
}

-- Static-tooltip placement instructions.
LOCALES.deDE.staticBoxHint = "Dieses Feld ziehen, um den festen Tooltip zu platzieren. Eine Ecke anklicken, um die Wachstumsrichtung festzulegen."
LOCALES.frFR.staticBoxHint = "Faites glisser ce cadre pour placer l'infobulle fixe. Cliquez sur un coin pour choisir son point d'ancrage."
LOCALES.esES.staticBoxHint = "Arrastra este cuadro para colocar la descripción fija. Haz clic en una esquina para fijar su anclaje."
LOCALES.ruRU.staticBoxHint = "Перетащите эту рамку, чтобы разместить неподвижную подсказку. Нажмите на угол, чтобы выбрать точку привязки."
LOCALES.zhCN.staticBoxHint = "拖动此框以设置固定提示的位置。点击角落以设置展开锚点。"
LOCALES.zhTW.staticBoxHint = "拖曳此框以設定固定提示的位置。點擊角落以設定展開錨點。"

local OPTION_TIPS_KO = {
    mask            = "툴팁 상단에 은은한 밝기 그라데이션(광택) 효과를 표시합니다.",
    fadeOut         = "마우스를 떼었을 때 툴팁이 즉시 닫히지 않고 부드럽게 서서히 사라집니다.",
    skinMore        = "채팅 메뉴, 우클릭 드롭다운 메뉴, 친구 목록 툴팁 등에도 EzWoW Style 다크 스킨을 적용합니다. (/reload 필요)",
    perChar         = "계정 공통 설정 대신 현재 접속 중인 캐릭터 전용으로 설정을 별도 저장합니다.",
    hideCombat      = "전투가 시작되면 화면을 가리지 않도록 툴팁을 자동으로 숨깁니다.",
    returnCombat    = "전투 중에는 마우스 따라가기 대신 게임 기본 고정 위치에 툴팁을 표시합니다.",
    returnUnitFrame = "파티창·공격대창·유닛 프레임 위에 마우스를 올렸을 때는 게임 기본 위치에 툴팁을 표시합니다.",
    classBorder     = "플레이어 캐릭터 툴팁의 테두리를 해당 직업 색상으로 강조합니다.",
    npcBorder       = "NPC·몬스터 툴팁의 테두리를 우호도(우호/중립/적대) 색상으로 강조합니다.",
    showModel       = "유닛 툴팁 옆에 대상의 3D 캐릭터/NPC 모델을 함께 표시합니다.",
    showTalent      = "플레이어 툴팁에 주 특성 및 특성 투자 점수(예: 41/0/20)를 표시합니다.",
    showItemLevel   = "플레이어 툴팁에 착용 평균 아이템 레벨을 표시합니다.",
    showRoleScore   = "플레이어 툴팁에 현재 PvP 명예 계급과 계급 배지를 표시합니다.",
    showTarget      = "해당 플레이어나 몬스터가 현재 바라보고 있는 '대상의 대상'을 표시합니다.",
    showTargetBy    = "파티/공격대원 중 현재 이 대상을 함께 타겟으로 잡고 있는 파티원 목록을 표시합니다.",
    showMount       = "플레이어가 탑승 중인 탈것 이름과 내 보유 여부를 표시합니다.",
    showSpeed       = "유닛의 현재 이동 속도(%)를 표시합니다.",
    showCastThreat  = "대상이 시전 중인 주문과 내 위협 수준(어글 %) 및 탱킹 상태를 표시합니다.",
    showNpcTrack    = "NPC의 생성 후 생존 시간, 현재 위상(Layer) 번호, 주요 드랍/퀘스트 수집 진행도를 표시합니다.",
    grayDead        = "죽은 캐릭터나 몬스터의 툴팁 이름을 회색으로 표시합니다.",
    hpText          = "툴팁 하단 체력 바 위에 현재 체력 / 최대 체력 수치를 표시합니다.",
    hideIssueReport = "화면의 PTR 이슈 리포터 버튼과 툴팁 하단의 'F6 버그 제보' 단축키 안내 문구를 숨깁니다.",
    showSource      = "아이템과 퀘스트의 획득처(던전, 보스, 상인, 퀘스트, 채집물, 좌표) 및 제작 재료/사용처를 표시합니다.",
    showCollect     = "장비 보유/착용 여부, 탈것, 애완동물, 전문기술 도안 습득 여부, 퀘스트 완료 상태를 표시합니다.",
    showBagCount    = "현재 보유 중인 아이템 수량(가방 및 은행 합계)을 툴팁에 표시합니다.",
    showItemDetails = "아이템의 상점 판매 가격과 최대 겹침 수량(Shift 누를 때)을 표시합니다.",
    itemBorder      = "아이템 툴팁의 테두리를 아이템 등급(일반/고급/희귀/영웅/전설) 색상으로 표시합니다.",
    questBorder     = "퀘스트 툴팁의 테두리를 내 레벨 대비 퀘스트 난이도 색상으로 표시합니다.",
    showIcons       = "아이템 및 주문 툴팁 제목 앞에 해당 아이콘을 함께 표시합니다.",
    showAuraCaster  = "버프·디버프 툴팁에 해당 효과를 건 시전자 이름을 직업 색상으로 표시합니다.",
    showIds         = "아이템·주문·NPC·퀘스트의 고유 번호(ID)를 항상 표시합니다. (끄면 Shift 또는 Alt를 누를 때만 표시)",
    showAuctionPrice = "경매장을 열었을 때 자동 수집된 최저 즉시 구매가(개당 단가 및 보유 묶음 합산가)를 아이템 툴팁에 표시합니다.",
    showDualName    = "아이템, 주문, 퀘스트, NPC 툴팁의 제목과 획득처·재료 목록에 한글 이름과 영문 이름을 함께 표시합니다.",
    autoSellJunk    = "상점 창을 열었을 때 가방에 있는 회색(하급) 잡템을 자동으로 판매하고 획득 금액을 안내합니다. (Shift를 누른 채 상점을 열면 건너뜀)",
    autoRepair      = "수리 가능한 상인을 열었을 때 착용 및 가방의 모든 장비를 자동으로 수리합니다. (Shift를 누른 채 상점을 열면 건너뜀)",
    chatLinkHover   = "채팅창에 올라온 아이템·주문·퀘스트·업적 링크에 마우스를 올리기만 해도 툴팁을 보여 줍니다. 클릭하지 않아도 됩니다.",
}

local OPTION_TIPS_EN = {
    mask            = "Displays a subtle glossy highlight gradient along the top of the tooltip.",
    fadeOut         = "Smoothly fades out the tooltip instead of hiding it immediately.",
    skinMore        = "Applies the EzWoW Style dark skin to dropdown menus, chat menus, and extra tooltips (/reload required).",
    perChar         = "Saves tooltip settings separately for the current character instead of account-wide.",
    hideCombat      = "Automatically hides tooltips during combat so they don't block the screen.",
    returnCombat    = "Uses the default static position instead of following the cursor while in combat.",
    returnUnitFrame = "Uses the default position when hovering unit/party/raid frames.",
    classBorder     = "Colors player tooltip borders by their class color.",
    npcBorder       = "Colors NPC tooltip borders by their reaction (friendly, neutral, hostile).",
    showModel       = "Displays a 3D model card next to player and NPC tooltips.",
    showTalent      = "Displays player talent specialization and point distribution.",
    showItemLevel   = "Displays the player's equipped item level.",
    showRoleScore   = "Displays the player's PvP Honor rank and badge.",
    showTarget      = "Displays who the unit is currently targeting (Target of Target).",
    showTargetBy    = "Displays which party/raid members are currently targeting this unit.",
    showMount       = "Displays the mount a player is riding and whether you have collected it.",
    showSpeed       = "Displays the unit's current movement speed (%).",
    showCastThreat  = "Displays the unit's current spell cast and your threat percentage.",
    showNpcTrack    = "Displays NPC alive duration, layer/phase ID, and drop/quest collection progress.",
    grayDead        = "Colors dead units' names gray on the tooltip.",
    hpText          = "Displays numeric current / maximum health on the tooltip health bar.",
    hideIssueReport = "Hides the floating PTR Issue Reporter frame and the 'Press F6 to submit a bug' line on tooltips.",
    showSource      = "Displays drop, dungeon, boss, quest, vendor, gathering coordinates, and reagent usage for items.",
    showCollect     = "Displays whether you own/equip the item, learned the recipe/mount/pet, or completed the quest.",
    showBagCount    = "Displays how many of the item you own across bags and bank.",
    showItemDetails = "Displays vendor sell price and maximum stack size (when holding Shift).",
    itemBorder      = "Colors item tooltip borders by item quality.",
    questBorder     = "Colors quest tooltip borders by quest difficulty level.",
    showIcons       = "Displays the item or spell icon next to the tooltip title.",
    showAuraCaster  = "Displays who cast the buff or debuff in their class color.",
    showIds         = "Always displays Item, Spell, NPC, and Quest IDs (when off, hold Shift or Alt to view).",
    showAuctionPrice = "Displays the lowest buyout price (unit & stack total) collected from the Auction House.",
    showDualName    = "Displays both Korean and English names side-by-side on item, spell, quest, and NPC tooltips.",
    autoSellJunk    = "Automatically sells all poor-quality (grey) items in your bags when visiting a merchant (hold Shift while opening to skip).",
    autoRepair      = "Automatically repairs all damaged equipment when visiting a repair-capable merchant (hold Shift while opening to skip).",
    chatLinkHover   = "Shows the tooltip for item, spell, quest, and achievement links in chat as soon as you hover them, without clicking.",
}

function SettingsDialog.resolveCurrentLangCode()
    local userPref = addon.db and addon.db.general and addon.db.general.language or "auto"
    if userPref and userPref ~= "auto" and LOCALES[userPref] then
        return userPref
    end
    local localeTbl = GetLocale and GetLocale() or "enUS"
    if localeTbl == "esMX" then localeTbl = "esES" end
    if LOCALES[localeTbl] then return localeTbl end
    return "enUS"
end

function SettingsDialog.resolveOptionsLocaleText(key)
    local targetTable = LOCALES[SettingsDialog.resolveCurrentLangCode()] or L_EN
    return targetTable[key] or L_EN[key] or key
end

function SettingsDialog.syncTooltipLocale()
    addon.L = addon.L or {}
    addon.L.TargetBy = SettingsDialog.resolveOptionsLocaleText("targetByLabel")
    addon.L.showTargetBy = SettingsDialog.resolveOptionsLocaleText("showTargetBy")
    addon.L.Talent = SettingsDialog.resolveOptionsLocaleText("talentLabel")
    addon.L.NoTalent = SettingsDialog.resolveOptionsLocaleText("noTalent")
end

-----------------------------------------------------------------------------
-- Commit Tooltip Visuals
-----------------------------------------------------------------------------
function SettingsDialog.commitTooltipVisuals()
    local greenVal = addon.db.general
    for _, tipWidget in ipairs(addon.tooltips) do
        EventDispatcher:trigger("tooltip.scale", tipWidget, greenVal.scale)
        EventDispatcher:trigger("tooltip.style.mask", tipWidget, greenVal.mask)
        EventDispatcher:trigger("tooltip.style.bgfile", tipWidget, greenVal.bgfile)
        EventDispatcher:trigger("tooltip.style.border.corner", tipWidget, greenVal.borderCorner)
        EventDispatcher:trigger("tooltip.style.border.size", tipWidget, greenVal.borderSize)
        EventDispatcher:trigger("tooltip.style.border.color", tipWidget, unpack(greenVal.borderColor))
        EventDispatcher:trigger("tooltip.style.background", tipWidget, unpack(greenVal.background))
    end
    EventDispatcher:trigger("tooltip.statusbar.height", greenVal.statusbarHeight)
    EventDispatcher:trigger("tooltip.statusbar.text", greenVal.statusbarText)
end

function SettingsDialog.resolveOpacityPct()
    local backdropTex = addon.db.general.background
    local alphaVal = (backdropTex and backdropTex[4]) or 0.92
    return math.floor(alphaVal * 100 + 0.5)
end

function SettingsDialog.assignOpacityPct(pct)
    local alphaVal = math.max(0.1, math.min(1.0, pct / 100))
    local greenVal = addon.db.general
    greenVal.background = { 18/255, 24/255, 31/255, alphaVal }
    if addon.db.unit and addon.db.unit.player and addon.db.unit.player.background then
        addon.db.unit.player.background.alpha = alphaVal
    end
    if addon.db.unit and addon.db.unit.npc and addon.db.unit.npc.background then
        addon.db.unit.npc.background.alpha = alphaVal
    end
    if addon.db.spell and addon.db.spell.background then
        addon.db.spell.background[4] = alphaVal
    end
    SettingsDialog.commitTooltipVisuals()
end

function SettingsDialog.resolveScalePct()
    return math.floor((addon.db.general.scale or 1) * 100 + 0.5)
end

function SettingsDialog.assignScalePct(pct)
    addon.db.general.scale = tonumber(string.format("%.2f", math.max(0.5, math.min(2.0, pct / 100)))) or 1
    SettingsDialog.commitTooltipVisuals()
end

-----------------------------------------------------------------------------
-- Prepare Static Mover
-----------------------------------------------------------------------------
local grid, saframe

function SettingsDialog.prepareStaticMover()
    if saframe then return saframe end

    grid = CreateFrame("Frame", nil, UIParent)
    grid:SetFrameStrata("FULLSCREEN_DIALOG")
        grid:SetFrameLevel(200)
    grid:SetAllPoints()
    grid:Hide()
    do
        local frameWidth, frameHeight = GetScreenWidth(), GetScreenHeight()
        local line = grid:CreateTexture(nil, "BACKGROUND")
        line:SetSize(frameWidth, 1)
        line:SetColorTexture(0.682, 0.886, 0.416, 0.35)
        line:SetPoint("CENTER")
        line = grid:CreateTexture(nil, "BACKGROUND")
        line:SetSize(1, frameHeight)
        line:SetColorTexture(0.682, 0.886, 0.416, 0.35)
        line:SetPoint("CENTER")
    end

    saframe = CreateFrame("Frame", "EzWoWTooltipStaticAnchor", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    saframe:Hide()
    ns.UIKit:ElevateModal(saframe, 250)
    saframe:SetClampedToScreen(true)
    saframe:EnableMouse(true)
    saframe:SetMovable(true)
    saframe:SetSize(220, 86)
    if saframe.SetBackdrop then
        ns.UIKit:ApplyBackdrop(saframe)
        saframe:SetBackdropColor(unpack(Theme.bg))
        saframe:SetBackdropBorderColor(unpack(Theme.accent))
    end

    saframe.label = saframe:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    saframe.label:SetPoint("CENTER", 0, 4)
    saframe.label:SetWidth(176)
    saframe.label:SetTextColor(unpack(Theme.text))

    local close = CreateFrame("Button", nil, saframe, BackdropTemplateMixin and "BackdropTemplate" or nil)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -3, -3)
    if close.SetBackdrop then
        ns.UIKit:ApplyBackdrop(close)
        close:SetBackdropColor(unpack(Theme.bgSub))
        close:SetBackdropBorderColor(unpack(Theme.border))
    end
    local dismissTxt = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dismissTxt:SetPoint("CENTER", 0, 0)
    dismissTxt:SetText("X")
    dismissTxt:SetTextColor(unpack(Theme.muted))
    close:SetScript("OnEnter", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(Theme.warn)) end
        dismissTxt:SetTextColor(unpack(Theme.warn))
    end)
    close:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(Theme.border)) end
        dismissTxt:SetTextColor(unpack(Theme.muted))
    end)
    close:SetScript("OnClick", function() saframe:Hide() end)

    local function persistStaticPos(self)
        self:StopMovingOrSizing()
        local anc = addon.db.general.anchor
        local anchorTarget = anc.p or "BOTTOMRIGHT"
        local left, right, top, bottom = self:GetLeft(), self:GetRight(), self:GetTop(), self:GetBottom()
        if not (left and right and top and bottom) then return end
        if anchorTarget == "BOTTOMRIGHT" then
            anc.x = math.floor(right - GetScreenWidth()) + 4
            anc.y = math.floor(bottom) - 3
        elseif anchorTarget == "BOTTOMLEFT" then
            anc.x = math.floor(left) - 2
            anc.y = math.floor(bottom) - 3
        elseif anchorTarget == "TOPLEFT" then
            anc.x = math.floor(left) - 2
            anc.y = math.floor(top - GetScreenHeight())
        elseif anchorTarget == "TOPRIGHT" then
            anc.x = math.floor(right - GetScreenWidth()) + 4
            anc.y = math.floor(top - GetScreenHeight())
        elseif anchorTarget == "TOP" then
            anc.x = math.floor(left - GetScreenWidth() / 2 + 110)
            anc.y = math.floor(top - GetScreenHeight())
        elseif anchorTarget == "BOTTOM" then
            anc.x = math.floor(left - GetScreenWidth() / 2 + 110)
            anc.y = math.floor(bottom) - 3
        end
    end

    local corners = { "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT", "TOP", "BOTTOM" }
    local function syncCorners()
        local currentState = addon.db.general.anchor.p or "BOTTOMRIGHT"
        for _, cpVal in ipairs(corners) do
            if saframe[cpVal] then
                if cpVal == currentState then
                    saframe[cpVal]:GetNormalTexture():SetVertexColor(0.682, 0.886, 0.416, 1)
                else
                    saframe[cpVal]:GetNormalTexture():SetVertexColor(0.655, 0.725, 0.773, 0.8)
                end
            end
        end
    end

    for _, cpVal in ipairs(corners) do
        local actionBtn = CreateFrame("Button", nil, saframe)
        actionBtn.cp = cpVal
        actionBtn:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
        actionBtn:SetSize(14, 14)
        actionBtn:SetPoint(cpVal)
        actionBtn:SetScript("OnClick", function(self)
            addon.db.general.anchor.p = self.cp
            syncCorners()
            persistStaticPos(saframe)
        end)
        saframe[cpVal] = actionBtn
    end

    saframe:RegisterForDrag("LeftButton")
    saframe:SetScript("OnDragStart", function(self) self:StartMoving() end)
    saframe:SetScript("OnDragStop", persistStaticPos)
    saframe:SetScript("OnShow", function(self)
        self.label:SetText(SettingsDialog.resolveOptionsLocaleText("staticBoxHint"))
        syncCorners()
        grid:Show()
    end)
    saframe:SetScript("OnHide", function() grid:Hide() end)
    return saframe
end

function SettingsDialog.switchStaticMover()
    local windowFrame = SettingsDialog.prepareStaticMover()
    if windowFrame:IsShown() then
        windowFrame:Hide()
        return
    end
    local anc = addon.db.general.anchor
    local anchorTarget = anc.p or "BOTTOMRIGHT"
    local oxVal = anc.x or -((_G.CONTAINER_OFFSET_X or 0) + 13)
    local oyVal = anc.y or (_G.CONTAINER_OFFSET_Y or 90)
    windowFrame:ClearAllPoints()
    windowFrame:SetPoint(anchorTarget, UIParent, anchorTarget, oxVal, oyVal)
    windowFrame:Show()
end

local configFrame
local BlizzardOptionsCanvas

local POS_ORDER = { "cursor", "default", "static" }
local POS_KEY_MAP = {
    cursorRight = "posCursor",
    cursor      = "posCursor",
    default     = "posDefault",
    static      = "posStatic",
}

local CURSOR_DIR_ORDER = {
    { key = "topLeft",      localeKey = "dirTopLeft" },
    { key = "topCenter",    localeKey = "dirTopCenter" },
    { key = "topRight",     localeKey = "dirTopRight" },
    { key = "bottomLeft",   localeKey = "dirBottomLeft" },
    { key = "bottomCenter", localeKey = "dirBottomCenter" },
    { key = "bottomRight",  localeKey = "dirBottomRight" },
}

function SettingsDialog.resolveActiveCursorDir(anc)
    if not anc then return "topRight" end
    if anc.cursorDir and addon.CURSOR_DIRS and addon.CURSOR_DIRS[anc.cursorDir] then
        return anc.cursorDir
    end
    if anc.position == "cursorRight" then
        return "topRight"
    end
    local cpVal = anc.cp
    if cpVal == "BOTTOMRIGHT" then return "topLeft"
    elseif cpVal == "BOTTOM" then return "topCenter"
    elseif cpVal == "BOTTOMLEFT" then return "topRight"
    elseif cpVal == "TOPRIGHT" then return "bottomLeft"
    elseif cpVal == "TOP" then return "bottomCenter"
    elseif cpVal == "TOPLEFT" then return "bottomRight"
    end
    return "topRight"
end

function SettingsDialog.fitFontStringToWidth(fs, text, maxWidth, baseSize, minSize)
    if not fs then return end
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    if fs.SetTextScale then
        -- scaling keeps the font object, so font addons still apply
        fs:SetTextScale(1)
        fs:SetText(text)
        local _, objectSize = fs:GetFont()
        if not objectSize or objectSize <= 0 then return end
        local size = baseSize
        fs:SetTextScale(size / objectSize)
        while fs:GetStringWidth() > maxWidth and size > minSize do
            size = size - 0.5
            fs:SetTextScale(size / objectSize)
        end
    else
        local font, _, flags = fs:GetFont()
        if not font then
            fs:SetText(text)
            return
        end
        fs:SetFont(font, baseSize, flags)
        fs:SetText(text)
        local size = baseSize
        while fs:GetStringWidth() > maxWidth and size > minSize do
            size = size - 0.5
            fs:SetFont(font, size, flags)
        end
    end
    if fs:GetStringWidth() > maxWidth then
        local orig = text
        while #text > 0 and fs:GetStringWidth() > maxWidth do
            text = text:sub(1, -2)
            while #text > 0 and string.byte(text, #text) >= 128 and string.byte(text, #text) < 192 do
                text = text:sub(1, -2)
            end
            fs:SetText(text .. "...")
            if text == orig then break end
        end
    end
end

function SettingsDialog.resetAllToDefaults()
    local keepLang = addon.db and addon.db.general and addon.db.general.language or "auto"
    local keepAhPrices = EzWoW_TooltipDB and EzWoW_TooltipDB.auctionPrices
    local keepAhTimes  = EzWoW_TooltipDB and EzWoW_TooltipDB.auctionTimes
    local keepAhLast   = EzWoW_TooltipDB and EzWoW_TooltipDB.auctionLastScan
    local fresh = addon.DeepCopy(addon.defaultDB)
    fresh.general.language = keepLang
    EzWoW_TooltipDB = addon.DeepCopy(fresh)
    if type(keepAhPrices) == "table" then EzWoW_TooltipDB.auctionPrices = keepAhPrices end
    if type(keepAhTimes) == "table" then EzWoW_TooltipDB.auctionTimes = keepAhTimes end
    if keepAhLast then EzWoW_TooltipDB.auctionLastScan = keepAhLast end
    EzWoW_TooltipPerCharDB = addon.DeepCopy(fresh)
    EzWoW_TooltipDB = EzWoW_TooltipDB
    EzWoW_TooltipPerCharDB = EzWoW_TooltipPerCharDB
    addon.db = EzWoW_TooltipDB
    EventDispatcher:trigger("tooltip:variables:loaded")
    EventDispatcher:trigger("EZWOW_TOOLTIP_GENERAL_INIT")
    SettingsDialog.commitTooltipVisuals()
    if addon.UpdateIssueReportState then addon:UpdateIssueReportState() end
    SettingsDialog.syncTooltipLocale()
    if configFrame and configFrame.updateLabels then
        configFrame.updateLabels()
    end
    print("|cffAEE26AEzWoW - Tooltip:|r " .. SettingsDialog.resolveOptionsLocaleText("resetDone"))
end

function SettingsDialog.launchConfigWindow()
    if configFrame then
        configFrame:SetShown(not configFrame:IsShown())
        if configFrame:IsShown() then configFrame:Raise() end
        return
    end

    configFrame = CreateFrame("Frame", "EzWoWTooltipConfig", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    configFrame:SetSize(830, 636)
    configFrame:SetPoint("CENTER")
    configFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    configFrame:SetToplevel(true)
    configFrame:SetClampedToScreen(true)
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    if configFrame.SetBackdrop then
        ns.UIKit:ApplyBackdrop(configFrame, 1, 1)
        configFrame:SetBackdropColor(unpack(Theme.bg))
        configFrame:SetBackdropBorderColor(unpack(Theme.border))
    end
    tinsert(UISpecialFrames, "EzWoWTooltipConfig")

    local windowPos = EzWoW_TooltipDB and EzWoW_TooltipDB.windowPos
    if type(windowPos) == "table" and type(windowPos[1]) == "string" and type(windowPos[2]) == "string" and type(windowPos[3]) == "number" and type(windowPos[4]) == "number" then
        pcall(function()
            configFrame:ClearAllPoints()
            configFrame:SetPoint(windowPos[1], UIParent, windowPos[2], windowPos[3], windowPos[4])
        end)
    end

    local top = CreateFrame("Frame", nil, configFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    top:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", configFrame, "TOPRIGHT", -1, -1)
    top:SetHeight(56)
    if top.SetBackdrop then
        top:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        top:SetBackdropColor(unpack(Theme.bgSub))
    end
    top:EnableMouse(true)
    top:RegisterForDrag("LeftButton")
    top:SetScript("OnDragStart", function() configFrame:StartMoving() end)
    top:SetScript("OnDragStop", function()
        configFrame:StopMovingOrSizing()
        local anchorTarget, _, relativePoint, coordX, coordY = configFrame:GetPoint(1)
        if EzWoW_TooltipDB then
            EzWoW_TooltipDB.windowPos = { anchorTarget or "CENTER", relativePoint or "CENTER", coordX or 0, coordY or 0 }
        end
    end)

    local accentLine = top:CreateTexture(nil, "ARTWORK")
    accentLine:SetColorTexture(unpack(Theme.accent))
    accentLine:SetPoint("BOTTOMLEFT", top, "BOTTOMLEFT", 0, 0)
    accentLine:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", 0, 0)
    accentLine:SetHeight(2)

    local titleIcon = top:CreateTexture(nil, "ARTWORK")
    titleIcon:SetSize(28, 28)
    titleIcon:SetPoint("TOPLEFT", 14, -14)
    titleIcon:SetTexture(ICON_PATH)

    local headingRegion = top:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headingRegion:SetPoint("TOPLEFT", 48, -11)
    headingRegion:SetText("EzWoW - Tooltip")
    headingRegion:SetTextColor(unpack(Theme.accent))

    local subtitleRegion = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitleRegion:SetPoint("TOPLEFT", headingRegion, "BOTTOMLEFT", 0, -3)
    subtitleRegion:SetWidth(720)
    subtitleRegion:SetJustifyH("LEFT")
    subtitleRegion:SetTextColor(unpack(Theme.muted))

    local close = CreateFrame("Button", nil, top, BackdropTemplateMixin and "BackdropTemplate" or nil)
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", top, "TOPRIGHT", -14, -14)
    if close.SetBackdrop then
        ns.UIKit:ApplyBackdrop(close)
        close:SetBackdropColor(unpack(Theme.bg))
        close:SetBackdropBorderColor(unpack(Theme.border))
    end
    local dismissTxt = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dismissTxt:SetPoint("CENTER", 0, 0)
    dismissTxt:SetText("X")
    dismissTxt:SetTextColor(unpack(Theme.muted))
    close:SetScript("OnEnter", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(Theme.warn)) end
        dismissTxt:SetTextColor(unpack(Theme.warn))
    end)
    close:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(Theme.border)) end
        dismissTxt:SetTextColor(unpack(Theme.muted))
    end)
    close:SetScript("OnClick", function() configFrame:Hide() end)

    local colDivider = configFrame:CreateTexture(nil, "ARTWORK")
    colDivider:SetColorTexture(0.204, 0.298, 0.357, 0.55)
    colDivider:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 415, -66)
    colDivider:SetSize(1, 316)

    local refreshLabels

    local function createSectionDivider(coordX, coordY, w)
        local resolvedValue = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        resolvedValue:SetPoint("TOPLEFT", coordX, coordY)
        resolvedValue:SetTextColor(unpack(Theme.accent))
        local line = configFrame:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0.204, 0.298, 0.357, 0.85)
        line:SetPoint("TOPLEFT", configFrame, "TOPLEFT", coordX, coordY - 18)
        line:SetSize(w, 1)
        return resolvedValue
    end

    local function createStyledButton(coordX, coordY, w, h, isAccent, onClick)
        local buttonWidget = CreateFrame("Button", nil, configFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
        buttonWidget:SetSize(w, h)
        buttonWidget:SetPoint("TOPLEFT", coordX, coordY)
        buttonWidget.isAccent = isAccent and true or false
        if buttonWidget.SetBackdrop then
            ns.UIKit:ApplyBackdrop(buttonWidget)
            buttonWidget:SetBackdropColor(unpack(Theme.bgSub))
            buttonWidget:SetBackdropBorderColor(unpack(buttonWidget.isAccent and Theme.accent or Theme.border))
        end
        local formatLocalizedLabel = buttonWidget:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        formatLocalizedLabel:SetPoint("CENTER")
        formatLocalizedLabel:SetWidth(w - 10)
        formatLocalizedLabel:SetTextColor(unpack(buttonWidget.isAccent and Theme.accent or Theme.text))
        buttonWidget.label = formatLocalizedLabel
        buttonWidget:SetScript("OnEnter", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(0.16, 0.21, 0.26, 1)
                self:SetBackdropBorderColor(unpack(Theme.accent))
            end
        end)
        buttonWidget:SetScript("OnLeave", function(self)
            if self.SetBackdropColor then
                if self.isActive then
                    self:SetBackdropColor(0.14, 0.22, 0.17, 1)
                    self:SetBackdropBorderColor(unpack(Theme.accent))
                else
                    self:SetBackdropColor(unpack(Theme.bgSub))
                    self:SetBackdropBorderColor(unpack(self.isAccent and Theme.accent or Theme.border))
                end
            end
        end)
        buttonWidget:SetScript("OnMouseDown", function() formatLocalizedLabel:SetPoint("CENTER", 1, -1) end)
        buttonWidget:SetScript("OnMouseUp", function() formatLocalizedLabel:SetPoint("CENTER", 0, 0) end)
        buttonWidget:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        if onClick then buttonWidget:SetScript("OnClick", onClick) end
        return buttonWidget, formatLocalizedLabel
    end

    local allChecks = {}

    local function createStyledCheckbox(coordX, coordY, maxW, localeKey, readOptionValue, writeOptionValue)
        local themeColor = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
        themeColor:SetSize(24, 24)
        themeColor:SetPoint("TOPLEFT", coordX, coordY)
        local resolvedValue = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        resolvedValue:SetPoint("LEFT", themeColor, "RIGHT", 4, 0)
        resolvedValue:SetWidth(maxW)
        resolvedValue:SetJustifyH("LEFT")
        resolvedValue:SetTextColor(unpack(Theme.text))
        themeColor:SetHitRectInsets(0, -(maxW + 4), 0, 0)
        themeColor:SetScript("OnClick", function(self)
            writeOptionValue(self:GetChecked() and true or false)
            if refreshLabels then refreshLabels() end
        end)
        themeColor:SetScript("OnEnter", function(self)
            resolvedValue:SetTextColor(unpack(Theme.accent))
            local hasKo = (SettingsDialog.resolveCurrentLangCode() == "koKR")
            local tipDesc = (hasKo and OPTION_TIPS_KO[localeKey]) or OPTION_TIPS_EN[localeKey]
            if tipDesc then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(SettingsDialog.resolveOptionsLocaleText(localeKey), 0.682, 0.886, 0.416)
                GameTooltip:AddLine(tipDesc, 0.929, 0.957, 0.969, true)
                GameTooltip:Show()
            end
        end)
        themeColor:SetScript("OnLeave", function()
            resolvedValue:SetTextColor(unpack(Theme.text))
            GameTooltip:Hide()
        end)
        allChecks[#allChecks + 1] = {
            chk = themeColor,
            txt = resolvedValue,
            maxW = maxW - 2,
            localeKey = localeKey,
            readValue = readOptionValue,
        }
        return themeColor, resolvedValue
    end

    local function createValueStepper(coordX, coordY, readOptionValue, writeOptionValue, minVal, maxVal, step)
        local formatLocalizedLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        formatLocalizedLabel:SetPoint("TOPLEFT", coordX, coordY - 6)
        formatLocalizedLabel:SetWidth(84)
        formatLocalizedLabel:SetJustifyH("LEFT")
        formatLocalizedLabel:SetTextColor(unpack(Theme.text))

        local function createStepDeltaBtn(sym, bx, delta)
            local actionBtn = CreateFrame("Button", nil, configFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
            actionBtn:SetSize(25, 25)
            actionBtn:SetPoint("TOPLEFT", bx, coordY)
            if actionBtn.SetBackdrop then
                ns.UIKit:ApplyBackdrop(actionBtn)
                actionBtn:SetBackdropColor(unpack(Theme.bgSub))
                actionBtn:SetBackdropBorderColor(unpack(Theme.border))
            end
            local displayText = actionBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            displayText:SetPoint("CENTER", 0, 0)
            displayText:SetText(sym)
            displayText:SetTextColor(unpack(Theme.text))
            actionBtn:SetScript("OnEnter", function(self)
                if self.SetBackdropColor then self:SetBackdropColor(0.16, 0.21, 0.26, 1) end
                if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(Theme.accent)) end
            end)
            actionBtn:SetScript("OnLeave", function(self)
                if self.SetBackdropColor then self:SetBackdropColor(unpack(Theme.bgSub)) end
                if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(Theme.border)) end
            end)
            actionBtn:SetScript("OnMouseDown", function() displayText:SetPoint("CENTER", 1, -1) end)
            actionBtn:SetScript("OnMouseUp", function() displayText:SetPoint("CENTER", 0, 0) end)
            actionBtn:SetScript("OnClick", function()
                local nextVal = math.max(minVal, math.min(maxVal, readOptionValue() + delta))
                writeOptionValue(nextVal)
                if refreshLabels then refreshLabels() end
            end)
            return actionBtn
        end

        local minus = createStepDeltaBtn("-", coordX + 88, -step)
        local plus  = createStepDeltaBtn("+", coordX + 156, step)
        local valText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        valText:SetPoint("CENTER", minus, "CENTER", 34, 0)
        valText:SetWidth(42)
        valText:SetJustifyH("CENTER")
        valText:SetTextColor(unpack(Theme.accent))
        return formatLocalizedLabel, valText
    end

    
    
    local langBtn, langText = createStyledButton(20, -66, 185, 27, false, function(_, button)
        local currentState = addon.db.general.language or "auto"
        local entryIndex = 1
        for index, entryValue in ipairs(LANG_OPTIONS) do
            if entryValue[1] == currentState then entryIndex = index; break end
        end
        if button == "RightButton" then
            entryIndex = (entryIndex - 2) % #LANG_OPTIONS + 1
        else
            entryIndex = entryIndex % #LANG_OPTIONS + 1
        end
        addon.db.general.language = LANG_OPTIONS[entryIndex][1]
        SettingsDialog.syncTooltipLocale()
        refreshLabels()
    end)

    local borderBtn, borderText = createStyledButton(215, -66, 185, 27, false, function()
        local greenVal = addon.db.general
        greenVal.borderCorner = (greenVal.borderCorner == "angular") and "default" or "angular"
        SettingsDialog.commitTooltipVisuals()
        refreshLabels()
    end)

    local secGenHeader = createSectionDivider(20, -104, 380)
    local scaleLabel, scaleVal = createValueStepper(20, -128, SettingsDialog.resolveScalePct, SettingsDialog.assignScalePct, 50, 200, 10)
    local alphaLabel, alphaValEntry = createValueStepper(215, -128, SettingsDialog.resolveOpacityPct, SettingsDialog.assignOpacityPct, 10, 100, 10)

    createStyledCheckbox(20, -160, 160, "mask",
        function() return addon.db.general.mask end,
        function(entryValue) addon.db.general.mask = entryValue; SettingsDialog.commitTooltipVisuals() end)
    createStyledCheckbox(215, -160, 160, "fadeOut",
        function() return addon.db.general.fadeOut end,
        function(entryValue) addon.db.general.fadeOut = entryValue end)

    createStyledCheckbox(20, -186, 160, "skinMore",
        function() return addon.db.general.skinMoreFrames end,
        function(entryValue) addon.db.general.skinMoreFrames = entryValue end)
    createStyledCheckbox(215, -186, 160, "perChar",
        function() return EzWoW_TooltipDB and EzWoW_TooltipDB.general and EzWoW_TooltipDB.general.SavedVariablesPerCharacter end,
        function(entryValue)
            EzWoW_TooltipDB.general.SavedVariablesPerCharacter = entryValue
            if entryValue then
                local savedDB = addon.DeepCopy(addon.db)
                addon.db = addon:MergeVariable(savedDB, EzWoW_TooltipPerCharDB)
            else
                addon.db = EzWoW_TooltipDB
            end
            EventDispatcher:trigger("tooltip:variables:loaded")
            EventDispatcher:trigger("EZWOW_TOOLTIP_GENERAL_INIT")
            SettingsDialog.commitTooltipVisuals()
        end)

    local secAncHeader = createSectionDivider(20, -220, 380)
    local posBtn, posText = createStyledButton(20, -244, 224, 26, false, function(_, button)
        local anc = addon.db.general.anchor
        local currentState = (anc.position == "cursorRight") and "cursor" or (anc.position or "cursor")
        local entryIndex = 1
        for index, anchorTarget in ipairs(POS_ORDER) do
            if anchorTarget == currentState then entryIndex = index; break end
        end
        if button == "RightButton" then
            entryIndex = (entryIndex - 2) % #POS_ORDER + 1
        else
            entryIndex = entryIndex % #POS_ORDER + 1
        end
        local nextPos = POS_ORDER[entryIndex]
        anc.position = nextPos
        if nextPos == "cursor" and not anc.cursorDir then
            anc.cursorDir = SettingsDialog.resolveActiveCursorDir(anc)
        end
        if addon.db.unit and addon.db.unit.player and addon.db.unit.player.anchor then
            addon.db.unit.player.anchor.position = "inherit"
        end
        if addon.db.unit and addon.db.unit.npc and addon.db.unit.npc.anchor then
            addon.db.unit.npc.anchor.position = "inherit"
        end
        refreshLabels()
    end)

    local moveStaticBtn, moveStaticText = createStyledButton(252, -244, 148, 26, false, function()
        addon.db.general.anchor.position = "static"
        if addon.db.unit and addon.db.unit.player and addon.db.unit.player.anchor then
            addon.db.unit.player.anchor.position = "inherit"
        end
        if addon.db.unit and addon.db.unit.npc and addon.db.unit.npc.anchor then
            addon.db.unit.npc.anchor.position = "inherit"
        end
        refreshLabels()
        SettingsDialog.switchStaticMover()
    end)

    local cursorDirBtns = {}
    for index, dirInfo in ipairs(CURSOR_DIR_ORDER) do
        local columnIndex = (index - 1) % 3
        local rowWidget = math.floor((index - 1) / 3)
        local bx = 20 + columnIndex * 129
        local byVal = -275 - rowWidget * 28
        local actionBtn, lbl = createStyledButton(bx, byVal, 122, 24, false, function()
            local anc = addon.db.general.anchor
            anc.position = "cursor"
            anc.cursorDir = dirInfo.key
            local preset = addon.CURSOR_DIRS and addon.CURSOR_DIRS[dirInfo.key]
            if preset then
                anc.cp = preset.cp
                anc.cx = preset.cx
                anc.cy = preset.cy
            end
            if addon.db.unit and addon.db.unit.player and addon.db.unit.player.anchor then
                addon.db.unit.player.anchor.position = "inherit"
            end
            if addon.db.unit and addon.db.unit.npc and addon.db.unit.npc.anchor then
                addon.db.unit.npc.anchor.position = "inherit"
            end
            refreshLabels()
        end)
        cursorDirBtns[index] = { btn = actionBtn, lbl = lbl, key = dirInfo.key, localeKey = dirInfo.localeKey }
    end

    createStyledCheckbox(20, -334, 160, "hideCombat",
        function() return addon.db.general.anchor.hiddenInCombat end,
        function(entryValue)
            addon.db.general.anchor.hiddenInCombat = entryValue
            addon.db.unit.player.anchor.hiddenInCombat = false
            addon.db.unit.npc.anchor.hiddenInCombat = false
        end)
    createStyledCheckbox(215, -334, 160, "returnCombat",
        function() return addon.db.general.anchor.returnInCombat end,
        function(entryValue)
            addon.db.general.anchor.returnInCombat = entryValue
            addon.db.unit.player.anchor.returnInCombat = false
            addon.db.unit.npc.anchor.returnInCombat = false
        end)
    createStyledCheckbox(20, -360, 350, "returnUnitFrame",
        function() return addon.db.general.anchor.returnOnUnitFrame end,
        function(entryValue)
            addon.db.general.anchor.returnOnUnitFrame = entryValue
            addon.db.unit.player.anchor.returnOnUnitFrame = false
            addon.db.unit.npc.anchor.returnOnUnitFrame = false
        end)

    
    
    local secUnitHeader = createSectionDivider(430, -66, 380)
    createStyledCheckbox(430, -90, 160, "classBorder",
        function() return addon.db.unit.player.coloredBorder == "class" end,
        function(entryValue) addon.db.unit.player.coloredBorder = entryValue and "class" or "default" end)
    createStyledCheckbox(625, -90, 160, "npcBorder",
        function() return addon.db.unit.npc.coloredBorder == "reaction" end,
        function(entryValue) addon.db.unit.npc.coloredBorder = entryValue and "reaction" or "default" end)

    createStyledCheckbox(430, -118, 160, "showModel",
        function() return addon.db.unit.player.showModel end,
        function(entryValue)
            addon.db.unit.player.showModel = entryValue
            addon.db.unit.npc.showModel = entryValue
        end)
    createStyledCheckbox(625, -118, 160, "showTalent",
        function() return addon.db.unit.player.showTalent ~= false end,
        function(entryValue)
            addon.db.unit.player.showTalent = entryValue
        end)

    createStyledCheckbox(430, -146, 160, "showItemLevel",
        function() return addon.db.unit.player.showItemLevel ~= false end,
        function(entryValue) addon.db.unit.player.showItemLevel = entryValue end)
    createStyledCheckbox(625, -146, 160, "showRoleScore",
        function() return addon.db.unit.player.showRoleAndScore ~= false end,
        function(entryValue) addon.db.unit.player.showRoleAndScore = entryValue end)

    createStyledCheckbox(430, -174, 160, "showTarget",
        function() return addon.db.unit.player.showTarget end,
        function(entryValue)
            addon.db.unit.player.showTarget = entryValue
            addon.db.unit.npc.showTarget = entryValue
        end)
    createStyledCheckbox(625, -174, 160, "showTargetBy",
        function() return addon.db.unit.player.showTargetBy end,
        function(entryValue)
            addon.db.unit.player.showTargetBy = entryValue
            addon.db.unit.npc.showTargetBy = entryValue
        end)

    createStyledCheckbox(430, -202, 160, "showMount",
        function() return addon.db.unit.player.showMount ~= false end,
        function(entryValue) addon.db.unit.player.showMount = entryValue end)
    createStyledCheckbox(625, -202, 160, "showSpeed",
        function() return addon.db.unit.player.showSpeed ~= false end,
        function(entryValue)
            addon.db.unit.player.showSpeed = entryValue
            addon.db.unit.npc.showSpeed = entryValue
        end)

    createStyledCheckbox(430, -230, 160, "showCastThreat",
        function() return addon.db.unit.player.showCastAndThreat ~= false end,
        function(entryValue)
            addon.db.unit.player.showCastAndThreat = entryValue
            addon.db.unit.npc.showCastAndThreat = entryValue
        end)
    createStyledCheckbox(625, -230, 160, "showNpcTrack",
        function() return addon.db.unit.npc.showNpcTracking ~= false end,
        function(entryValue) addon.db.unit.npc.showNpcTracking = entryValue end)

    createStyledCheckbox(430, -258, 160, "grayDead",
        function() return addon.db.unit.player.grayForDead end,
        function(entryValue)
            addon.db.unit.player.grayForDead = entryValue
            addon.db.unit.npc.grayForDead = entryValue
        end)
    createStyledCheckbox(625, -258, 160, "hpText",
        function() return addon.db.general.statusbarText end,
        function(entryValue)
            addon.db.general.statusbarText = entryValue
            SettingsDialog.commitTooltipVisuals()
        end)

    createStyledCheckbox(430, -288, 350, "hideIssueReport",
        function() return addon.db.general.hideIssueReport ~= false end,
        function(entryValue)
            addon.db.general.hideIssueReport = entryValue
            if addon.UpdateIssueReportState then addon:UpdateIssueReportState() end
        end)

    local hpHeightLabel, hpHeightVal = createValueStepper(430, -326,
        function() return addon.db.general.statusbarHeight or 8 end,
        function(entryValue)
            addon.db.general.statusbarHeight = entryValue
            SettingsDialog.commitTooltipVisuals()
        end, 0, 16, 1)

    
    
    local secItemHeader = createSectionDivider(20, -394, 790)

    createStyledCheckbox(20, -418, 228, "showSource",
        function() return addon.db.item.showSourceInfo ~= false end,
        function(entryValue) addon.db.item.showSourceInfo = entryValue end)
    createStyledCheckbox(286, -418, 228, "showCollect",
        function() return addon.db.item.showCollectionStatus ~= false end,
        function(entryValue) addon.db.item.showCollectionStatus = entryValue end)
    createStyledCheckbox(552, -418, 228, "showBagCount",
        function() return addon.db.item.showBagCount ~= false end,
        function(entryValue) addon.db.item.showBagCount = entryValue end)

    createStyledCheckbox(20, -444, 228, "showItemDetails",
        function() return addon.db.item.showItemDetails ~= false end,
        function(entryValue) addon.db.item.showItemDetails = entryValue end)
    createStyledCheckbox(286, -444, 228, "itemBorder",
        function() return addon.db.item.coloredItemBorder end,
        function(entryValue) addon.db.item.coloredItemBorder = entryValue end)
    createStyledCheckbox(552, -444, 228, "questBorder",
        function() return addon.db.quest.coloredQuestBorder end,
        function(entryValue) addon.db.quest.coloredQuestBorder = entryValue end)

    createStyledCheckbox(20, -470, 228, "showIcons",
        function() return addon.db.item.showItemIcon end,
        function(entryValue)
            addon.db.item.showItemIcon = entryValue
            addon.db.spell.showIcon = entryValue
        end)
    createStyledCheckbox(286, -470, 228, "showAuraCaster",
        function() return addon.db.spell.showAuraCaster ~= false end,
        function(entryValue)
            addon.db.spell.showAuraCaster = entryValue
            if addon.SynchronizeAuraCasterCVar then addon.SynchronizeAuraCasterCVar() end
        end)
    createStyledCheckbox(552, -470, 228, "showIds",
        function() return addon.db.general.alwaysShowIdInfo end,
        function(entryValue) addon.db.general.alwaysShowIdInfo = entryValue end)

    createStyledCheckbox(20, -496, 228, "showAuctionPrice",
        function() return addon.db.item.showAuctionPrice ~= false end,
        function(entryValue) addon.db.item.showAuctionPrice = entryValue end)

    local inspectAhBtn, inspectAhText = createStyledButton(286, -496, 240, 24, false, function()
        if addon.BeginAuctionHousePriceScan then
            addon:BeginAuctionHousePriceScan()
        end
        if refreshLabels then refreshLabels() end
    end)

    createStyledCheckbox(552, -496, 228, "showDualName",
        function() return addon.db.item.showDualName ~= false end,
        function(entryValue) addon.db.item.showDualName = entryValue end)

    createStyledCheckbox(20, -522, 228, "autoSellJunk",
        function() return addon.db.item.autoSellJunk ~= false end,
        function(entryValue) addon.db.item.autoSellJunk = entryValue end)
    createStyledCheckbox(286, -522, 228, "autoRepair",
        function() return addon.db.item.autoRepair ~= false end,
        function(entryValue) addon.db.item.autoRepair = entryValue end)
    createStyledCheckbox(552, -522, 228, "chatLinkHover",
        function() return addon.db.item.chatLinkHover ~= false end,
        function(entryValue) addon.db.item.chatLinkHover = entryValue end)

    local resetBtn, resetText = createStyledButton(195, -564, 210, 30, false, function()
        SettingsDialog.resetAllToDefaults()
    end)

    local copyBox
    local donateBtn, donateText = createStyledButton(425, -564, 210, 30, true, function()
        if not copyBox then
            copyBox = CreateFrame("Frame", "EzWoWTooltipDonate", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
            copyBox:SetSize(390, 116)
            copyBox:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
            ns.UIKit:ElevateModal(copyBox, 260)
            copyBox:EnableMouse(true)
            copyBox:SetMovable(true)
            copyBox:RegisterForDrag("LeftButton")
            copyBox:SetScript("OnDragStart", copyBox.StartMoving)
            copyBox:SetScript("OnDragStop", copyBox.StopMovingOrSizing)
            if UISpecialFrames then table.insert(UISpecialFrames, "EzWoWTooltipDonate") end
            if copyBox.SetBackdrop then
                ns.UIKit:ApplyBackdrop(copyBox)
                copyBox:SetBackdropColor(unpack(Theme.bg))
                copyBox:SetBackdropBorderColor(unpack(Theme.accent))
            end
            local lbl = copyBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("TOP", 0, -14)
            lbl:SetTextColor(unpack(Theme.accent))
            copyBox.lbl = lbl
            local edit = CreateFrame("EditBox", nil, copyBox, BackdropTemplateMixin and "BackdropTemplate" or nil)
            edit:SetSize(346, 27)
            edit:SetFrameLevel(copyBox:GetFrameLevel() + 5)
            edit:SetPoint("TOP", 0, -43)
            if edit.SetBackdrop then
                ns.UIKit:ApplyBackdrop(edit)
                edit:SetBackdropColor(0.047, 0.067, 0.086, 0.96)
                edit:SetBackdropBorderColor(unpack(Theme.border))
            end
            edit:SetFontObject(ChatFontNormal)
            edit:SetTextColor(unpack(Theme.text))
            edit:SetTextInsets(8, 8, 0, 0)
            edit:SetAutoFocus(false)
            edit:SetText(DONATE_URL)
            edit:SetScript("OnEditFocusGained", function(self)
                if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(Theme.accent)) end
                self:HighlightText()
            end)
            edit:SetScript("OnEditFocusLost", function(self)
                if self.SetBackdropBorderColor then self:SetBackdropBorderColor(unpack(Theme.border)) end
            end)
            edit:SetScript("OnEscapePressed", function() copyBox:Hide() end)
            edit:SetScript("OnEnterPressed", function() copyBox:Hide() end)
            copyBox.edit = edit
            local cClose = CreateFrame("Button", nil, copyBox, BackdropTemplateMixin and "BackdropTemplate" or nil)
            cClose:SetSize(22, 22)
            cClose:SetFrameLevel(copyBox:GetFrameLevel() + 5)
            cClose:SetPoint("TOPRIGHT", -6, -6)
            if cClose.SetBackdrop then
                ns.UIKit:ApplyBackdrop(cClose)
                cClose:SetBackdropColor(unpack(Theme.bgSub))
                cClose:SetBackdropBorderColor(unpack(Theme.border))
            end
            local cCloseTxt = cClose:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cCloseTxt:SetPoint("CENTER", 0, 0)
            cCloseTxt:SetText("X")
            cCloseTxt:SetTextColor(unpack(Theme.muted))
            cClose:SetScript("OnClick", function() copyBox:Hide() end)
        end
        copyBox.lbl:SetText(SettingsDialog.resolveOptionsLocaleText("copyTitle"))
        copyBox.edit:SetText(DONATE_URL)
        ns.UIKit:ElevateModal(copyBox, 260)
        copyBox:Show()
        if copyBox.Raise then copyBox:Raise() end
        copyBox.edit:SetFocus()
        copyBox.edit:HighlightText()
    end)

    local hintText = configFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hintText:SetPoint("BOTTOMLEFT", 20, 16)
    hintText:SetWidth(790)
    hintText:SetJustifyH("CENTER")
    hintText:SetTextColor(unpack(Theme.muted))

    local function resolveCurrentLangLabel()
        local currentState = addon.db.general.language or "auto"
        if currentState == "auto" then return SettingsDialog.resolveOptionsLocaleText("langAuto") end
        for _, entryValue in ipairs(LANG_OPTIONS) do
            if entryValue[1] == currentState then return entryValue[2] end
        end
        return SettingsDialog.resolveOptionsLocaleText("langAuto")
    end

    refreshLabels = function()
        SettingsDialog.fitFontStringToWidth(subtitleRegion, SettingsDialog.resolveOptionsLocaleText("subtitle"), 720, 10, 8)
        SettingsDialog.fitFontStringToWidth(langText, SettingsDialog.resolveOptionsLocaleText("language") .. ": " .. resolveCurrentLangLabel() .. " ▼", 174, 12, 9)
        local hasAngular = (addon.db.general.borderCorner == "angular")
        SettingsDialog.fitFontStringToWidth(borderText, SettingsDialog.resolveOptionsLocaleText("borderStyle") .. ": " .. SettingsDialog.resolveOptionsLocaleText(hasAngular and "borderAngular" or "borderDefault") .. " ▼", 174, 12, 9)

        SettingsDialog.fitFontStringToWidth(secGenHeader, SettingsDialog.resolveOptionsLocaleText("secGeneral"), 376, 13, 10)
        SettingsDialog.fitFontStringToWidth(scaleLabel, SettingsDialog.resolveOptionsLocaleText("scale"), 82, 12, 9)
        scaleVal:SetText(SettingsDialog.resolveScalePct() .. "%")
        SettingsDialog.fitFontStringToWidth(alphaLabel, SettingsDialog.resolveOptionsLocaleText("opacity"), 82, 12, 9)
        alphaValEntry:SetText(SettingsDialog.resolveOpacityPct() .. "%")

        SettingsDialog.fitFontStringToWidth(secAncHeader, SettingsDialog.resolveOptionsLocaleText("secAnchor"), 376, 13, 10)
        local anc = addon.db.general.anchor
        local positionData = anc.position or "cursor"
        local hasCursorMode = (positionData == "cursor" or positionData == "cursorRight")
        local activeDir = SettingsDialog.resolveActiveCursorDir(anc)
        local posKey = POS_KEY_MAP[positionData] or "posCursor"
        SettingsDialog.fitFontStringToWidth(posText, SettingsDialog.resolveOptionsLocaleText("position") .. ": " .. SettingsDialog.resolveOptionsLocaleText(posKey) .. " ▼", 212, 12, 9)
        SettingsDialog.fitFontStringToWidth(moveStaticText, SettingsDialog.resolveOptionsLocaleText("moveStatic"), 136, 12, 9)

        for _, item in ipairs(cursorDirBtns) do
            SettingsDialog.fitFontStringToWidth(item.lbl, SettingsDialog.resolveOptionsLocaleText(item.localeKey), 112, 11, 9)
            local active = hasCursorMode and (item.key == activeDir)
            item.btn.isActive = active
            if item.btn.SetBackdropColor then
                if active then
                    item.btn:SetBackdropColor(0.14, 0.22, 0.17, 1)
                    item.btn:SetBackdropBorderColor(unpack(Theme.accent))
                    item.lbl:SetTextColor(unpack(Theme.accent))
                else
                    item.btn:SetBackdropColor(unpack(Theme.bgSub))
                    item.btn:SetBackdropBorderColor(unpack(Theme.border))
                    item.lbl:SetTextColor(unpack(hasCursorMode and Theme.text or Theme.muted))
                end
            end
        end

        SettingsDialog.fitFontStringToWidth(secUnitHeader, SettingsDialog.resolveOptionsLocaleText("secUnit"), 376, 13, 10)
        SettingsDialog.fitFontStringToWidth(hpHeightLabel, SettingsDialog.resolveOptionsLocaleText("hpHeight"), 82, 12, 9)
        hpHeightVal:SetText((addon.db.general.statusbarHeight or 8) .. "px")

        SettingsDialog.fitFontStringToWidth(secItemHeader, SettingsDialog.resolveOptionsLocaleText("secItem"), 780, 13, 10)
        local ahCount = addon.CountCachedAuctionPrices and addon:CountCachedAuctionPrices() or 0
        SettingsDialog.fitFontStringToWidth(inspectAhText, string.format(SettingsDialog.resolveOptionsLocaleText("scanAuctionBtn"), ahCount), 236, 11, 9)

        SettingsDialog.fitFontStringToWidth(resetText, SettingsDialog.resolveOptionsLocaleText("reset"), 196, 12, 9)
        SettingsDialog.fitFontStringToWidth(donateText, SettingsDialog.resolveOptionsLocaleText("donate"), 196, 12, 9)
        SettingsDialog.fitFontStringToWidth(hintText, SettingsDialog.resolveOptionsLocaleText("hint"), 780, 10, 8)

        for _, item in ipairs(allChecks) do
            SettingsDialog.fitFontStringToWidth(item.txt, SettingsDialog.resolveOptionsLocaleText(item.localeKey), item.maxW, 12, 9)
            item.chk:SetChecked(item.readValue() and true or false)
        end

        if BlizzardOptionsCanvas and BlizzardOptionsCanvas.updateText then
            BlizzardOptionsCanvas.updateText()
        end
    end

    configFrame.updateLabels = refreshLabels
    configFrame:SetScript("OnShow", refreshLabels)
    refreshLabels()
end

-----------------------------------------------------------------------------
-- Register Blizzard Options
-----------------------------------------------------------------------------
function SettingsDialog.registerBlizzardOptions()
    if BlizzardOptionsCanvas then return end
    BlizzardOptionsCanvas = CreateFrame("Frame", "EzWoWTooltipInterfaceOptionsPanel", UIParent)
    BlizzardOptionsCanvas.name = "EzWoW - Tooltip"

    local iconTex = BlizzardOptionsCanvas:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(32, 32)
    iconTex:SetPoint("TOPLEFT", 18, -18)
    iconTex:SetTexture(ICON_PATH)

    local headingRegion = BlizzardOptionsCanvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    headingRegion:SetPoint("LEFT", iconTex, "RIGHT", 10, 0)
    headingRegion:SetText("EzWoW - Tooltip")
    headingRegion:SetTextColor(unpack(Theme.accent))

    local desc = BlizzardOptionsCanvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", iconTex, "BOTTOMLEFT", 0, -14)
    desc:SetWidth(520)
    desc:SetJustifyH("LEFT")

    local launchBtn = CreateFrame("Button", nil, BlizzardOptionsCanvas, BackdropTemplateMixin and "BackdropTemplate" or nil)
    launchBtn:SetSize(220, 28)
    launchBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)
    if launchBtn.SetBackdrop then
        ns.UIKit:ApplyBackdrop(launchBtn)
        launchBtn:SetBackdropColor(0.14, 0.22, 0.14, 0.96)
        launchBtn:SetBackdropBorderColor(unpack(Theme.accent))
    end
    launchBtn.label = launchBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    launchBtn.label:SetPoint("CENTER")
    launchBtn.label:SetTextColor(unpack(Theme.accent))
    launchBtn:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(0.20, 0.30, 0.19, 1)
            self:SetBackdropBorderColor(unpack(Theme.accent))
        end
    end)
    launchBtn:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(0.14, 0.22, 0.14, 0.96)
            self:SetBackdropBorderColor(unpack(Theme.accent))
        end
    end)
    launchBtn:SetScript("OnMouseDown", function(self) self.label:SetPoint("CENTER", 1, -1) end)
    launchBtn:SetScript("OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 0) end)
    launchBtn:SetScript("OnClick", function() SettingsDialog.launchConfigWindow() end)

    local hint = BlizzardOptionsCanvas:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", launchBtn, "BOTTOMLEFT", 0, -14)
    hint:SetTextColor(unpack(Theme.muted))

    BlizzardOptionsCanvas.updateText = function()
        desc:SetText(SettingsDialog.resolveOptionsLocaleText("panelDesc"))
        launchBtn.label:SetText(SettingsDialog.resolveOptionsLocaleText("panelOpen"))
        ns.UIKit:FitFontString(launchBtn.label, 212, 1)
        hint:SetText(SettingsDialog.resolveOptionsLocaleText("panelHint"))
    end
    BlizzardOptionsCanvas:SetScript("OnShow", BlizzardOptionsCanvas.updateText)
    BlizzardOptionsCanvas.updateText()

    compat.AddOptionsCategory(BlizzardOptionsCanvas)
end

EventDispatcher:attachEvent("VARIABLES_LOADED", function()
    SettingsDialog.syncTooltipLocale()
    SettingsDialog.registerBlizzardOptions()
end)

-----------------------------------------------------------------------------
-- EzWoW Tooltip
-----------------------------------------------------------------------------
SLASH_EZWOWTOOLTIP1 = "/ezt"
SLASH_EZWOWTOOLTIP2 = "/et"
SLASH_EZWOWTOOLTIP3 = "/ezwowtooltip"
SLASH_EZWOWTOOLTIP4 = "/eztooltip"
SLASH_EZWOWTOOLTIP5 = "/툴팁"

function SlashCmdList.EZWOWTOOLTIP(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "reset" then
        SettingsDialog.resetAllToDefaults()
    elseif msg == "debug" then
        addon.debugNextUnit = true
        print("|cffAEE26AEzWoW - Tooltip:|r hover over a player or NPC to print their tooltip lines.")
    elseif msg == "static" or msg == "anchor" then
        SettingsDialog.switchStaticMover()
    elseif msg:match("^lang") then
        local arg = msg:match("^%S+%s+(%S+)")
        local normalizeFullwidthCodepoint = arg and LANG_ALIASES[arg]
        if not normalizeFullwidthCodepoint then
            print("|cffAEE26AEzWoW - Tooltip:|r /ezt lang auto | ko | en | de | fr | es | ru | cn | tw")
            return
        end
        addon.db.general.language = normalizeFullwidthCodepoint
        SettingsDialog.syncTooltipLocale()
        if configFrame and configFrame.updateLabels then configFrame.updateLabels() end
        print("|cffAEE26AEzWoW - Tooltip:|r " .. SettingsDialog.resolveOptionsLocaleText("language") .. " = " .. normalizeFullwidthCodepoint .. " (" .. SettingsDialog.resolveCurrentLangCode() .. ")")
    else
        SettingsDialog.launchConfigWindow()
    end
end
