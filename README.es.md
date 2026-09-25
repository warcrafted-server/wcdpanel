# wcdpanel

*[English version](README.md)*

Addon de información para World of Warcraft: Wrath of the Lich King (3.3.5a, cliente en
castellano). Dibuja barras configurables en la parte de arriba o abajo de la pantalla (o sueltas,
donde quieras), cada una con sitio para localización, bolsas, durabilidad, misiones, oro, reloj,
volumen, correo, profesiones y los iconos de tus otros addons: todo lo que hoy amontonas alrededor
del minimapa, pero ordenado y sin taparlo.

Está inspirado en TitanPanel, pero escrito desde cero: es un addon nuevo, no un parche sobre
Titan, y no requiere tenerlo instalado. La licencia de Titan prohíbe redistribuir versiones
modificadas suyas, así que aquí no hay ni una línea de su código; solo se reutiliza el mismo
patrón de "barra con plugins" que ya conoces.

## Instalación

Copia la carpeta del repositorio dentro de `World of Warcraft/Interface/AddOns/` con el nombre
`wcdpanel` (no `wcdpanel-main` ni similar) y actívalo en la lista de AddOns de la pantalla de
selección de personaje.

## Primer vistazo

Al entrar por primera vez con un personaje aparece ya una barra arriba, con esta disposición:

- **Izquierda**: localización, bolsas, durabilidad, misiones, oro, tipo de saqueo, XP descansada,
  tiempo estimado para subir de nivel, hermandad, rendimiento y un icono por cada profesión que
  tengas aprendida.
- **Derecha**: reloj, volumen, correo, el botón para autoocultar la barra y, detrás, los iconos de
  tus propios addons (los que usan LibDataBroker y los que ponen un botón suelto en el minimapa).

Todo eso es configurable desde el primer momento: qué se muestra, dónde y con qué aspecto. No hay
que editar nada a mano para empezar a cambiarlo.

## Moverlo todo

Con las barras desbloqueadas (`/wcd lock` o la casilla "Bloquear todas las barras" en las
opciones), cualquier elemento se puede arrastrar: suéltalo sobre otra barra, o sobre el tercio
izquierdo/central/derecho de la misma barra, para cambiarlo de sitio. El propio fondo de una barra
"libre" (no anclada arriba ni abajo) también se arrastra, para colocarla en cualquier parte de la
pantalla.

El clic derecho, tanto sobre un elemento como sobre el fondo de una barra, abre un menú con las
opciones más habituales: quitar de la barra, moverlo a otra, bloquear, autoocultar... Sin tener
que pasar por el panel de opciones para lo del día a día.

## Barras

No hay límite de barras. `/wcd bar add top|bottom|free` crea una nueva (o el botón "Añadir barra"
en las opciones); `/wcd bar del <n>` la borra. Cada barra tiene su propio nombre, altura, escala,
opacidad, color de fondo, si se oculta en combate y si se autooculta al apartar el ratón. Las
barras ancladas arriba o abajo (`top`/`bottom`) pueden además desplazar la interfaz de Blizzard
(el marco del personaje, el minimapa, la barra de acción...) para que no queden tapados; las
barras `free` se colocan donde quieras y no mueven nada.

## Todos tus addons, en la barra

Dos plugins se encargan de que el minimapa deje de ser un cementerio de iconos:

- **LDB**: cualquier addon que use LibDataBroker (marcadores de misiones, calendarios,
  contadores de oro...) aparece automáticamente como un elemento más de la barra, con su icono,
  su texto y su propio tooltip y menú. Los "lanzadores" (los que solo abren una ventana al hacer
  clic) se pueden mostrar solo con icono para ahorrar sitio.
- **MinimapButtons**: recoge los botones sueltos que algunos addons ponen pegados al minimapa
  (los que no usan LibDataBroker) y los coloca igual, en un icono de tamaño uniforme, sin tocar
  su clic ni su función. Cada botón se puede "recoger" o dejar en el minimapa por separado, desde
  las opciones del plugin.

Ambos se pueden desactivar si prefieres seguir con los iconos en el minimapa.

## Profesiones

Un icono por cada profesión que tengas aprendida (incluida la Forja de runas de los caballeros de
la muerte), colocado ya en la barra desde el principio. Van solo con icono para no ocupar espacio:
pasa el ratón por encima para ver el nivel, y haz clic para lanzar la acción principal de esa
profesión (fundir, buscar hierbas, abrir la hoguera de cocina...); mayús+clic da la acción
secundaria en las que la tienen. Si no hay clic con sentido para una profesión (como Desuello),
el icono se limita a informar.

## Perfiles

La configuración se guarda por perfil de cuenta (AceDB), así que puedes compartir la misma barra
entre todos tus personajes o darle un perfil propio a uno en concreto, desde la pestaña Perfiles
de las opciones.

## Opciones

`/wcd` abre el panel completo (también disponible desde Interfaz ▸ AddOns): general (separación
entre elementos, tamaño de icono...), una sección por barra, una sección por plugin (activarlo,
sus opciones propias y dónde va colocado cada uno de sus elementos) y los perfiles.

Comandos sueltos, para no tener que abrir el panel: `/wcd lock` bloquea o desbloquea todas las
barras; `/wcd bar add top|bottom|free` y `/wcd bar del <n>` crean o borran una barra; `/wcd bar`
lista las que hay.

## Escribir un plugin propio

`docs/PLUGIN_API.md` explica la API completa con un ejemplo mínimo. La idea general: un plugin
registra uno o varios elementos (`WCDPanel:NewPlugin`), cada uno con su icono, su texto y sus
callbacks de clic y tooltip; wcdpanel se encarga de colocarlo, moverlo, guardar su posición y
mostrarlo en las opciones.

## Estado

En desarrollo. Consulta `CHANGELOG.md` para ver qué se ha corregido y añadido en cada revisión.
