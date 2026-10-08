# Élysée 2027

App iOS sur les candidats à la présidentielle 2027 : profils, fonctions, réseaux, actus, vidéos, podcasts, posts Bluesky.

- `scripts/sync.mjs` reconstruit `data/candidats.json` (liste : Wikipédia ; enrichissement : Wikidata ; médias : Google Actualités, YouTube, Apple Podcasts, Bluesky). `npm run sync`, `npm test`.
- `.github/workflows/sync.yml` le relance toutes les 6 h. L'app embarque une copie et télécharge la dernière version au lancement.
- `./install.sh` : build + installation sur l'iPhone (XcodeGen). Icône : `swift tools/icon.swift Elysee/Assets.xcassets/AppIcon.appiconset/icon.png`.
- `YOUTUBE_API_KEY` (optionnel, secret GitHub) : ajoute les vidéos qui parlent du candidat, en plus de sa propre chaîne.
