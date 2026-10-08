// Synchronise la liste des candidats (Wikipédia) + enrichissement (Wikidata) + médias (news, YouTube, podcasts).
// Usage : node scripts/sync.mjs   (YOUTUBE_API_KEY optionnelle pour les vidéos qui parlent du candidat)
import { readFile, writeFile } from 'node:fs/promises';

const UA = { 'User-Agent': 'presidentielle-2027/0.1 (https://github.com/kameltovic/presidentielle-2027)' };
const OUT = new URL('../data/candidats.json', import.meta.url);
const WP = 'https://fr.wikipedia.org/w/api.php';

const SOURCES = [
  { page: "Candidatures à l'élection présidentielle française de 2027", section: 'Candidats déclarés', status: 'declare' },
  { page: "Candidatures à l'élection présidentielle française de 2027", section: 'Autres primaires', status: 'primaire', primary: 'Primaire de la droite' },
  { page: 'Primaire de la gauche unitaire de 2026', section: 'Déclarés', status: 'primaire', primary: 'Primaire de la gauche unitaire' },
  { page: 'Primaire présidentielle socialiste française de 2026', section: 'Candidats officiels', status: 'primaire', primary: 'Primaire socialiste' },
  { page: "Candidatures à l'élection présidentielle française de 2027", section: 'Candidats pressentis', status: 'pressenti' },
];

const getJSON = async (url) => {
  const r = await fetch(url, { headers: UA, signal: AbortSignal.timeout(20000) });
  if (!r.ok) throw new Error(`${r.status} ${url}`);
  return r.json();
};
const getText = async (url) => {
  const r = await fetch(url, { headers: UA, signal: AbortSignal.timeout(20000) });
  if (!r.ok) throw new Error(`${r.status} ${url}`);
  return r.text();
};
const wp = (params) => getJSON(`${WP}?${new URLSearchParams({ format: 'json', formatversion: '2', ...params })}`);

// ---------- Parsing wikitext ----------

/** Retire refs et modèles {{note}} (imbrication gérée par comptage d'accolades). */
function stripNoise(s) {
  s = s.replace(/<ref[^>]*\/>/g, '').replace(/<ref[^>]*>[\s\S]*?<\/ref>/g, '');
  let out = '';
  for (let i = 0; i < s.length; i++) {
    if (s.startsWith('{{note', i) || s.startsWith('{{Note', i)) {
      let depth = 0;
      for (; i < s.length; i++) {
        if (s.startsWith('{{', i)) { depth++; i++; } else if (s.startsWith('}}', i)) { depth--; i++; if (!depth) break; }
      }
      continue;
    }
    out += s[i];
  }
  return out;
}

/** Contenu d'une section, jusqu'au titre suivant (quel que soit son niveau). */
export function section(wikitext, title) {
  const m = wikitext.match(new RegExp(`^(=+)\\s*${title.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*\\1\\s*$`, 'm'));
  if (!m) return '';
  const rest = wikitext.slice(m.index + m[0].length);
  const end = rest.search(/^=+[^=]/m);
  return end === -1 ? rest : rest.slice(0, end);
}

const link = (s) => s?.match(/\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]+))?\]\]/);
const roleText = (s) => clean(s
  .replace(/\{\{Circonscription fr\|(\d+)\|([^}|]+)[^}]*\}\}/gi, '$1e circonscription de $2')
  .replace(/\{\{(\d+)e\}\}/g, '$1e')
  .replace(/\{\{[^{}]*\}\}/g, ''));
const clean = (s) => s.replace(/\[\[(?:[^\]|]*\|)?([^\]]*)\]\]/g, '$1').replace(/''+/g, '').replace(/<[^>]+>/g, '').trim();

/** Lignes d'un tableau wiki → objets candidat (champs structurés seulement, pas les commentaires libres). */
export function parseRows(text) {
  const rows = [];
  const hasCampaign = /Campagne/.test(text);
  for (const raw of text.split(/\n\|-/)) {
    const row = stripNoise(raw);
    const head = row.match(/^\s*!(?!\s*colspan)(.+)$/m)?.[1];
    if (!head) continue;
    const parts = head.split(/<br\s*\/?>/i);
    let name, wiki;
    const tri = parts[0].match(/\{\{TriNom\|([^|}]+)\|([^|}]+)(\|nolink=oui)?/);
    let sortName;
    if (tri) { name = `${tri[1].trim()} ${tri[2].trim()}`; wiki = tri[3] ? null : name; sortName = tri[2].trim(); }
    else { const l = link(parts[0]); if (!l) continue; wiki = l[1].trim(); name = (l[2] || l[1]).trim(); sortName = name.split(' ').slice(1).join(' ').replace(/^(?:de |d')/, ''); }
    const partyPart = parts.at(-1);
    const pl = link(partyPart);
    const party = clean(partyPart.split('/')[0]) || null;
    // Cellules : 1 photo, 2 couleur, 3 fonctions, 4 campagne (absente du tableau des pressentis).
    const cells = row.split(/\n\|(?!-)/);
    const file = (cell) => cell?.match(/\[\[(?:Fichier|File|Image):([^|\]]+)/i)?.[1].trim();
    const photo = file(cells[1]);
    const campaign = hasCampaign ? cells[4] : '';
    const birth = head.match(/\{\{Âge\|(\d+)\|(\d+)\|(\d{4})/);
    const slogan = campaign?.match(/(?:^|[^'])''([^'\n]{3,80})''(?!')/)?.[1];
    const roles = (cells[3] || '').split('\n').filter((l) => /^\*/.test(l)).map((l) => roleText(l.replace(/^\*+/, ''))).filter(Boolean);
    const colorCode = cells[2]?.match(/couleurs\|([^}|]+)/)?.[1].trim() ?? null;
    rows.push({
      name, wiki, sortName, roles, colorCode,
      party: party === name ? null : party,
      partyWiki: pl ? pl[1].trim() : null,
      photo: photo && !/replace this image/i.test(photo) ? photo : null,
      campaignLogo: file(campaign) || null,
      slogan: slogan && !/^aucune$/i.test(slogan.trim()) ? clean(slogan) : null,
      birth: birth ? `${birth[3]}-${birth[2].padStart(2, '0')}-${birth[1].padStart(2, '0')}` : null,
    });
  }
  return rows;
}

// ---------- Sondages (1er tour) ----------

const MONTHS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/** Cellule de tableau → texte sans attributs ; les liens deviennent «Cible». */
function cellText(cell) {
  let s = cell.replace(/\{\{blanc\|([^}]*)\}\}/gi, '$1').replace(/\{\{formatnum[:|]([^}]*)\}\}/gi, '$1').replace(/\{\{[^{}]*\}\}/g, '');
  s = s.replace(/\[\[([^\]|]+)(?:\|[^\]]*)?\]\]/g, '«$1»');
  // Attributs : « attr | contenu » — on garde ce qui suit le dernier « | » de premier niveau.
  const i = s.lastIndexOf('|');
  return (i === -1 ? s : s.slice(i + 1)).trim();
}
const num = (s) => { const m = s.match(/^\s*(?:'''|<[^>]+>|\s)*(\d+(?:[,.]\d+)?)/); return m ? parseFloat(m[1].replace(',', '.')) : null; };

/** Tableau des sondages du 1er tour → [{ pollster, date, sample, url, scores: [{ name: % }] }] (un objet par hypothèse). */
export function parsePolls(text, year) {
  const polls = [];
  for (const table of text.split(/\n\{\|/).slice(1)) {
    const rows = stripNoise(table.split(/\n\|\}/)[0]).split(/\n\|-[^\n]*/);
    // Ligne d'en-tête des noms : « ! … [[Nom complet|Court]] ».
    const head = rows.find((r) => /^!.*\[\[[^\]]+\|[^\]]+\]\]/m.test(r) && !/Fichier:/.test(r));
    if (!head) continue;
    const cols = head.split('\n').filter((l) => l.startsWith('!')).map((l) => l.match(/\[\[([^\]|]+)/)?.[1].trim() ?? 'Autres');
    if (!cols.includes('Autres')) cols.push('Autres');
    let current = null;
    for (const row of rows) {
      if (row.trim().startsWith('!')) continue;
      const cells = row.trim().split(/\n(?=\|)/).map((c) => c.replace(/^\|/, ''));
      let values = cells;
      if (cells.length > cols.length) {
        const [p, d, n] = cells;
        const date = [...cellText(d).matchAll(/(\d{1,2})(?:er)?\s+([a-zéû]+)/gi)].at(-1) ?? [, cellText(d).match(/\d{1,2}/)?.[0], cellText(d).match(/[a-zéû]{3,}/i)?.[0]];
        const month = MONTHS.findIndex((m) => m.startsWith(String(date[2]).toLowerCase().slice(0, 4)));
        current = {
          pollster: p.match(/\[https?:\S+\s+([^\]]+)\]/)?.[1].trim() ?? cellText(p),
          url: p.match(/\[(https?:\S+)/)?.[1] ?? null,
          date: month >= 0 ? `${year}-${String(month + 1).padStart(2, '0')}-${String(date[1]).padStart(2, '0')}` : null,
          sample: parseInt(cellText(n).replace(/\D/g, ''), 10) || null,
        };
        values = cells.slice(3);
      }
      if (!current || values.length !== cols.length) continue;
      const scores = {};
      values.forEach((cell, i) => {
        for (const part of cell.split(/<hr\s*\/?>/i)) {
          const v = num(cellText(part));
          // Un nom dans la cellule = candidat testé à la place de celui de la colonne.
          const name = part.match(/\[\[([^\]|]+)/)?.[1] ?? (cols[i] === 'Autres' ? null : cols[i]);
          if (v != null && name) scores[name.trim()] = v;
        }
      });
      if (Object.keys(scores).length >= 4) polls.push({ ...current, scores });
    }
  }
  return polls.filter((p) => p.date);
}

/** Tous les tableaux de la section « premier tour », l'année étant lue dans les titres. */
export function allPolls(wikitext) {
  const start = wikitext.search(/^==\s*Sondages concernant le premier tour\s*==/m);
  const end = wikitext.slice(start + 10).search(/^==[^=]/m);
  const body = wikitext.slice(start, end === -1 ? undefined : start + 10 + end);
  let year = null;
  return body.split(/^(?==+[^=])/m).flatMap((chunk) => {
    year = chunk.match(/^=+[^=\n]*?(\d{4})/)?.[1] ?? year;
    return year ? parsePolls(chunk, year) : [];
  });
}

/** Moyenne des hypothèses publiées dans les 30 jours précédant le dernier sondage + historique par sondage. */
export function aggregatePolls(polls) {
  const last = polls.map((p) => p.date).sort().at(-1);
  const from = new Date(Date.parse(last) - 30 * 864e5).toISOString().slice(0, 10);
  const recent = polls.filter((p) => p.date >= from);
  const by = {};
  for (const p of polls) {
    for (const [name, v] of Object.entries(p.scores)) {
      const o = (by[slugify(name)] ??= { values: [], history: {} });
      if (p.date >= from) o.values.push(v);
      (o.history[`${p.date}|${p.pollster}`] ??= []).push(v);
    }
  }
  const mean = (a) => Math.round((a.reduce((x, y) => x + y, 0) / a.length) * 10) / 10;
  const result = {};
  for (const [slug, o] of Object.entries(by)) {
    result[slug] = {
      avg: o.values.length ? mean(o.values) : null,
      min: o.values.length ? Math.min(...o.values) : null,
      max: o.values.length ? Math.max(...o.values) : null,
      n: o.values.length,
      history: Object.entries(o.history).map(([k, v]) => ({ date: k.split('|')[0], pollster: k.split('|')[1], value: mean(v) })).sort((a, b) => a.date.localeCompare(b.date)),
    };
  }
  // Classement : seulement les candidats testés dans au moins un quart des hypothèses récentes.
  Object.entries(result)
    .filter(([, r]) => r.n >= recent.length / 4)
    .sort((a, b) => b[1].avg - a[1].avg)
    .forEach(([, r], i) => (r.rank = i + 1));
  const meta = {
    from, to: last,
    polls: new Set(recent.map((p) => `${p.date}|${p.pollster}`)).size,
    hypotheses: recent.length,
    pollsters: [...new Set(recent.map((p) => p.pollster))],
    source: 'https://fr.wikipedia.org/wiki/Liste_de_sondages_sur_l%27%C3%A9lection_pr%C3%A9sidentielle_fran%C3%A7aise_de_2027',
  };
  return { meta, result };
}

export const slugify = (s) => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

/** Codes → couleurs du modèle « Infobox Parti politique français/couleurs » (ex. RN → #0D378A). */
export function partyColors(wikitext) {
  const out = {};
  let pending = [];
  for (const line of wikitext.split('\n')) {
    const m = line.match(/^\s*\|\s*([^=|<]+?)\s*(=\s*(.*))?$/);
    if (!m) continue;
    pending.push(m[1]);
    if (!m[2]) continue;
    const hex = m[3].match(/#[0-9a-f]{6}\b|#[0-9a-f]{3}\b/i)?.[0];
    if (hex) for (const code of pending) out[code] ??= hex;
    pending = [];
  }
  return out;
}

async function fetchCandidates() {
  const pages = {};
  const all = new Map();
  for (const src of SOURCES) {
    pages[src.page] ??= (await wp({ action: 'parse', page: src.page, prop: 'wikitext' })).parse.wikitext;
    for (const c of parseRows(section(pages[src.page], src.section))) {
      const slug = slugify(c.name);
      if (all.has(slug)) continue; // le premier statut (le plus avancé) gagne
      all.set(slug, { slug, ...c, status: src.status, primary: src.primary || null });
    }
  }
  return [...all.values()];
}

// ---------- Wikidata ----------

async function qids(titles) {
  const map = {};
  for (let i = 0; i < titles.length; i += 50) {
    const r = await wp({ action: 'query', titles: titles.slice(i, i + 50).join('|'), prop: 'pageprops', ppprop: 'wikibase_item', redirects: '1' });
    const norm = Object.fromEntries([...(r.query.normalized || []), ...(r.query.redirects || [])].map((n) => [n.to, n.from]));
    for (const p of r.query.pages) {
      if (!p.pageprops?.wikibase_item) continue;
      let t = p.title;
      while (norm[t]) t = norm[t];
      map[t] = p.pageprops.wikibase_item;
      map[p.title] = p.pageprops.wikibase_item;
    }
  }
  return map;
}

async function wikidata(ids) {
  if (!ids.length) return {};
  const q = `SELECT ?item ?web ?x ?yt ?bsky ?insta ?tiktok ?logo ?img WHERE {
    VALUES ?item { ${ids.map((i) => 'wd:' + i).join(' ')} }
    OPTIONAL { ?item wdt:P856 ?web } OPTIONAL { ?item wdt:P2002 ?x } OPTIONAL { ?item wdt:P2397 ?yt }
    OPTIONAL { ?item wdt:P12361 ?bsky } OPTIONAL { ?item wdt:P2003 ?insta } OPTIONAL { ?item wdt:P7085 ?tiktok }
    OPTIONAL { ?item wdt:P154 ?logo } OPTIONAL { ?item wdt:P18 ?img } OPTIONAL { ?item wdt:P465 ?color } }`;
  const r = await getJSON(`https://query.wikidata.org/sparql?format=json&query=${encodeURIComponent(q)}`);
  const out = {};
  for (const b of r.results.bindings) {
    const id = b.item.value.split('/').pop();
    const o = (out[id] ??= {});
    for (const k of ['web', 'x', 'yt', 'bsky', 'insta', 'tiktok', 'logo', 'img', 'color']) if (b[k] && !o[k]) o[k] = decodeURIComponent(b[k].value.split('/').pop());
  }
  return out;
}

/** URL redimensionnée + attribution (auteur, licence) pour chaque fichier. */
async function fileInfo(files) {
  const out = {};
  for (let i = 0; i < files.length; i += 50) {
    const r = await wp({ action: 'query', titles: files.slice(i, i + 50).map((f) => 'File:' + f).join('|'), prop: 'imageinfo', iiprop: 'url|extmetadata', iiurlwidth: '800', redirects: '1' });
    const norm = Object.fromEntries([...(r.query.normalized || []), ...(r.query.redirects || [])].map((n) => [n.to, n.from]));
    for (const p of r.query.pages) {
      const ii = p.imageinfo?.[0];
      if (!ii) continue;
      let t = p.title;
      while (norm[t]) t = norm[t];
      const m = ii.extmetadata || {};
      out[t.replace(/^(File|Fichier):/, '')] = {
        url: ii.thumburl || ii.url,
        page: ii.descriptionurl,
        author: clean(m.Artist?.value || '').slice(0, 120) || null,
        license: m.LicenseShortName?.value || null,
      };
    }
  }
  return out;
}

// ---------- Médias ----------

const decode = (s) => s.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, "'").trim();
const decodeEntities = (s) => s && s.replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n)).replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)));
const tag = (xml, t) => { const m = xml.match(new RegExp(`<${t}[^>]*>([\\s\\S]*?)</${t}>`)); return m ? decode(m[1]) : null; };

// Bing Actualités : image, extrait et lien direct vers l'article. Google Actualités en secours.
async function bingNews(name) {
  const q = new URLSearchParams({ q: `"${name}"`, format: 'rss', setlang: 'fr', cc: 'FR', mkt: 'fr-FR', qft: 'sortbydate="1"' });
  const xml = await getText(`https://www.bing.com/news/search?${q}`);
  return [...xml.matchAll(/<item>([\s\S]*?)<\/item>/g)].slice(0, 15).map(([, it]) => {
    const link = tag(it, 'link');
    const img = tag(it, 'News:Image');
    return {
      title: decodeEntities(tag(it, 'title')),
      url: new URL(link).searchParams.get('url') || link,
      source: decodeEntities(tag(it, 'News:Source') || '').replace(/ via MSN$/, '') || null,
      excerpt: decodeEntities(tag(it, 'description') || '') || null,
      image: img ? img.replace(/^http:/, 'https:') + '&w=800&h=450&c=14' : null,
      date: new Date(tag(it, 'pubDate')).toISOString(),
    };
  });
}

async function googleNews(name) {
  const xml = await getText(`https://news.google.com/rss/search?q=${encodeURIComponent(`"${name}"`)}&hl=fr&gl=FR&ceid=FR:fr`);
  return [...xml.matchAll(/<item>([\s\S]*?)<\/item>/g)].slice(0, 15).map(([, it]) => ({
    title: tag(it, 'title')?.replace(/ - [^-]+$/, ''),
    url: tag(it, 'link'),
    source: tag(it, 'source'),
    excerpt: null,
    image: null,
    date: new Date(tag(it, 'pubDate')).toISOString(),
  }));
}

async function news(name) {
  const bing = await bingNews(name).catch(() => []);
  return bing.length >= 5 ? bing : googleNews(name);
}

async function channelVideos(channelId) {
  const xml = await getText(`https://www.youtube.com/feeds/videos.xml?channel_id=${channelId}`);
  return [...xml.matchAll(/<entry>([\s\S]*?)<\/entry>/g)].slice(0, 8).map(([, e]) => ({
    id: tag(e, 'yt:videoId'), title: tag(e, 'title'), channel: tag(e, 'name'), date: new Date(tag(e, 'published')).toISOString(), own: true,
  }));
}

async function searchVideos(name) {
  if (!process.env.YOUTUBE_API_KEY) return [];
  const p = new URLSearchParams({ part: 'snippet', q: `"${name}"`, type: 'video', order: 'date', maxResults: '8', relevanceLanguage: 'fr', regionCode: 'FR', key: process.env.YOUTUBE_API_KEY });
  const r = await getJSON(`https://www.googleapis.com/youtube/v3/search?${p}`);
  return r.items.map((i) => ({ id: i.id.videoId, title: decode(i.snippet.title), channel: i.snippet.channelTitle, date: new Date(i.snippet.publishedAt).toISOString(), own: false }));
}

async function podcasts(name) {
  const fold = (t) => t.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  const p = new URLSearchParams({ term: name, media: 'podcast', entity: 'podcastEpisode', country: 'FR', limit: '30' });
  const r = await getJSON(`https://itunes.apple.com/search?${p}`);
  return r.results
    .filter((e) => fold(`${e.trackName} ${e.description || ''}`).includes(fold(name)))
    .sort((a, b) => b.releaseDate.localeCompare(a.releaseDate))
    .slice(0, 10)
    .map((e) => ({ title: e.trackName, show: e.collectionName, url: e.trackViewUrl, audio: e.episodeUrl || null, artwork: e.artworkUrl600 || null, date: new Date(e.releaseDate).toISOString(), duration: e.trackTimeMillis ? Math.round(e.trackTimeMillis / 60000) : null }));
}

// Bluesky : API publique, gratuite. (L'API X est payante : on se contente du lien vers le profil.)
async function blueskyPosts(handle) {
  const r = await getJSON(`https://public.api.bsky.app/xrpc/app.bsky.feed.getAuthorFeed?actor=${handle}&limit=10&filter=posts_no_replies`);
  return r.feed.filter((f) => !f.reason).slice(0, 6).map(({ post: p }) => ({
    text: p.record.text, image: p.embed?.images?.[0]?.thumb ?? p.embed?.external?.thumb ?? p.embed?.media?.images?.[0]?.thumb ?? null, date: new Date(p.record.createdAt).toISOString(), likes: p.likeCount, reposts: p.repostCount,
    url: `https://bsky.app/profile/${handle}/post/${p.uri.split('/').pop()}`,
  }));
}

/** Exécute fn sur chaque élément, 4 à la fois. */
async function pool(items, fn, n = 4) {
  const res = [];
  let i = 0;
  await Promise.all(Array.from({ length: n }, async () => { while (i < items.length) { const k = i++; res[k] = await fn(items[k]); } }));
  return res;
}

// ---------- Main ----------

async function main() {
  const prev = JSON.parse(await readFile(OUT, 'utf8').catch(() => '{"candidats":[]}'));
  const prevBySlug = Object.fromEntries(prev.candidats.map((c) => [c.slug, c]));

  const cands = await fetchCandidates();
  const declared = cands.filter((c) => c.status !== 'pressenti').length;
  // Garde-fou : un tableau Wikipédia cassé/vandalisé ne doit pas vider le site.
  if (declared < 10) throw new Error(`Seulement ${declared} candidats déclarés parsés — Wikipédia a changé de format ? Données conservées.`);

  const { meta: polls, result: pollBySlug } = aggregatePolls(allPolls((await wp({ action: 'parse', page: "Liste de sondages sur l'élection présidentielle française de 2027", prop: 'wikitext' })).parse.wikitext));
  for (const c of cands) c.poll = pollBySlug[c.slug] ?? null;
  console.log(`Sondages : ${polls.polls} sondages (${polls.hypotheses} hypothèses) du ${polls.from} au ${polls.to}`);

  const colors = partyColors((await wp({ action: 'parse', page: 'Modèle:Infobox Parti politique français/couleurs', prop: 'wikitext' })).parse.wikitext);

  const titles = [...new Set(cands.flatMap((c) => [c.wiki, c.partyWiki]).filter(Boolean))];
  const qmap = await qids(titles);
  const wd = await wikidata([...new Set(Object.values(qmap))]);

  for (const c of cands) {
    const p = wd[qmap[c.wiki]] || {};
    const party = wd[qmap[c.partyWiki]] || {};
    c.qid = qmap[c.wiki] || null;
    c.photo ??= p.img || null;
    c.partyLogo = party.logo || null;
    c.partyColor = colors[c.colorCode] ?? (party.color ? `#${party.color}` : null);
    c.links = { site: p.web ? decodeURI(p.web) : null, x: p.x || null, youtube: p.yt || null, bluesky: p.bsky || null, instagram: p.insta || null, tiktok: p.tiktok || null };
  }

  const files = [...new Set(cands.flatMap((c) => [c.photo, c.campaignLogo, c.partyLogo]).filter(Boolean))];
  const info = await fileInfo(files);
  for (const c of cands) for (const k of ['photo', 'campaignLogo', 'partyLogo']) c[k] = c[k] && info[c[k]] ? { file: c[k], ...info[c[k]] } : null;

  // Une source média en panne ne vide pas les données de la veille.
  const keep = async (c, key, fn) => { try { return await fn(); } catch (e) { console.warn(`  ⚠ ${c.name} ${key}: ${e.message}`); return prevBySlug[c.slug]?.[key] || []; } };
  await pool(cands, async (c) => {
    c.news = await keep(c, 'news', () => news(c.name));
    const own = c.links.youtube ? await keep(c, 'videos', () => channelVideos(c.links.youtube)) : [];
    const about = await keep(c, 'videos', () => searchVideos(c.name));
    c.videos = [...own, ...about.filter((v) => !own.some((o) => o.id === v.id))].sort((a, b) => b.date.localeCompare(a.date));
    c.posts = c.links.bluesky ? await keep(c, 'posts', () => blueskyPosts(c.links.bluesky)) : [];
    c.podcasts = await keep(c, 'podcasts', () => podcasts(c.name));
    console.log(`✓ ${c.name} — ${c.news.length} actus, ${c.videos.length} vidéos, ${c.podcasts.length} podcasts, ${c.posts.length} posts`);
  });

  const before = new Set(Object.keys(prevBySlug));
  const after = new Set(cands.map((c) => c.slug));
  const added = [...after].filter((s) => !before.has(s));
  const removed = [...before].filter((s) => !after.has(s));
  if (added.length || removed.length) console.log(`Changements de liste : +[${added}] -[${removed}]`);

  cands.sort((a, b) => a.sortName.localeCompare(b.sortName, 'fr'));
  await writeFile(OUT, JSON.stringify({ updatedAt: new Date().toISOString(), polls, candidats: cands }, null, 1) + '\n');
  console.log(`${cands.length} candidats écrits dans data/candidats.json`);
}

if (import.meta.url === `file://${process.argv[1]}`) main().catch((e) => { console.error(e); process.exit(1); });
