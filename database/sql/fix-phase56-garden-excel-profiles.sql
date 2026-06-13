-- fix-phase56-garden-excel-profiles.sql
-- Full profile ingest from Garden.xlsx (Master Sheet + Quick Plant Profile).
-- Safe to re-run. Maps Excel cultivar profiles onto species shells (tomato, artichoke, …).
-- Source: brainstorm-inbox/2025.11.09_Garden.xlsx

-- Excel: Black Beauty Tomato - Brisbane → species slug `tomato` (Brisbane)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'tomato' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip tomato — shell missing'; RETURN; END IF;
  UPDATE public.plants SET plant_family = 'Solanaceae', subspecies = 'Solanum lycopersicum var. lycopersicum', taxonomic_authority = 'L. (Carl Linnaeus)', plant_type = 'Herbaceous annual, warm-season crop', genetic_lineage_type = 'Open-pollinated (heirloom-type selection, not an F1 hybrid)', variety_cultivar = '‘Black Beauty’ – Medium to large (150–200 g) round fruits with deep purple-black skin rich in anthocyanins. Meaty texture, complex smoky flavour, low acidity. Indeterminate growth habit with continuous fruiting. Considered one of the darkest-skinned tomato cultivars available.', origin = 'Developed by Wild Boar Farms, California, USA. Derived from selective breeding of high-anthocyanin heirloom tomatoes. Introduced into specialty heirloom seed systems internationally, including Australia.', growth_rate = 'Fast. Germination to transplant readiness occurs within 4–6 weeks, and rapid vegetative growth follows. Fruiting begins approximately 75–85 days after transplanting under Brisbane conditions.', size_height = 'Plant height typically 1.5–2.0 metres with support, spread 0.6–0.8 metres under Brisbane conditions.', pollination_type = 'Predominantly self-pollinating (autogamous), with flowers containing both male and female structures. Limited natural cross-pollination may occur.', flowering_season = 'In Brisbane, flowering generally begins from September through December when planted in late winter to spring, with continued flowering through summer if conditions remain favourable.', germination_time = '5–10 days under Brisbane’s warm spring conditions at soil temperatures of 20–28 °C.', time_to_harvest = '75–85 days from transplanting to first ripe fruits, depending on season and growing conditions.', planting_windows = '• Primary window: August to October (spring planting for summer harvest).
• Secondary window: November to December for late summer cropping, though disease and pest pressure increase with humidity.', harvesting_method = 'Fruits are harvested by hand when fully coloured (deep purple-black skin with red undertones) and slightly soft to the touch. Use clean, sharp scissors or gently twist fruits to avoid stem tearing. Harvest regularly to encourage continued fruiting.', care_summary = 'Tomato – Black Beauty (Solanum lycopersicum) is a herbaceous annual in the Solanaceae family, classified under the Vegetables group. It typically grows to 1.5–2.0 metres tall with a 0.6–0.8 metre spread with a vining form, suited to the herbaceous layer in food forest systems. Native to selective breeding origins in California, USA, this annual is moderate to grow and is non-invasive. It prefers full sun, fertile loamy soil within pH 6.0–6.8, and tolerates Brisbane’s humid subtropical climate with careful disease management and protection from strong winds. It is self-pollinating, flowers from September to December, and begins yielding within one season, producing 4–6 kg per plant from November to March with a shelf life of 4–10 days depending on storage. It offers richly flavoured, anthocyanin-rich fruit for fresh eating, cooking, and preservation, and contributes ecologically by attracting pollinators, providing seasonal diversity, and supporting garden guild integration.', updated_at = now() WHERE id = v_plant;
  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'climate', 'Well suited to Brisbane’s humid subtropical climate with warm springs and summers that promote rapid growth and fruiting.', 'High summer humidity encourages fungal diseases such as early blight, powdery mildew, and fruit splitting during heavy rainfall. Prolonged heatwaves can also reduce fruit set.', 'Plant from late winter to early summer to avoid peak humidity. Use resistant varieties where possible, apply regular pruning for airflow, and provide protective rain covers or tunnels during heavy rainfall.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Prefers deep, fertile, loamy soils with good structure and organic matter content.', 'Heavy clay soils cause poor drainage and root stress. Sandy soils dry out quickly and leach nutrients.', 'In clay soils, build raised beds and add compost or coarse sand for drainage. In sandy soils, apply regular compost and mulching to retain moisture and improve nutrient retention. Maintain soil cover year-round to prevent erosion.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'ph', 'Optimal pH range: 6.0–6.8. Tolerates 5.8–7.0 but nutrient uptake efficiency decreases outside this band.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', 'Requires full sun, with a minimum of 6–8 hours of direct sunlight daily for reliable flowering and fruiting.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'wind', 'Moderate. Tomato stems are brittle and prone to snapping in strong winds, especially under fruit load. Requires staking, trellising, or cages to prevent wind damage.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Requires consistent soil moisture throughout the growing season. Even watering supports uniform fruit development.', 'Irregular watering causes blossom end rot, fruit cracking, and reduced yield. Overwatering leads to root rot and fungal disease.', 'Install drip irrigation or soaker hoses to deliver steady water supply. Mulch heavily to conserve moisture and buffer temperature extremes. Avoid overhead watering to reduce leaf wetness and fungal spread.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Frost-sensitive annual crop; requires frost-free conditions for survival and productivity.', 'Temperatures below 5 °C cause growth suppression, and light frost kills seedlings or flowers.', 'Plant only after last frost risk (typically late winter in Brisbane). Use cloches or protective fleece for early plantings if cold nights are forecast.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'seasonal_risk', 'Late summer storms may cause fruit splitting and plant damage. High humidity in January–February significantly increases fungal disease pressure. Extended dry spells in spring cause water stress and blossom end rot if irrigation is inconsistent. Risk of fruit fly increases from mid-summer onward; protective netting is recommended.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'companions', 'Good companions include basil (repels pests and enhances flavour), marigold (reduces nematodes and deters whitefly), carrots (soil utilisation), lettuce (groundcover), and onions (insect deterrence).', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'incompatibles', 'Avoid planting near brassicas (compete heavily for nutrients), potatoes and eggplants (increase risk of shared diseases like blight), and fennel (allelopathic suppression).', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'fertilisation', 'Apply balanced organic fertiliser or compost before planting. Feed fortnightly with liquid seaweed or fish emulsion during vegetative growth. Switch to potassium-rich fertiliser during flowering and fruiting.', 'Over-fertilisation with nitrogen causes excessive foliage and poor fruit set.', 'Use fertiliser blends with NPK ratios balanced towards phosphorus and potassium during reproductive stages. Monitor leaf colour to detect nutrient imbalance.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'mulching', 'Maintain 5–8 cm of organic mulch (sugarcane, lucerne, or straw). Mulching conserves moisture, suppresses weeds, and buffers soil against temperature extremes in Brisbane’s hot summers. Keep mulch clear of the stem base to prevent rot.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pruning', 'Prune lower leaves and excess suckers to improve airflow, reduce disease risk, and encourage stronger fruiting trusses.', 'Over-pruning reduces yield and exposes fruits to sunscald.', 'Retain enough foliage to shade fruit while selectively pruning for balance. Regularly train vines onto stakes or cages.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'special_care', 'Requires trellising, staking, or tomato cages to support indeterminate vines.', 'Plants collapse under fruit load if not supported. Heavy summer rainfall may lead to fruit cracking.', 'Install support structures early, tie stems gently with soft ties, and harvest fruits promptly to reduce splitting.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'rotation', 'Belongs to the Solanaceae rotation group. Should not be planted in the same soil for at least 3 years to prevent disease buildup (blight, nematodes). Follow after legumes or leafy greens for soil balance.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Common pests in Brisbane include aphids, whiteflies, and caterpillars.', 'Fruit fly is a significant threat from mid-summer; mites may increase in dry spells.', 'Use insect exclusion netting for fruit fly, apply neem oil or insecticidal soap for aphids and whitefly, and encourage beneficial insects with flowering companions. Regular monitoring is essential.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'disease_notes', 'High humidity in Brisbane increases risk of early blight (Alternaria), bacterial spot, and powdery mildew. Crop rotation, good spacing, pruning for airflow, and copper-based sprays reduce severity. Avoid handling plants when wet to limit disease spread.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 8, 10, '• Primary window: August to October (spring planting for summer harvest).
• Secondary window: November to December for late summer cropping, though disease and pest pressure increase with humidity.'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 8 AND pc.month_end = 10
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'transplant', 9, 11, 'Transplant when seedlings have 4–6 true leaves, typically 4–6 weeks after sowing. Harden off seedlings by gradually exposing them to outdoor conditions for one week before planting out.'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'transplant'
        AND pc.month_start = 9 AND pc.month_end = 11
    );
  END IF;
END $$;

-- Excel: Black Beauty Tomato - Kerala → species slug `tomato` (Kerala)
DO $$
DECLARE v_plant uuid; v_cz uuid;
BEGIN
  SELECT id INTO v_plant FROM public.plants WHERE slug = 'tomato' LIMIT 1;
  IF v_plant IS NULL THEN RAISE NOTICE 'skip tomato — shell missing'; RETURN; END IF;
  UPDATE public.plants SET plant_family = 'Solanaceae', subspecies = 'Solanum lycopersicum var. lycopersicum', taxonomic_authority = 'L. (Carl Linnaeus)', plant_type = 'Herbaceous annual, warm-season crop', genetic_lineage_type = 'Open-pollinated (heirloom-type selection, not an F1 hybrid)', variety_cultivar = '‘Black Beauty’ – Medium to large (150–200 g) round fruits with deep purple-black skin rich in anthocyanins. Meaty texture, complex smoky flavour, low acidity. Indeterminate growth habit with continuous fruiting. Considered one of the darkest-skinned tomato cultivars available.', origin = 'Developed by Wild Boar Farms, California, USA. Derived from selective breeding of high-anthocyanin heirloom tomatoes. Introduced into specialty heirloom seed systems internationally, including Australia.', growth_rate = 'Fast. Germination to transplant readiness occurs within 4–6 weeks, and rapid vegetative growth follows. Fruiting begins approximately 75–85 days after transplanting under Brisbane conditions.', size_height = 'Plant height typically 1.5–2.0 metres with support, spread 0.6–0.8 metres under Brisbane conditions.', pollination_type = 'Predominantly self-pollinating (autogamous), with flowers containing both male and female structures. Limited natural cross-pollination may occur.', flowering_season = 'In Brisbane, flowering generally begins from September through December when planted in late winter to spring, with continued flowering through summer if conditions remain favourable.', germination_time = '5–10 days under Brisbane’s warm spring conditions at soil temperatures of 20–28 °C.', time_to_harvest = '75–85 days from transplanting to first ripe fruits, depending on season and growing conditions.', planting_windows = '• Primary window: August to October (spring planting for summer harvest).
• Secondary window: November to December for late summer cropping, though disease and pest pressure increase with humidity.', harvesting_method = 'Fruits are harvested by hand when fully coloured (deep purple-black skin with red undertones) and slightly soft to the touch. Use clean, sharp scissors or gently twist fruits to avoid stem tearing. Harvest regularly to encourage continued fruiting.', care_summary = 'Tomato – Black Beauty (Solanum lycopersicum) is a herbaceous annual in the Solanaceae family, classified under the Vegetables group. It typically grows to 1.5–2.0 metres tall with a 0.6–0.8 metre spread with a vining form, suited to the herbaceous layer in food forest systems. Native to selective breeding origins in California, USA, this annual is moderate to grow and is non-invasive. It prefers full sun, fertile loamy soil within pH 6.0–6.8, and tolerates Brisbane’s humid subtropical climate with careful disease management and protection from strong winds. It is self-pollinating, flowers from September to December, and begins yielding within one season, producing 4–6 kg per plant from November to March with a shelf life of 4–10 days depending on storage. It offers richly flavoured, anthocyanin-rich fruit for fresh eating, cooking, and preservation, and contributes ecologically by attracting pollinators, providing seasonal diversity, and supporting garden guild integration.', updated_at = now() WHERE id = v_plant;
  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1;
  IF v_cz IS NOT NULL THEN
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'climate', 'Well suited to Brisbane’s humid subtropical climate with warm springs and summers that promote rapid growth and fruiting.', 'High summer humidity encourages fungal diseases such as early blight, powdery mildew, and fruit splitting during heavy rainfall. Prolonged heatwaves can also reduce fruit set.', 'Plant from late winter to early summer to avoid peak humidity. Use resistant varieties where possible, apply regular pruning for airflow, and provide protective rain covers or tunnels during heavy rainfall.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'soil', 'Prefers deep, fertile, loamy soils with good structure and organic matter content.', 'Heavy clay soils cause poor drainage and root stress. Sandy soils dry out quickly and leach nutrients.', 'In clay soils, build raised beds and add compost or coarse sand for drainage. In sandy soils, apply regular compost and mulching to retain moisture and improve nutrient retention. Maintain soil cover year-round to prevent erosion.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'ph', 'Optimal pH range: 6.0–6.8. Tolerates 5.8–7.0 but nutrient uptake efficiency decreases outside this band.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'sunlight', 'Requires full sun, with a minimum of 6–8 hours of direct sunlight daily for reliable flowering and fruiting.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'wind', 'Moderate. Tomato stems are brittle and prone to snapping in strong winds, especially under fruit load. Requires staking, trellising, or cages to prevent wind damage.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'water', 'Requires consistent soil moisture throughout the growing season. Even watering supports uniform fruit development.', 'Irregular watering causes blossom end rot, fruit cracking, and reduced yield. Overwatering leads to root rot and fungal disease.', 'Install drip irrigation or soaker hoses to deliver steady water supply. Mulch heavily to conserve moisture and buffer temperature extremes. Avoid overhead watering to reduce leaf wetness and fungal spread.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'frost', 'Frost-sensitive annual crop; requires frost-free conditions for survival and productivity.', 'Temperatures below 5 °C cause growth suppression, and light frost kills seedlings or flowers.', 'Plant only after last frost risk (typically late winter in Brisbane). Use cloches or protective fleece for early plantings if cold nights are forecast.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'seasonal_risk', 'Late summer storms may cause fruit splitting and plant damage. High humidity in January–February significantly increases fungal disease pressure. Extended dry spells in spring cause water stress and blossom end rot if irrigation is inconsistent. Risk of fruit fly increases from mid-summer onward; protective netting is recommended.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'companions', 'Good companions include basil (repels pests and enhances flavour), marigold (reduces nematodes and deters whitefly), carrots (soil utilisation), lettuce (groundcover), and onions (insect deterrence).', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'incompatibles', 'Avoid planting near brassicas (compete heavily for nutrients), potatoes and eggplants (increase risk of shared diseases like blight), and fennel (allelopathic suppression).', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'fertilisation', 'Apply balanced organic fertiliser or compost before planting. Feed fortnightly with liquid seaweed or fish emulsion during vegetative growth. Switch to potassium-rich fertiliser during flowering and fruiting.', 'Over-fertilisation with nitrogen causes excessive foliage and poor fruit set.', 'Use fertiliser blends with NPK ratios balanced towards phosphorus and potassium during reproductive stages. Monitor leaf colour to detect nutrient imbalance.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'mulching', 'Maintain 5–8 cm of organic mulch (sugarcane, lucerne, or straw). Mulching conserves moisture, suppresses weeds, and buffers soil against temperature extremes in Brisbane’s hot summers. Keep mulch clear of the stem base to prevent rot.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pruning', 'Prune lower leaves and excess suckers to improve airflow, reduce disease risk, and encourage stronger fruiting trusses.', 'Over-pruning reduces yield and exposes fruits to sunscald.', 'Retain enough foliage to shade fruit while selectively pruning for balance. Regularly train vines onto stakes or cages.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'special_care', 'Requires trellising, staking, or tomato cages to support indeterminate vines.', 'Plants collapse under fruit load if not supported. Heavy summer rainfall may lead to fruit cracking.', 'Install support structures early, tie stems gently with soft ties, and harvest fruits promptly to reduce splitting.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'rotation', 'Belongs to the Solanaceae rotation group. Should not be planted in the same soil for at least 3 years to prevent disease buildup (blight, nematodes). Follow after legumes or leafy greens for soil balance.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'pest_mgmt', 'Common pests in Brisbane include aphids, whiteflies, and caterpillars.', 'Fruit fly is a significant threat from mid-summer; mites may increase in dry spells.', 'Use insect exclusion netting for fruit fly, apply neem oil or insecticidal soap for aphids and whitefly, and encourage beneficial insects with flowering companions. Regular monitoring is essential.')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
    VALUES (v_plant, v_cz, 'disease_notes', 'High humidity in Brisbane increases risk of early blight (Alternaria), bacterial spot, and powdery mildew. Crop rotation, good spacing, pruning for airflow, and copper-based sprays reduce severity. Avoid handling plants when wet to limit disease spread.', '', '')
    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'sow', 8, 10, '• Primary window: August to October (spring planting for summer harvest).
• Secondary window: November to December for late summer cropping, though disease and pest pressure increase with humidity.'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'sow'
        AND pc.month_start = 8 AND pc.month_end = 10
    );
    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
    SELECT v_plant, v_cz, 'transplant', 9, 11, 'Transplant when seedlings have 4–6 true leaves, typically 4–6 weeks after sowing. Harden off seedlings by gradually exposing them to outdoor conditions for one week before planting out.'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.plant_calendar pc
      WHERE pc.plant_id = v_plant AND pc.activity = 'transplant'
        AND pc.month_start = 9 AND pc.month_end = 11
    );
  END IF;
END $$;

SELECT 'fix-phase56-garden-excel-profiles ready — 2 excel profile(s)' AS status;