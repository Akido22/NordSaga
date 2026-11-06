# Эффекты

Листы `x1/*.png`, `x2/*.png` и `fx.json` выгружает `tools/export_fx.mjs` из
[pixelfx](https://github.com/patch-gg/pixelfx) (MIT, лицензия — `LICENSE-pixelfx.txt`;
часть эффектов pixelfx основана на Sprite Fusion, Copyright (c) 2026 Hugo Duprez, MIT).
Эффекты перекрашены под палитру игры. Снег (`scripts/world/weather.gd`) — рецепт
`weather/snow` из pixelfx, переписанный на GDScript.

Выгрузить заново (нужен Node.js и клон pixelfx):
```
git clone https://github.com/patch-gg/pixelfx <папка>
node tools/export_fx.mjs <папка> [slash hit stunned]
```
Новый эффект — добавить запись в `FX` в `tools/export_fx.mjs`, выгрузить и вызвать
`world.effects.play("имя", x, y, отражён)` (точка — у ног) или `FxSheets.draw(...)`.
