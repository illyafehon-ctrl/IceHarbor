# Нові матеріали та шрифти

Проєктні файли:
- `textures/winter_terrain_atlas.png` — новий квадратний атлас: сніг, потрісканий лід, зимова трава/мох, земля/гравій. Створений вбудованою генерацією зображень (ImageGen) для цієї гри. Оригінальний атлас скопійований у проєкт без обрізання або зміни зображення.
- `Ground.gdshader` — вибирає чверті атласу, змішує матеріали природними плямами, формує засніжені краї та прохід. Кожна зона має власну суміш і візерунок. Це не чотири окремі фотофайли: використовується один атлас матеріалів.
- `Grass.gdshader` — рух об'ємної трави, її відтінки й освітлення.
- `fonts/DejaVuSans.ttf`, `fonts/DejaVuSerif-Bold.ttf` — вбудовані шрифти з підтримкою української. Ліцензія додається в `fonts/LICENSE.txt`.
- `ArtTheme.gd` — спільне оформлення тексту.

Точний запит до вбудованої генерації зображень:

> Use case: stylized-concept. Asset type: a single square 2 by 2 material texture atlas for a polished mobile 3D winter fishing game. Four equal quadrants fill the entire image with no margins, labels, dividers, objects or perspective. Top left quadrant: powder snow, creamy white and pale cool blue, granular fluffy snow with gentle wind-carved ripples, low contrast. Top right: frozen blue-grey ground ice, translucent milky glacial surface with fine branching white cracks and faint trapped bubbles, low contrast. Bottom left: dense small grass, moss and short winter grass in muted sage, olive and golden beige, scattered tiny blades, painterly natural detail. Bottom right: warm earth and tiny rounded gravel, muted russet tan and grey, packed soil with subtle pebble grains. Each quadrant is an orthographic flat overhead physically plausible albedo surface, even diffuse illumination, crisp organic detail, slightly hand-painted premium game art rather than pixel art. All textures at consistent small material scale. No large rocks, no scenery, no casts shadows, no highlights baked as directional lighting, no text, no borders. Four precisely equal edge-aligned square panels. High resolution square atlas.

Попередні матеріали дерева, одягу, шкіри рюкзаків, кори, магазину, води та льоду, а також портрети команди залишені в архіві. Нові поверхні доповнюють їх. Ці матеріали не вилучені з відео і не є оригінальними файлами Whiteout Survival.

## Додані звук і світові написи
`fonts/DejaVuSans-Bold.ttf` використовується для жирних написів над крижинами, магазином і переходами зон. Його охоплює додана ліцензія DejaVu. Кроки `step.wav`, `step_2.wav`, `step_3.wav` та удари `ice.wav`, `ice_2.wav`, `ice_3.wav` синтезовано для цієї гри. `music.wav` — власний 32-секундний інструментальний цикл із теплими акордами й м'якими нотами, створений програмно; це не сторонній музичний запис і не аудіо з відео. Змішування категорій виконується у `GameAudio.gd`, спільний інтерфейс — `SoundSettings.gd`.


Оновлення 20 зон: тематичні декорації, кухні та страви створені програмно. Використано наявні текстури дерева, магазину, льоду та зимового ґрунту з новими кольоровими варіантами. Три звуки кроків синтезовано з фільтрованого шуму та тихого низького тону; сторонні записи не використовувалися.


## Мультяшне оновлення
Вбудована генерація зображень (image_gen), без API/CLI: `textures/cartoon_terrain_atlas.png` та `icons/portraits_cartoon.png`. Обидва оригінали включені у проєкт. Покриття вибирається шейдером із чотирьох частин атласу; портрети показуються через AtlasTexture. Моделі NPC, риби, вода, тріщини льоду та матеріали предметів виконані кодом Godot.

Промпт покриття:
Use case: stylized-concept. Asset type: seamless game terrain texture atlas, one square image split into exactly four equally sized square quadrants, edge to edge with no padding, no labels, no lettering, no objects, top-down orthographic flat albedo materials. Top left: soft clean ivory snow with very subtle large rounded pale blue shaded drifts. Top right: turquoise cartoon glacier ice, large clean irregular ice plates with a few smooth white cracks. Bottom left: mint sage cartoon grass made of broad soft rounded patches with very sparse simple brush blade marks. Bottom right: warm apricot sandy ground with broad smooth peach color variation. Cozy mobile tycoon game aesthetic, hand painted clean simplified cartoon textures, pastel colors, broad shapes, extremely low fine-detail noise, no photographic detail, no grain, no 3D perspective, no border, no drop shadows. Each quadrant must be usable alone as a surface repeating across a 3D game island, no furniture, no scenery.

Промпт портретів:
Use case: stylized-concept. Asset: one game UI portrait atlas containing exactly THREE equal-width vertical columns side by side, edge to edge, no text or borders. Three friendly simplified cozy mobile fishing tycoon NPCs rendered as smooth rounded toy-like low-detail cartoon 3D figures, big simple heads and small stocky bodies, mitten hands, round eyes, soft clean colors, no fabric weave or realistic fur or tiny details. Left column: fisherman in warm golden yellow winter coat, cream scarf and matching round cap, brown backpack, holding a small ice pickaxe. Middle column: courier in sage mint winter coat and round cap, cream scarf, big brown delivery backpack, carrying a plate with a fish. Right column: seller in lavender winter coat and round cap, cream scarf, small brown backpack, holding a gold coin. Each figure centered in its own equal column, full body with comfortable margin, similar scale, three-quarter view showing friendly faces. Background flat pale blue in all three columns, same lighting and camera, simple clean illustration for small icons, no photorealism, no writing, no logos, no scenery. Wide landscape 3:1 composition.


Деталізоване оновлення: ToonOutline.gdshader, PaintedWood.gdshader, LogRings.gdshader — програмні матеріали, створені для цього проєкту. Деталі персонажів і трифазний замах інструментом створені кодом. Відео IMG_1932.MP4 використано як візуальний орієнтир; оригінальні активи з відео не витягалися.


Оновлення чіткості: ящики, ліхтарі, снігові шапки та ефект ZoneCelebration.gd створені програмно. Нові сторонні активи не додавалися.


Оновлення локацій: нові SVG меню/налаштувань, 20 тематичних композицій, п'ять ранніх орієнтирів, ShopSiding/ShopRoof/ShopGlass.gdshader створені кодом для проєкту. Зовнішні моделі та текстури не додавалися.

Лід: IceVisual.gdshader перероблений на три незмінні осередки радіальних тріщин, які розростаються за реальною втратою міцності. Нових зовнішніх текстур не додано.


Оновлення ходи й декорацій: PicnicCloth.gdshader, BarrelStaves.gdshader, GardenStone.gdshader створені програмно, як і лавки, прапорці та кашпо. Нова анімація процедурна, залежить від пройденої відстані та ваги вантажу; зовнішні анімаційні бібліотеки не використано.

Деталі костюмів, фактура тканини, додаткові візерунки землі, дерев, льоду й води створені програмно. Зовнішні текстури чи моделі для цього оновлення не використовувалися.

New coastlines, ground scatter, cloth weave, frost variation and gait phases are code-generated original game assets. No external reference textures or motion-capture data copied.

Wardrobe catalog, 2D clothing illustrations, original geometric clothing variants, expanded coastlines, biome ground clusters, fish scale/gill shader, ice layer/normal details and secondary gait motion were created in project code. No third-party clothing assets or motion capture were used.
