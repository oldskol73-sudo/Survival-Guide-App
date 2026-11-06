# Wild Medicinal Plants: sources and licence basis

Library > Wild Medicinal Plants. Seven public-domain titles, downloaded one at a time from the Internet Archive (category `plants` in `assets/catalog/categories.json`, off by default, about 107 MB in all). The app ships none of them. Hashes are not pinned (trust on first use, like the other items); sizes are recorded.

## What each title gives you

| Title | Pictures | Names, habitat, description | Historical uses | Toxicity and look-alikes | Licence basis |
|---|---|---|---|---|---|
| Millspaugh, *Medicinal Plants* vol 1 and 2 (1892) | 180 colour plates | Yes: common and Latin names, range, botanical description | Yes, with history and preparation | Physiological and poisoning effects per plant; some look-alike notes | Published 1892, public domain |
| Henkel, *Wild Medicinal Plants of the US*, USDA Bulletin 89 (1906) | None | Names index: common and Latin names, family, habit, range, part used | Part used only | Marks poisonous plants only | US Government work |
| Henkel, *Weeds Used in Medicine*, Farmers' Bulletin 188 (1904) | Drawings | Yes, with gathering notes | Yes | Some cautions | US Government work |
| Chesnut, *Thirty Poisonous Plants of the US*, Farmers' Bulletin 86 (1898) | Drawings | Yes, with where each grows | Not the aim | Main subject: poisonous parts, effects, look-alike mistakes | US Government work |
| Marsh, *Stock-Poisoning Plants of the Range*, Bulletin 1245 (1924) | Plates and drawings | Yes | Not the aim | Main subject: identification and poisoning | US Government work |
| Densmore, *Uses of Plants by the Chippewa Indians*, Smithsonian BAE 44th Annual Report (1928) | 33 plates | Plant names (English, Ojibwe, Latin) | Documented traditional uses | Some | US Government publication, 1928 |

Gutenberg ebook 79110 (the link you gave) is a transcription of the Henkel 1906 bulletin. It is a names index with no pictures, so the catalog uses the Internet Archive scan of the same bulletin, which is a PDF and fits the app's reader and search. Gutenberg also discourages robot downloading.

## Honest gaps

- **No modern photographs.** The pictures are 1890s-1920s colour plates and line drawings. A modern photographic field guide that is free to redistribute does not exist in what I checked. The USDA PLANTS database has public-domain text, but its images are a mix of public domain and copyrighted, and it is a website, not a download.
- **Medicine is historical.** These books give doses and remedies that are out of date and sometimes unsafe. The screen says so in a boxed warning at the top.
- **The Densmore book records Ojibwe knowledge.** It is a public-domain government publication, but consider the cultural context in any marketing.
- **Not included:** the herbal books in the developer's own library (Herbal Materia Medica, Herb Formulas, and similar) have no verified licence. They stay out until each is checked.

## To refresh a hash later

Download the file, run `sha256sum`, put it in `sha256` in the catalog. The Internet Archive occasionally rebuilds derived PDFs, which is why the hashes are not pinned yet.
