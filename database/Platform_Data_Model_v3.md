# Platform — Complete Data Model (v3, definitive)

*The whole platform, modelled from the brainstorm — the loop, the two layers, the connective systems — not just the garden manual's fields. Supersedes the v1 spec and v2 model. Same non-breaking rules: additive only (`CREATE TABLE IF NOT EXISTS`), RLS + grants per the v1 pattern, hidden pages, reversible, staging-first. The garden manual is one input here (garden reference data); the model also covers the kitchen, drinks, the learning layer, personalisation, and trust — everything we mapped.*

Legend: **(exists)** = already in your app · **(new)** = to add. Existing tables are referenced, never redefined.

---

## 1. Foundation — shared by everything

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Controlled vocabularies (replace loose text everywhere)
CREATE TABLE IF NOT EXISTS public.cat_high_level     (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text, definition text);
CREATE TABLE IF NOT EXISTS public.cat_main           (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text, definition text);
CREATE TABLE IF NOT EXISTS public.garden_layers      (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text, description text);
CREATE TABLE IF NOT EXISTS public.growth_habits      (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text, description text);
CREATE TABLE IF NOT EXISTS public.lifecycles         (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text, traits text);
CREATE TABLE IF NOT EXISTS public.soil_types         (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text, ph_low numeric, ph_high numeric);
CREATE TABLE IF NOT EXISTS public.sunlight_levels    (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text, hours text);
CREATE TABLE IF NOT EXISTS public.seed_saving_groups (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), grp smallint UNIQUE, name text, notes text);
CREATE TABLE IF NOT EXISTS public.ease_ratings       (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), score smallint UNIQUE, name text, definition text);

-- Location cascade (the only location machinery; one warm zone for now)
CREATE TABLE IF NOT EXISTS public.climate_zones (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text);
CREATE TABLE IF NOT EXISTS public.regions       (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text, climate_zone_id uuid REFERENCES climate_zones(id), is_active boolean DEFAULT true);

-- Media (images, polymorphic, with credit + licence) → Supabase bucket 'garden-media'
CREATE TABLE IF NOT EXISTS public.media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), bucket_path text NOT NULL,
  alt_text text, credit text, license text,
  entity_type text, entity_id uuid, is_primary boolean DEFAULT false
);

-- Tags / cross-links (search, "related", connecting plant↔ingredient↔drink↔lesson)
CREATE TABLE IF NOT EXISTS public.tags (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text);
CREATE TABLE IF NOT EXISTS public.entity_tags (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tag_id uuid REFERENCES tags(id), entity_type text, entity_id uuid);
```

---

## 2. Garden — grow *(new)*

**`plants`** — location-invariant profile (Sections 1, 2, 5, 6, 7, 8, 10), FKs to the lookups. Columns grouped by your profile section so coverage is verifiable:

```sql
CREATE TABLE IF NOT EXISTS public.plants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE NOT NULL,
  -- S1 identity:  common_name, botanical_name, subspecies, taxonomic_authority,
  --   plant_family, plant_type, genetic_lineage_type, variety_cultivar, origin,
  --   size_height, size_spread + FKs: high_level_category_id, main_category_id,
  --   growth_habit_id, garden_layer_id
  -- S2 lifecycle: root_invasiveness, senescence_behaviour, suckering_behaviour,
  --   growth_rate + FKs: lifecycle_id, ease_rating_id
  -- S5 propagation (17): pollination_requirements/type, flowering_season,
  --   propagation_details/methods/timing/depth/sowing/transplanting,
  --   germination_time, rootstock, years_to_first_harvest, time_to_harvest,
  --   planting_windows, pollination_isolation, seed_purity_risk, isolation_methods
  -- S6 harvest (10): harvest_season, harvesting_method, yield_per_plant,
  --   storage_methods, shelf_life, seed_storage_procedures/parameters,
  --   seed_retest_interval, regeneration_frequency + FK seed_saving_group_id
  -- S7 human use (9): edible_parts, culinary_applications, medicinal_parts,
  --   medicinal_systems, toxic_parts, ayurvedic_classification, functional_uses,
  --   cultural_uses, nutritional_composition
  -- S8 ecology (4): wildlife_attraction, erosion_control, carbon_sequestration,
  --   ecological_integration
  -- S10 + housekeeping:
  common_name text NOT NULL, botanical_name text, care_summary text,
  is_published boolean DEFAULT false,
  created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now()
  -- (all section fields above are real columns; abbreviated here for length)
);

-- Morphology made data: which parts exist + their role (edible/medicinal/toxic/used)
CREATE TABLE IF NOT EXISTS public.plant_parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), plant_id uuid REFERENCES plants(id) ON DELETE CASCADE,
  part text,                       -- root, stem, leaf, flower, fruit, seed, bud...
  role text,                       -- edible, medicinal, toxic, functional, ornamental
  notes text
);
```

**Cascade — region-varying content (Sections 3, 4, 9):**

```sql
CREATE TABLE IF NOT EXISTS public.plant_climate_care (   -- S3 + S4, Core/Risk/Fix per zone
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), plant_id uuid REFERENCES plants(id) ON DELETE CASCADE,
  climate_zone_id uuid REFERENCES climate_zones(id),
  field_key text NOT NULL,   -- climate, soil, ph, sunlight, wind, water, frost, seasonal_risk,
                             -- planting_distance, fertilisation, mulching, pruning,
                             -- special_care, tools, rotation, pest_mgmt, disease_notes
  core text, risk text, fix text, value text,
  UNIQUE (plant_id, climate_zone_id, field_key)
);
CREATE TABLE IF NOT EXISTS public.plant_culture (        -- S9 per region (sparse)
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), plant_id uuid REFERENCES plants(id) ON DELETE CASCADE,
  region_id uuid REFERENCES regions(id),
  local_name text, placement_status text, beliefs_restrictions text,
  planting_protocol text, location_cautions text, symbolism text, modern_context text,
  UNIQUE (plant_id, region_id)
);
```

**Relationships + scheduling:**

```sql
CREATE TABLE IF NOT EXISTS public.plant_companions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id uuid REFERENCES plants(id) ON DELETE CASCADE,
  other_plant_id uuid REFERENCES plants(id) ON DELETE CASCADE,
  relationship text CHECK (relationship IN ('companion','incompatible')), reason text,
  UNIQUE (plant_id, other_plant_id)
);
CREATE TABLE IF NOT EXISTS public.plant_calendar (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id uuid REFERENCES plants(id) ON DELETE CASCADE,
  climate_zone_id uuid REFERENCES climate_zones(id),
  activity text CHECK (activity IN ('sow','transplant','plant','harvest','prune')),
  month_start smallint, month_end smallint, notes text
);
```

---

## 3. Garden — design & map *(new)*  ("where to plant what")

```sql
-- Reusable guilds / polycultures (named plant groupings)
CREATE TABLE IF NOT EXISTS public.guilds (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text, description text);
CREATE TABLE IF NOT EXISTS public.guild_members (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), guild_id uuid REFERENCES guilds(id), plant_id uuid REFERENCES plants(id), role text);
-- Zones 0–5 as reference; actual placed maps live in personalisation (§7)
CREATE TABLE IF NOT EXISTS public.zone_definitions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), zone smallint UNIQUE, name text, description text);
```

---

## 4. Ecosystem — protect *(new)*  (pests, diseases, beneficials, **fungi, soil life**)

```sql
CREATE TABLE IF NOT EXISTS public.organisms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text, scientific_name text,
  kind text CHECK (kind IN ('pest','disease','beneficial','pollinator','fungus','soil_life')),
  description text, is_published boolean DEFAULT false
);
CREATE TABLE IF NOT EXISTS public.plant_organisms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id uuid REFERENCES plants(id) ON DELETE CASCADE,
  organism_id uuid REFERENCES organisms(id) ON DELETE CASCADE,
  relationship text CHECK (relationship IN ('pest_of','disease_of','attracts','controlled_by')),
  notes text, UNIQUE (plant_id, organism_id, relationship)
);
```

---

## 5. The hinge — plant ↔ kitchen

```sql
CREATE TABLE IF NOT EXISTS public.plant_ingredients (   -- → existing ingredients table
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id uuid REFERENCES plants(id) ON DELETE CASCADE,
  ingredient_id uuid REFERENCES public.ingredients(id) ON DELETE CASCADE,
  part text, is_primary boolean DEFAULT true,
  UNIQUE (plant_id, ingredient_id, part)
);
```

---

## 6. Kitchen & drinks

- **`ingredients`, `submitted_recipes`, `collections`, `pantry`, grocery** — *(exists)*. Reused, not redefined.

```sql
-- Preserve *(new)*
CREATE TABLE IF NOT EXISTS public.preservation_methods (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text, description text, safety_notes text);
CREATE TABLE IF NOT EXISTS public.ingredient_preservation (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), ingredient_id uuid REFERENCES public.ingredients(id), method_id uuid REFERENCES preservation_methods(id), notes text);

-- Drink — beverages & cocktails *(new)*
CREATE TABLE IF NOT EXISTS public.drinks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, name text,
  kind text CHECK (kind IN ('cocktail','wine','spirit','infusion','tea','cordial','juice')),
  body text, is_published boolean DEFAULT false
);
CREATE TABLE IF NOT EXISTS public.drink_ingredients (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), drink_id uuid REFERENCES drinks(id) ON DELETE CASCADE, ingredient_id uuid REFERENCES public.ingredients(id), amount text);
CREATE TABLE IF NOT EXISTS public.pairings (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), drink_id uuid REFERENCES drinks(id), recipe_id uuid, note text);
```

---

## 7. Learning layer — the platform's reason to exist *(new)*

The part the brainstorm was really about: not data, but *teaching*.

```sql
CREATE TABLE IF NOT EXISTS public.topics (        -- concepts: morphology, anatomy, soil food web,
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),  -- photosynthesis, fermentation, distillation, IPM...
  slug text UNIQUE, name text, summary text, parent_topic_id uuid REFERENCES topics(id)
);
CREATE TABLE IF NOT EXISTS public.lessons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, title text, body text,
  topic_id uuid REFERENCES topics(id), chapter_ref text,     -- e.g. 'manual.3'
  difficulty text CHECK (difficulty IN ('start','core','deep')),  -- pedagogy / progression
  is_published boolean DEFAULT false, created_at timestamptz DEFAULT now()
);
CREATE TABLE IF NOT EXISTS public.learning_paths (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), slug text UNIQUE, title text, description text);
CREATE TABLE IF NOT EXISTS public.path_steps (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), path_id uuid REFERENCES learning_paths(id) ON DELETE CASCADE, lesson_id uuid REFERENCES lessons(id), step_order smallint);
-- link a lesson to ANY entity (plant, organism, ingredient, drink)
CREATE TABLE IF NOT EXISTS public.lesson_links (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), lesson_id uuid REFERENCES lessons(id) ON DELETE CASCADE, entity_type text, entity_id uuid);
```

---

## 8. Personalisation — My Garden / My Kitchen *(new + extends existing)*

What turns a library into *their* companion, and feeds the seasonal engine.

```sql
CREATE TABLE IF NOT EXISTS public.user_plants (   -- what a user actually grows
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  plant_id uuid REFERENCES plants(id),
  status text CHECK (status IN ('planned','growing','harvesting','done')),
  planted_at date, bed_label text, notes text
);
CREATE TABLE IF NOT EXISTS public.user_regions (  -- a user's resolved location → cascade
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  region_id uuid REFERENCES regions(id)
);
CREATE TABLE IF NOT EXISTS public.garden_journal ( -- extends your existing diary concept
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  entry_date date, body text, user_plant_id uuid REFERENCES user_plants(id), media_id uuid REFERENCES media(id)
);
-- pantry, grocery, family_profiles, household → (exists), reused
```

---

## 9. Trust & safety *(new)*  — non-negotiable for a free teaching platform

```sql
-- Review/verification status, applied to any content entity
CREATE TABLE IF NOT EXISTS public.content_review (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text, entity_id uuid,
  status text CHECK (status IN ('draft','in_review','verified','flagged')),
  reviewer_id uuid REFERENCES auth.users(id), verified_at timestamptz, note text
);
-- Sources / citations behind a claim (authority for the learning layer)
CREATE TABLE IF NOT EXISTS public.sources (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), entity_type text, entity_id uuid, title text, author text, url text);
-- Explicit safety flags surfaced to users (toxicity, foraging, preserving, alcohol)
CREATE TABLE IF NOT EXISTS public.safety_flags (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), entity_type text, entity_id uuid, flag text, message text);
```

---

## 10. Cross-cutting — seasonal engine & search (no new tables, derived)

- **"What now, here?"** is a *query*, not a table: `plant_calendar ⋈ climate_zones ⋈ user_regions ⋈ user_plants`, filtered to the current month. Build it as a Postgres view or RPC once the tables above exist — it needs no storage of its own.
- **Search / related** rides on `tags` + `entity_tags` + the relationship tables. Everything is already linkable.

---

## Coverage map — against the brainstorm board (not the manual)

| Brainstorm element | Modelled by |
|---|---|
| Design & map | `guilds`, `guild_members`, `zone_definitions`, `garden_layers` |
| Grow (250 profiles) | `plants` + lookups + `plant_parts` |
| Grow — region-varying | `plant_climate_care`, `plant_culture` (cascade) |
| Protect (pests/beneficials/fungi/soil) | `organisms`, `plant_organisms` |
| Ingredient hinge | `plant_ingredients` → existing `ingredients` |
| Companion planting | `plant_companions` |
| Seasonal calendar | `plant_calendar` (+ §10 view) |
| Preserve | `preservation_methods`, `ingredient_preservation` |
| Cook | existing `ingredients`/`recipes`/`pantry`/grocery |
| Drink (beverages & cocktails) | `drinks`, `drink_ingredients`, `pairings` |
| Gather & serve | existing events/table-planner/household |
| Learning layer (morphology, anatomy, manual, lessons) | `topics`, `lessons`, `learning_paths`, `path_steps`, `lesson_links` |
| Location cascade | `climate_zones`, `regions`, `user_regions` |
| My Garden / My Kitchen | `user_plants`, `garden_journal` + existing pantry/grocery |
| Search & cross-linking | `tags`, `entity_tags` |
| Community & review | `content_review` |
| Safety & trust | `safety_flags`, `sources`, `content_review` |
| Images / media | `media` + `garden-media` bucket |

Every node on the loop and every connective system has a home. Nothing here is sourced only from the manual.

---

## Build, incrementally — design stays whole

Run the migration (all tables), then seed one plant end-to-end (the v1 slice). Because the full shape exists from day one, every later addition — plant #2, a guild, a drink, a lesson, a pest, a user's garden — is an `INSERT` into a table that already exists. No `ALTER` on live data, ever. That is what protects what you've already built.

*RLS (public reads published, admins write) + grants on every table here, using the exact pattern in the v1 spec.*
```
