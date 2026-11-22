# Underwater Acoustics, Sonar, Contact Management and TMA: Fundamentals and Game Abstractions (Godot 4 submarine command simulator)

Labels used throughout: **[FACT]** = stated by the cited public source; **[COMMUNITY]** = player/forum statement, not developer-verified; **[ILLUSTRATIVE]** = number computed here from a cited public formula for orientation only, not real platform data; **[ESTIMATE]** = researcher's rough estimate with no direct source; **[INFERENCE/REC]** = reasoning or recommendation derived from the cited findings. No real sonar or platform performance figures are presented as known; all numbers below are textbook/generic or explicitly illustrative. Research only; no implementation code.

Research date: November 2026. Sources consulted: FAS-hosted US Naval Academy course pages (ES310), DOSITS (URI), NPL listings, DTIC reports, IEEE/arXiv bearings-only tracking literature, MathWorks Sensor Fusion documentation, Naval Submarine League archive, and community forums for Dangerous Waters, Cold Waters, Silent Hunter and Command: Modern Operations.

---

## 1. Passive and active sonar equations (SL, TL, NL, DI/AG, DT, TS, SE) and how a game can use them

### Takeaway
The unclassified sonar equations are simple decibel bookkeeping (passive: SE = SL − TL − (NL − DI) − DT; active: SE = SL − 2TL + TS − (NL − DI) − DT, or reverberation-limited variants), which makes them an ideal, cheap backbone for a game's detection model; the difficulty and "physics" live almost entirely inside TL and NL, which can be parameterised.

### Cited Findings
- [FACT] Passive sonar: SNR = SL + DI − TL − NL (one-way path, no target strength); active sonar: SNR = SL − 2TL + TS − NL + DI. The terms are combined by ordinary dB addition/subtraction, not by power summation — [FAS ES310 Underwater Acoustics](https://man.fas.org/dod-101/navy/docs/es310/uw_acous/uw_acous.htm)
- [FACT] DOSITS writes the same forms with array gain (AG) as a reduction of noise: passive SNR = SL − TL − (NL − AG); active SNR = SL − 2TL + TS − (NL − AG). The passive form drops TS and has TL once because transmission is one-way — [DOSITS Sonar Equation](https://dosits.org/science/advanced-topics/sonar-equation/)
- [FACT] Term definitions: SL = level 1 m from source (dB re 1 µPa); TL = total intensity reduction by spreading and attenuation; TS = echo level 1 m from target relative to incident intensity; NL = background noise at receiver; AG = effective noise reduction from a receiver that looks in one direction and rejects noise from others — [DOSITS Sonar Equation](https://dosits.org/science/advanced-topics/sonar-equation/)
- [FACT] NL = AN ⊕ SN (ambient noise power-summed with self-noise) — [FAS ES310 Underwater Acoustics](https://man.fas.org/dod-101/navy/docs/es310/uw_acous/uw_acous.htm)
- [FACT] Signal excess: SE = SNR − DT; detection is declared when SE > 0. The operator sets the threshold; "signal absent" is decided when SNR is below DT — [DOSITS Sonar Equation](https://dosits.org/science/advanced-topics/sonar-equation/); [DOSITS Detection Threshold](https://dosits.org/science/advanced-topics/detection-threshold-for-sonar/)
- [FACT] "Detection generally occurs, meaning more than 50% of the time, whenever SNR > DT" (i.e., DT is conventionally the 50% detection point) — [FAS ES310 Underwater Acoustics](https://man.fas.org/dod-101/navy/docs/es310/uw_acous/uw_acous.htm)
- [FACT] Figure of merit (FOM): passive FOM = SL + DI − NL − DT, detection when FOM > TL; active FOM = SL + TS + DI − NL − DT and, because loss occurs twice, detection when FOM/2 > TL — [FAS ES310 Sonar Propagation](https://man.fas.org/dod-101/navy/docs/es310/SNR_PROP/snr_prop.htm)
- [FACT] Directivity: circular plate of diameter D: beamwidth ≈ 2.4λ/D, DI = 20 log(πD/λ); linear array of length L: beamwidth ≈ 2λ/L, DI = 10 log(2L/λ) (the page's prose gives 10 log(πL/λ), conflicting with its own table). Array frequency limits: f_min ≈ c/2L (DI → 0 when 2L = λ), f_max ≈ c/d for element spacing d — [FAS ES310 Underwater Acoustics](https://man.fas.org/dod-101/navy/docs/es310/uw_acous/uw_acous.htm)
- [FACT] Level combining: SPL_total = 10 log(10^(L1/10) + 10^(L2/10)); 60 ⊕ 60 = 63 dB; table shortcut: add 3/2/1/0 dB to the larger level for differences of 0–1/2–4/5–9/>9 dB — [FAS ES310 Underwater Acoustics](https://man.fas.org/dod-101/navy/docs/es310/uw_acous/uw_acous.htm)
- [FACT] DOSITS worked active-sonar example: SL 220 dB yields SNR ≈ 22 dB (array gain included as noise reduction) — [DOSITS active sonar example](https://dosits.org/science/advanced-topics/sonar-equation/sonar-equation-example-active-sonar) (from search excerpt; full numerical breakdown not retrieved)
- [FACT] Active sonar can be reverberation-limited rather than noise-limited; a bistatic receiver avoids the reverberation limit and reduces two-way loss — [FAS ES310 ASW Systems](https://man.fas.org/dod-101/navy/docs/es310/asw_sys/asw_sys.htm)
- [FACT] Command: Modern Operations (CMO) converts database nominal values plus modifiers into an FOM that becomes a practical detection range; the developer described the result as a sharp threshold ("at 12.2 nm there will always be a detection and at 12.4 there will never be one") and listed a "softer FOM with a ± factor" as under consideration — [Matrix Games forum, CMO sonar model thread](https://forums.matrixgames.com/viewtopic.php?p=4789844)

### Inferences
- [INFERENCE/REC] A game sensor model can compute, per (sensor, target, frequency band) pair per sonar tick: SE = SL_band(target state) − TL_band(geometry, environment) − (NL_band(ambient ⊕ own self-noise) − DI_band(sensor, bearing)) − DT_sensor(operator/processing mode). Everything is a handful of additions plus one TL lookup; this is cheap enough for every pair at 1 Hz.
- [INFERENCE/REC] Use DT as the 50%-detection point (per FAS) and map SE to a detection probability with a smooth function (e.g., a logistic/normal CDF on SE with a "fluctuation" spread of a few dB). This avoids the CMO-style hard edge its own developer considered softening, and naturally produces intermittent "fading" contacts near the edge of detection — a key source of tension. The spread value is a tuning parameter, not a sourced constant.
- [INFERENCE/REC] Counter-detection of active sonar follows directly from the equations: the target hears the ping after only one TL (SL − TL − NL_target + DI_target) whereas the pinger needs the echo after 2TL + TS. Because TL grows with range, a pinging platform is generally detectable well beyond the range at which it gets an echo — the classic "going active reveals you" trade-off reported by players ([Cold Waters SUBSIM thread](https://subsim.com/radioroom/showthread.php?p=2529396)).
- [INFERENCE/REC] The FOM form lets the UI show a "predicted detection range" by inverting the TL curve (range at which TL = FOM). This is a natural fit for a sonar-prediction display and for AI decision-making.
- [INFERENCE/REC] DI depends on frequency (via λ) and on array size; the cheapest game representation is a per-array table of DI per band plus a bearing-dependent coverage mask (baffles/blind arcs). The f_min ≈ c/2L limit explains why short hull arrays are poor at the low frequencies where tonals and shipping noise live, and why long towed arrays exist.

### Gaps
- Urick's textbook detection-threshold expressions in terms of detection index d, bandwidth and integration time (and ROC curves) were not retrieved this session; FAS states it gives no ROC treatment. Reference for follow-up: R. J. Urick, *Principles of Underwater Sound*, 3rd ed., McGraw-Hill, 1983 (not consulted directly).
- Reverberation level (RL) formulas for reverberation-limited active sonar were not retrieved; FAS and DOSITS pages fetched do not give them.
- No public source fetched gives a canonical SE-to-Pd spread value; the "few dB" spread is a design parameter.

---

## 2. Transmission loss and propagation features; which can be approximated cheaply

### Takeaway
Textbook TL = spreading + absorption + an "anomaly" term; spreading and absorption are trivial closed-form functions, while the gameplay-relevant structure (layer/shadow zone, surface duct, convergence zones, deep sound channel, bottom bounce, shallow-water cut-off) can all be represented as parametric rules or precomputed TL tables derived from a per-region sound speed profile, without runtime ray tracing.

### Cited Findings
**Spreading and absorption**
- [FACT] Spherical spreading TL = 20 log R (R in m) out to a transition range; beyond it cylindrical TL = 10 log R + 30 dB; the course uses a 1000 m transition range justified by an average ocean depth of ~2000 m — [FAS ES310 Sonar Propagation](https://man.fas.org/dod-101/navy/docs/es310/SNR_PROP/snr_prop.htm)
- [FACT] Full textbook form: TL = 10 log R + 30 + αR + A, where α is absorption (dB/km) and A is a "transmission loss anomaly" covering scattering, surface/bottom reflection losses and sound-speed effects. Rules of thumb ignoring αR and A: ~60 dB at 1 km, 70 dB at 10 km, 80 dB at 100 km — [FAS ES310 Sonar Propagation](https://man.fas.org/dod-101/navy/docs/es310/SNR_PROP/snr_prop.htm)
- [FACT] Absorption rises strongly with frequency — [FAS ES310 Sonar Propagation](https://man.fas.org/dod-101/navy/docs/es310/SNR_PROP/snr_prop.htm); see also [DOSITS Sound Absorption](https://dosits.org/science/movement/why-does-sound-get-weaker-as-it-travels/sound-absorption/)
- [FACT] Thorp (1965) empirical absorption fit: α ≈ 0.1f²/(1+f²) + 40f²/(4100+f²) + 2.75×10⁻⁴ f² + 0.003 dB/kyd, f in kHz; implementations frequently mislabel units (dB/kyd vs dB/km) — [ns-3 Bugzilla #1055 (Thorp units discussion)](https://www.nsnam.org/bugzilla/show_bug.cgi?id=1055) (formula as reproduced in search excerpts of the DTIC/ns-3 results)
- [FACT] Thorp is an empirical fit mainly for low/intermediate frequencies in deep sound-channel waters; later work (Browning & Mellen) found near-surface low-frequency absorption at higher pH can be up to twice Thorp's values — [Browning & Mellen, IOA proceedings](https://www.ioa.org.uk/system/files/publications/DG%20BROWNING%20RH%20MELLEN%20THE%20EFFECT%20OF%20PH%20ON%20LOW%20FREQUENCY%20SOUND%20ABSORPTION%20IN%20THE%20OCEAN.pdf)
- [ILLUSTRATIVE] Computed from the Thorp formula above (converted ×1.094 to dB/km): ~0.0045 dB/km at 100 Hz; ~0.07 dB/km at 1 kHz; ~0.2 dB/km at 3 kHz; ~1.2 dB/km at 10 kHz; ~8 dB/km at 30 kHz. Over 50 km that is ~0.2 dB (100 Hz), ~3.4 dB (1 kHz), ~59 dB (10 kHz). This is the physical reason low-frequency passive listening dominates long-range detection and high-frequency active/torpedo sonars are short-ranged.
- [INFERENCE] The alternative coefficient set "0.11 … 44 …" seen in some references is the same Thorp fit expressed in dB/km (0.1×1.094 ≈ 0.11; 40×1.094 ≈ 44), resolving the apparent conflict noted in search results.
- Francois–Garrison (1982) and Ainslie–McColm (1998) are the modern standard absorption models (boric acid and magnesium sulphate relaxation plus pure-water viscosity) and are offered on the NPL technical guide — [NPL sea absorption guide](https://resource.npl.co.uk/acoustics/techguides/seaabsorption/) (page returned HTTP 503 during this session; formulas not verified here).

**Sound speed profile (SVP)**
- [FACT] Rules of thumb: +1 °C → +3 m/s; +100 m depth → +1.7 m/s; +1 ppt salinity → +1.3 m/s; nominal c ≈ 1500 m/s — [FAS ES310 Underwater Acoustics](https://man.fas.org/dod-101/navy/docs/es310/uw_acous/uw_acous.htm)
- [FACT] The SVP is "the fundamental tool for predicting how sound will travel"; structure: a variable surface (seasonal) layer, the main thermocline, and a deep isothermal layer whose positive gradient "is solely due to the pressure effect"; winter storms can mix the surface layer to ~100 m — [FAS ES310 Sonar Propagation](https://man.fas.org/dod-101/navy/docs/es310/SNR_PROP/snr_prop.htm)
- [FACT] Mackenzie (1981), "Nine-term equation for sound speed in the oceans", J. Acoust. Soc. Am. 70(3), 807–812, DOI 10.1121/1.386920; validity −2 to 30 °C, 30–40 ppt (NPL lists 25–40 ppt), 0–8000 m — [Scilit record of Mackenzie 1981](https://scilit.com/publications/2b09562f36ddec29bb3abfb08cb47f6e); [NPL sound speed in seawater guide](https://resource.npl.co.uk/acoustics/techguides/soundseawater/)
- [FACT] NPL notes the most recent seawater sound-speed equation is the NPL equation of Leroy, Robinson & Goldsmith (2008), inputs T, S, depth and latitude, agreeing to better than ±0.2 m/s with complex reference equations — [NPL sound speed in seawater guide](https://resource.npl.co.uk/acoustics/techguides/soundseawater/)
- [Unverified coefficients — researcher background, verify against the DOI before use] Mackenzie: c = 1448.96 + 4.591T − 5.304×10⁻²T² + 2.374×10⁻⁴T³ + 1.340(S−35) + 1.630×10⁻²D + 1.675×10⁻⁷D² − 1.025×10⁻²T(S−35) − 7.139×10⁻¹³TD³ (T °C, S ppt, D m). [ILLUSTRATIVE] With S = 35 this gives ≈1521.5 m/s (20 °C, 0 m), ≈1483 m/s (4 °C, 1000 m), ≈1525.7 m/s (2 °C, 4000 m), ≈1534 m/s (25 °C, 0 m).

**Layer, shadow zone, surface duct**
- [FACT] With a positive gradient above a negative one, rays split at the layer depth (LD, where sound speed is maximum); beyond a minimum range, rays from a source above the layer do not reach depths just below it (shadow zone), and submarines favour that depth — [FAS ES310 Sonar Propagation](https://man.fas.org/dod-101/navy/docs/es310/SNR_PROP/snr_prop.htm)
- [FACT] A positive gradient near the surface traps sound in a surface duct — [FAS ES310 Sonar Propagation](https://man.fas.org/dod-101/navy/docs/es310/SNR_PROP/snr_prop.htm)
- [FACT] The surface duct has a minimum cutoff frequency (MCF) that depends on sonic layer depth (SLD, depth of the near-surface sound-speed maximum); sound above the MCF is trapped — [Helber et al. 2008, NRL](https://www7320.nrlssc.navy.mil/pubs/2008/helber-2008.pdf); an empirical MCF form a1·V0·SLD^a2·(V_SLD − V0) appears in [US Patent 8032314](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/8032314) (constants not in excerpt)
- [FACT, OCR-garbled, treat as unverified] A DTIC report gives an empirical maximum trapped wavelength λ_max ≈ 0.0047·h^1.5 (both in feet) for duct thickness h — [DTIC ADA247257](https://apps.dtic.mil/sti/pdfs/ADA247257.pdf). [ILLUSTRATIVE] Taken at face value (c ≈ 4921 ft/s) this gives cutoffs of ~1 kHz for a 100 ft duct, ~370 Hz for 200 ft, ~200 Hz for 300 ft, ~95 Hz for 500 ft.
- [FACT] CMO's model weakens surface ducting as wind and sea state increase (developer statement) — [Matrix Games forum](https://forums.matrixgames.com/viewtopic.php?p=4789844)

**Convergence zones (CZ), deep sound channel (DSC), bottom bounce**
- [FACT] CZ: rays bent back up by the deep pressure gradient reconverge near the surface "typically 20–30 nm from the source", repeating at ~30/60 nm, each zone only a few miles wide; requires "a minimum of 200 m of depth excess" (water depth beyond the depth at which rays turn back up; the definition gloss is the researcher's) — [FAS ES310 Sonar Propagation](https://man.fas.org/dod-101/navy/docs/es310/SNR_PROP/snr_prop.htm)
- [FACT] CZ conditions: sound speed at depth at least as great as at the surface, plus enough water below that depth; rays reappear at intervals of about 30 miles out to several hundred miles — [tpub Aerographer/Navy training text](https://tpub.com/weather3/2-9.htm) (search excerpt)
- [FACT] Deep sound channel: a negative gradient above a positive gradient bends rays back toward the channel axis; sonobuoys have a setting for typical axis depth — [FAS ES310 Sonar Propagation](https://man.fas.org/dod-101/navy/docs/es310/SNR_PROP/snr_prop.htm); sonobuoy depth settings shallow for surface duct, deep for sound channel — [FAS ES310 ASW Systems](https://man.fas.org/dod-101/navy/docs/es310/asw_sys/asw_sys.htm)
- [FACT] Bottom bounce arrives at steep angles (>30° from horizontal); flat hard bottoms are best, soft mud worst — [FAS ES310 Sonar Propagation](https://man.fas.org/dod-101/navy/docs/es310/SNR_PROP/snr_prop.htm); spherical arrays' large downward look angles are used for bottom-bounce detection — [FAS ES310 ASW Systems](https://man.fas.org/dod-101/navy/docs/es310/asw_sys/asw_sys.htm)
- [FACT] Variable-depth sonar operated below the layer can reach submarines in the shadow zone of the submarine's own sonar and use the deep channel — [FAS ES310 ASW Systems](https://man.fas.org/dod-101/navy/docs/es310/asw_sys/asw_sys.htm)
- [FACT] Naval training literature treats TL with models for the mixed layer, surface interference, CZ and bottom bounce within the sonar-equation framework — [DTIC ADA030034 (NPS text)](https://apps.dtic.mil/sti/tr/pdf/ADA030034.pdf) (search excerpt); Urick's 1979 DARPA report *Sound Propagation in the Sea* has a surface-duct chapter — [DTIC ADA319320](https://apps.dtic.mil/sti/tr/pdf/ADA319320.pdf)

**How an existing game parameterises propagation (CMO, as a pattern)**
- [FACT, developer/forum] CMO indexes layer strength to latitude (strongest 0.7 at the equator, −0.1 per 18° latitude in the version discussed), indexes CZ range to latitude, requires ≥200 m (600 ft) clearance under the target for CZ detection, and grants a 200% effective-range boost when both emitter and receiver are in the DSC band — [Matrix Games forum](https://forums.matrixgames.com/viewtopic.php?p=4789844)
- [CONFLICT] CMO's manual states CZ intervals range "from 40 nm in the poles to 20 nm in the equator"; a forum analyst called this "almost completely wrong" and proposed ~40 nm at the equator falling to ~20 nm near the polar circles, no CZs beyond ~70° latitude, and a latitude-dependent minimum water depth of ~1700–5380 m; the developer later wrote "OP changes implemented, currently in testing" without specifying which — [Matrix Games forum](https://forums.matrixgames.com/viewtopic.php?p=4789844)

**Shallow water**
- [FACT] A shallow layer acts like a waveguide with a mode cutoff frequency depending on layer thickness H, water sound speed c and bottom sound speed c1 — [US Patent 9880305](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9880305) (excerpt form appears garbled). The standard Pekeris-waveguide form (researcher background; see Jensen, Kuperman, Porter & Schmidt, *Computational Ocean Acoustics*, 2nd ed., Springer, 2011 — not consulted directly) is f_n ≈ (n − ½)·c / (2H·√(1 − c²/c_b²)). [ILLUSTRATIVE] For H = 50 m, c = 1500 m/s, c_b = 1700 m/s, the first-mode cutoff is ≈16 Hz.
- [FACT] FAS chose the spherical-to-cylindrical transition range from typical ocean depth — [FAS ES310 Sonar Propagation](https://man.fas.org/dod-101/navy/docs/es310/SNR_PROP/snr_prop.htm)

### Inferences
- [INFERENCE] The CZ latitude conflict is resolvable from physics: warmer tropical surface water has a higher sound speed (≈1534 m/s at 25 °C vs ≈1490 m/s at 10 °C, illustrative Mackenzie values), so rays must go deeper before the pressure gradient matches the surface speed, implying longer CZ range and greater required water depth at low latitudes. This supports the forum analyst's direction over the quoted manual text. A game that derives CZ range from a per-region SVP gets this right automatically.
- [INFERENCE/REC] Cheap representation of environment (per ocean "province"/grid cell, updated rarely):
  - Store a coarse SVP (e.g., 8–20 depth knots) or generate it from a few parameters (surface temperature, mixed-layer depth, thermocline gradient, deep temperature, salinity) via Mackenzie. From it derive scalars: layer depth / SLD, layer strength (gradient contrast), surface-duct cutoff band, DSC axis depth, CZ range and width, required depth excess, bottom depth and bottom type.
  - TL per pair = piecewise spreading (transition range set from duct thickness or water depth) + α(f)·R from a 4–8 band Thorp lookup + anomaly terms: (a) cross-layer penalty when source and receiver are on opposite sides of the layer beyond a minimum range (tunable, e.g., several to tens of dB scaled by layer strength); (b) surface-duct bonus when both are in-duct and band is above cutoff (decaying with sea state); (c) CZ "annulus" bonus when range is within ±(width/2) of k·R_CZ and depth excess condition holds; (d) bottom-bounce path with bottom-loss per bounce by bottom type in deep water; (e) shallow-water rule: low bands below cutoff heavily attenuated, mode stripping/bottom loss, higher reverberation for active.
  - Take the best (lowest-TL) of the available paths per pair; optionally report which path won ("direct", "CZ", "bottom bounce"), which is gameplay-relevant information for the player (CZ contacts appear and disappear in bands).
- [INFERENCE/REC] A precomputed TL table per province (source-depth bin × receiver-depth bin × range bin × band) built offline or at load time by a simple 2D ray tracer gives most of the realism at O(1) runtime cost; memory is modest (e.g., 10 × 10 × 200 × 4 floats ≈ 80k floats ≈ 320 KB per province) [ESTIMATE].
- [INFERENCE/REC] Absorption chemistry (Francois–Garrison vs Thorp vs Ainslie–McColm) differences are irrelevant to gameplay; a fixed Thorp band table is sufficient. What matters is the qualitative "low frequency travels far, high frequency dies fast" ordering.

### Gaps
- NPL absorption guide (Francois–Garrison, Ainslie–McColm formulas) returned HTTP 503; formulas not verified. References for follow-up: R. E. Francois & G. R. Garrison, J. Acoust. Soc. Am. 72 (1982); M. A. Ainslie & J. G. McColm, J. Acoust. Soc. Am. 103 (1998) — not consulted directly.
- Mackenzie coefficients are reproduced from researcher background knowledge; the R package page fetched cites the paper but does not show the coefficients. Verify against the original paper.
- Exact Urick surface-duct cutoff expression and "best depth" formula (shown only as an image on FAS) were not retrieved; the DTIC λ_max formula is OCR-garbled.
- No public source fetched gives a canonical cross-layer TL penalty magnitude; it is a tuning value (realistically highly variable).
- Lurton, *An Introduction to Underwater Acoustics*, 2nd ed., Springer, 2010, and Jensen et al. (2011) were not consulted directly this session.

---

## 3. Ambient noise and target radiated noise (broadband, tonals, speed, cavitation, transients)

### Takeaway
Ambient noise is dominated by distant shipping at low frequencies and wind/wave (sea state) at mid-to-high frequencies, with rain and biologics as intermittent spikes of +20–35 dB; target noise is a broadband continuum plus narrowband machinery tonals, rising with speed and jumping sharply at cavitation inception, which occurs at higher speeds when deeper. All of this is parameterisable with a few curves and events.

### Cited Findings
**Ambient noise**
- [FACT] Wenz (1962) curves give typical ocean background noise spectrum levels (dB re 1 µPa²/Hz) versus frequency by source; 20–500 Hz noise is primarily distant shipping; 500 Hz–100 kHz is mostly spray and bubbles from breaking waves, increasing with wind speed — [DOSITS (search excerpt) / Ocean Noise Variability](https://dosits.org/science/advanced-topics/ocean-noise-variability-and-noise-budgets). Full reference: G. M. Wenz, "Acoustic ambient noise in the ocean: spectra and sources," J. Acoust. Soc. Am. 34(12), 1936–1956 (1962).
- [FACT] A storm passing over a receiver can raise mid-frequency levels by 30 dB or more; heavy rain can raise levels by up to 35 dB over several hundred Hz to >20 kHz; marine mammal calls can raise low-frequency levels 20–25 dB at some locations/times (e.g., 17–20 Hz off California in fall/winter from blue and fin whales) — [DOSITS Ocean Noise Variability](https://dosits.org/science/advanced-topics/ocean-noise-variability-and-noise-budgets)
- [FACT] Measured example (Point Sur, CA) means: 91.3 dB at 50 Hz, 81.0 at 100 Hz, 75.7 at 200 Hz, 71.6 at 400 Hz (dB re 1 µPa²/Hz), std dev ~4–5 dB; distributions have upper tails — [DOSITS Ocean Noise Variability](https://dosits.org/science/advanced-topics/ocean-noise-variability-and-noise-budgets)
- [FACT] In an Ionian Sea 500 Hz noise budget, wind was the most frequent dominant source, then shipping, then rain — [DOSITS Ocean Noise Variability](https://dosits.org/science/advanced-topics/ocean-noise-variability-and-noise-budgets)
- [FACT] Simplified Wenz descriptive curves do not include rain per se; rain is present only ~10–20% of the time — [NOAA report (search excerpt)](https://repository.library.noaa.gov/view/noaa/58992/noaa_58992_DS1.pdf)
- [FACT] FAS course: sea-state noise mostly >300 Hz, shipping <300 Hz; six shipping-density classes (very remote, remote, quiet, shipping lanes, heavy traffic deep, heavy traffic shallow); biologics (e.g., snapping shrimp, whales, dolphins) are unpredictable and known only in situ; AN = shipping ⊕ sea state; worked example at 300 Hz: shipping lanes 65 dB ⊕ sea state 2 62 dB = 67 dB — [FAS ES310 Underwater Acoustics](https://man.fas.org/dod-101/navy/docs/es310/uw_acous/uw_acous.htm)
- [FACT] Self-noise (electronics, platform, flow over the array) has a speed-independent floor and increases with flow and platform noise above it — [FAS ES310 Underwater Acoustics](https://man.fas.org/dod-101/navy/docs/es310/uw_acous/uw_acous.htm)
- [FACT] CMO does not model cumulative ambient noise from multiple platforms but does let platforms on the same bearing mask a submarine; cumulative ambient from platforms was listed as a possible change — [Matrix Games forum](https://forums.matrixgames.com/viewtopic.php?p=4789844)

**Target radiated noise**
- [FACT] Broadband sources: propeller and shaft (generally <1000 Hz, amplitude-modulated by rotation rate), flow noise, some propulsion plants; narrowband sources: pumps, motors, generators, propulsion machinery — "when specifying narrowband sources, it is important to also specify the frequency" — [FAS ES310 Underwater Acoustics](https://man.fas.org/dod-101/navy/docs/es310/uw_acous/uw_acous.htm)
- [FACT] A target's frequency content reveals its identity and operating state; changes in received frequency over time (Doppler) indicate range rate if the original frequency is known; waterfall displays show a beam's frequency content over time — [FAS ES310 ASW Systems](https://man.fas.org/dod-101/navy/docs/es310/asw_sys/asw_sys.htm)
- [FACT] Cavitation inception speed (CIS) is the highest speed without any cavitation on propellers or appendages; even a small amount of cavitation causes a significant increase in noise — [Kongsberg CIS page](https://www.kongsberg.com/maritime/services/hydrodynamics--collaboration--references/propeller-design--cavitation/cavitation-inception-speed--cis) (search excerpt; direct fetch returned 403)
- [FACT] Depth raises the pressure on the propeller and reduces the tendency to cavitate ("the deeper the hub, the greater will be the pressure … less tendency towards a vacuum") — [ITU propulsion lecture, Week 04](https://web.itu.edu.tr/takinaci/dersler/advpropsys/week_04/Week_04.pdf) (search excerpt); the cavitation number uses the pressure "far from any disturbance considered at the same water depth" — [TU Hamburg paper](https://tore.tuhh.de/bitstreams/f697e795-0cca-4d6b-90bb-3f405ac36252/download) (search excerpt)
- [FACT] Model-scale inception prediction for modern submarine propulsors needs substantial scaling corrections (Reynolds number, nuclei content) — [National Academies, naval hydrodynamics chapter](https://www.nationalacademies.org/read/9820/chapter/5) (search excerpt)
- [FACT] CMO: submarine noise rises with speed non-linearly; no tactical/best-silent speed modelled at the time; subs could not hear low-altitude aircraft/helicopters — [Matrix Games forum](https://forums.matrixgames.com/viewtopic.php?p=4789844)
- [COMMUNITY] Cold Waters players report that higher own speed "washes out" contacts and that running ultra-quiet (≤5 kt or stopped) speeds up solutions — [SUBSIM Cold Waters thread](https://subsim.com/radioroom/showthread.php?p=2529396)

### Inferences
- [INFERENCE] Using the standard cavitation number σ = (p∞ − p_v)/(½ρV²) with p∞ ≈ p_atm + ρgh, a fixed inception σ_i implies V_i ∝ √(p_atm + ρgh − p_v), i.e., roughly V_i(h2)/V_i(h1) ≈ √((10.3 + h2)/(10.3 + h1)) with h in metres. [ILLUSTRATIVE] Relative to 20 m: ×1.9 at 100 m, ×2.6 at 200 m, ×3.7 at 400 m. This is an idealised upper bound (tip-vortex inception and scaling effects deviate); a game should use a gentler, tunable curve with the same monotonic shape.
- [INFERENCE/REC] Minimal radiated-noise model per platform per band: SL_band = base_band + slope_band·log10(max(V, V_min)/V_ref) + cavitation_step_band·smoothstep(V − V_cis(depth)) + machinery_state_offsets (e.g., pumps on/off, reactor coolant mode/drive mode as abstract "quiet modes") + active transient events. Separate tonal lines (frequency, level, tied to machinery state, Doppler-shifted by radial velocity) feed classification rather than detection range only.
- [INFERENCE/REC] Transients (tube flooding, outer door opening, weapon launch, hull popping on depth change, dropped objects, active pings) are short-duration additive SL spikes in specific bands that can reveal a quiet platform and grant the hearer an immediate bearing and classification cue. They are cheap (event list with decay) and high-tension. No public source fetched quantifies transient levels; treat magnitudes as tuning values.
- [INFERENCE/REC] Ambient model: NL_band = shipping(density class, band) ⊕ wind/sea-state(band) ⊕ rain(event) ⊕ biologics(region/season random events), taken from a small Wenz-shaped table (≈5 shipping classes × 4–8 bands; sea state 0–6 × bands). Add own-ship self-noise(speed, band, array) and power-sum. The DOSITS spread (~4–5 dB std) suggests adding slow random variation for "living" conditions.
- [INFERENCE/REC] Sea state couples nicely into gameplay: higher sea state raises mid/high-frequency NL (hurting high-frequency sensors, helping the hider) and degrades the surface duct (CMO pattern).

### Gaps
- No unclassified source fetched gives generic radiated-noise vs speed slopes (e.g., dB per doubling of speed) for submarines; the slope must be a tuning parameter. (Ross, *Mechanics of Underwater Noise*, would be the textbook follow-up — not consulted.)
- Numeric Wenz curve values per sea state/shipping class were not extracted (figures not readable in fetched pages); a designer would need to digitise from Wenz (1962) or a public reproduction.
- Search excerpts mentioned historical submarine tip-vortex cavitation at low speeds and naval cavitation-free speed ranges, but the exact source page was not verified; omitted as facts.

---

## 4. Sensor types and geometry (bow/sphere, flank, towed arrays, baffles, active, sonobuoys/dipping sonar)

### Takeaway
Each array type should be represented by a coverage geometry (bearing/elevation arcs, baffles), a per-band DI/bearing-accuracy profile, a self-noise sensitivity to own speed, and type-specific ambiguities (towed array left/right mirror bearings and degradation while turning); airborne sonobuoys/dipping sonar and MAD form the external threat layer.

### Cited Findings
- [FACT] Hull-mounted arrays are shielded from own-ship noise by discontinuing the array aft and using sound-attenuating material; the region aft where the sonar cannot detect is the baffles — [FAS ES310 ASW Systems](https://man.fas.org/dod-101/navy/docs/es310/asw_sys/asw_sys.htm)
- [FACT] Spherical arrays (common on submarines) have a much wider vertical field of view; large downward angles are used for bottom-bounce detection — [FAS ES310 ASW Systems](https://man.fas.org/dod-101/navy/docs/es310/asw_sys/asw_sys.htm)
- [FACT] Towed arrays can be very long because they are not constrained by ship size, giving narrow beams or lower-frequency operation; low frequency is valuable because many sources are strong there and absorption is small — [FAS ES310 ASW Systems](https://man.fas.org/dod-101/navy/docs/es310/asw_sys/asw_sys.htm)
- [FACT] "The linear array cannot distinguish signals on the left from those on the right"; manoeuvring resolves it because only one of the two bearings matches after the second leg (worked example: 030/330 relative on course 045, then 060/300 relative on course 135 → true bearing 075) — [FAS ES310 ASW Systems](https://man.fas.org/dod-101/navy/docs/es310/asw_sys/asw_sys.htm)
- [FACT] Bearings-only tracking with a towed array can be modelled with two parallel filters, one for the measured angle and one for the mirror angle 2h − γ (h = array heading), each weighted by measurement likelihood; after an own-ship manoeuvre one weight goes to 1 and the ghost is eliminated; the scenario used 1-minute sampling and 1.5° bearing noise std — [Radhakrishnan et al., arXiv 2302.01729](https://arxiv.org/abs/2302.01729)
- [FACT] The turn-and-observe-bearing-trend method fails when target signals are intermittent; array snaking can be exploited instead — [Vossen, IOA proceedings](https://www.ioa.org.uk/system/files/proceedings/p_vossen_on_the_use_of_array_snaking_for_resolving_the_left-right_ambiguity_of_linear_antennas_in_towed_arrays.pdf); probability of correct resolution depends on array shape and SNR — [Oxford ORA paper](https://ora.ox.ac.uk/objects/uuid:68cae061-75f7-4619-a7f3-e9b7003e04f4/files/m15cb6d0b21eacfb01639ea91d2a7f49e)
- [FACT] Towed-array processing usually assumes a straight array, so performance degrades during tow-ship manoeuvres — [Rogers & Krolik (2010), Duke Scholars](https://scholars.duke.edu/individual/pub781868)
- [FACT] Bottom-bounce arrivals leave the source direction uncertain for a towed array until further analysis — [FAS ES310 ASW Systems](https://man.fas.org/dod-101/navy/docs/es310/asw_sys/asw_sys.htm)
- [FACT] Sonobuoys: passive DIFAR (directional from a small hydrophone set), VLAD (vertical line of DIFAR hydrophones, better vertical directivity), active DICASS (pings on aircraft command); depth set shallow for surface duct or deep for sound channel; poor DI but very low self-noise, so can outperform larger hull systems; data relayed by VHF — [FAS ES310 ASW Systems](https://man.fas.org/dod-101/navy/docs/es310/asw_sys/asw_sys.htm)
- [FACT] MAD detects the submarine's ferrous mass, works only when the submarine is relatively shallow, and is used mainly for precise localisation for weapon delivery — [FAS ES310 ASW Systems](https://man.fas.org/dod-101/navy/docs/es310/asw_sys/asw_sys.htm)
- [FACT] Hull arrays have a low-frequency limit f_min ≈ c/2L and high-frequency limit c/d — [FAS ES310 Underwater Acoustics](https://man.fas.org/dod-101/navy/docs/es310/uw_acous/uw_acous.htm)
- [FACT] CMO attributed a helicopter detection of a deep submarine to dipping sonar (helicopter otherwise inaudible to subs in that model) — [Matrix Games forum](https://forums.matrixgames.com/viewtopic.php?p=4789844)
- [COMMUNITY] Dangerous Waters: tracks cannot be moved from the towed array to another array; players establish a "master track" and continue via spherical/cylindrical/conformal arrays if the towed array drops; players reel in the towed array before high-speed evasion — [SUBSIM DW thread](https://www.subsim.com/radioroom/showthread.php?p=2749515)
- [COMMUNITY] Cold Waters players report the game does not triangulate between towed and bow arrays; course changes shift energy between bow and towed sonar levels — [SUBSIM Cold Waters thread](https://subsim.com/radioroom/showthread.php?p=2529396)

### Inferences
- [INFERENCE/REC] Minimal sensor descriptor (data, not code): array type; coverage mask over relative bearing (e.g., bow/sphere forward ±~150° with aft baffle; towed omni-in-azimuth but conical/mirror; flank arrays port/starboard broadside sectors); usable bands and DI per band; bearing accuracy as function of SE (σθ shrinking as SE grows, floor at some degrees); self-noise vs own speed curve; deployment state (towed array streamed length/time to stream/retrieve; max safe speed; depth relative to own ship).
- [INFERENCE/REC] Towed-array gameplay rules: (1) every towed bearing produces a contact pair (true + mirror) until disambiguated by a leg change or by correlation with a hull array; (2) during and for a settling period after an own-ship turn (time-based, scaled by turn magnitude and array length), the towed array's bearing accuracy degrades or the array is unusable (supported qualitatively by Rogers & Krolik; settling time is a tuning value); (3) the towed array may sit at a different depth than own ship (possibly below the layer), which is a real tactical lever via TL layer rules.
- [INFERENCE/REC] Baffles create the "clear the baffles" manoeuvre (periodic turns to check astern) and the trailing tactic; minimal implementation is a coverage mask plus own-ship propulsion noise dominating aft.
- [INFERENCE/REC] Threat sensors (sonobuoys, dipping sonar, MAD, surface VDS, active pings from aircraft) can reuse the same sonar-equation path with their own descriptors: sonobuoys have low DI but low self-noise and a chosen depth (above/below layer), MAD is a very short range, depth-limited proximity check. This gives the player a readable reason to go deep/under the layer when aircraft are present.

### Gaps
- Flank arrays and dipping sonar were not covered by fetched sources; their description above is researcher inference.
- No public source fetched gives a towed-array post-turn settling time or a stable-heading requirement; treat as design parameter.
- Generic baffle arc widths are not given by fetched sources.

---

## 5. Contact lifecycle: detection, classification, identification, tracking, loss; merges/splits; operator reports

### Takeaway
A contact should progress through explicit states — raw detection (unconfirmed) → confirmed track → classified (category) → identified (class/hull, rarely) — driven by accumulated signal excess and feature cues (tonals, transients, Doppler), with M-of-N style confirmation/deletion logic, bearing-gated association, and the possibility of merges, splits and ghost tracks; operator reports are the narrative surface of this state machine.

### Cited Findings
- [FACT] Radar/sonar-style trackers commonly hold new tracks as tentative (often hidden from the operator to suppress false tracks at the cost of reporting delay) until enough plots associate; a common promotion rule is M-of-N, e.g., 3 of 5 — [Wikipedia: Radar tracker](https://en.wikipedia.org/wiki/Radar_tracker); MathWorks example confirms after 3 detections in 5 updates and deletes after 6 consecutive misses — [MathWorks: Introduction to Track Logic](https://www.mathworks.com/help/fusion/ug/introduction-to-track-logic.html)
- [FACT] Deletion can use M consecutive misses or M-of-N misses; tentative tracks are often deleted on any miss in the confirmation window; score-based (evidence-accumulation) logic is an alternative to hit counting — [MathWorks: Introduction to Track Logic](https://www.mathworks.com/help/fusion/ug/introduction-to-track-logic.html); [METU tracking lecture notes](https://users.metu.edu.tr/home405/umut/wwwhome/ee793/files/METULecture3.pdf)
- [FACT] Unassigned observations can initiate new tentative tracks; data association methods include nearest-neighbour and PDA — [MathWorks: Introduction to Multiple Target Tracking](https://www.mathworks.com/help/fusion/ug/introduction-to-multiple-target-tracking.html) (search excerpt); [METU lecture](https://users.metu.edu.tr/home405/umut/wwwhome/ee793/files/METULecture3.pdf)
- [FACT] Passive classification relies on frequency content (narrowband lines reveal identity and operating state); matching analysis bandwidth to a narrowband source maximises SNR; waterfall and multi-beam "grams" displays support this — [FAS ES310 ASW Systems](https://man.fas.org/dod-101/navy/docs/es310/asw_sys/asw_sys.htm)
- [FACT] DT is set by the operator and trades detections vs false alarms — [DOSITS Detection Threshold](https://dosits.org/science/advanced-topics/detection-threshold-for-sonar/)
- [FACT] Wandering sonar trackers producing bad bearings are a recognised error source; operators adjust tracks manually — [Naval Submarine League, "The Short-Range Encounter Problem"](https://archive.navalsubleague.org/?p=3882)
- [FACT] CMO's developer listed auto-generated false contacts, operator alertness/fatigue and combat-system capacity limits as possible model additions — [Matrix Games forum](https://forums.matrixgames.com/viewtopic.php?p=4789844)
- [COMMUNITY] Dangerous Waters supports merging tracks; "doing TMA on a merged track is no different than … a single track"; manual TMA lets players merge contacts automatic TMA will not — [SUBSIM DW thread](https://www.subsim.com/radioroom/showthread.php?p=2749515); [SUBSIM search excerpts on DW TMA](https://www.subsim.com/radioroom/showthread.php?p=2756990)
- [COMMUNITY] Cold Waters: a player reports that when a lost contact is regained, the partially developed solution (e.g., 50–55%) restarts from scratch (no developer confirmation; thread identity from search excerpt not verified) — [SUBSIM search results](https://www.subsim.com/radioroom/showthread.php?p=2491698)
- [COMMUNITY] Silent Hunter (WWII-era) sonar operator reports a bearing and an approximate speed category (slow/medium/fast) and acquires contacts on his own; SH4 provides "Report contacts" and "Range to target" orders; players use the hydrophone station for exact bearings — [gry-online SH4 sonar guide](https://www.gry-online.pl/poradniki/silent-hunter-4-wolves-of-the-pacific/sekcja-ii-panel-rozkazow-sonar/zc5cac); [SUBSIM SH threads (search excerpts)](https://www.subsim.com/radioroom/showthread.php?p=1349599)

### Inferences
- [INFERENCE/REC] Suggested contact state machine: `DETECTION (bearing-only blip, not shown or shown faint)` → `TRACK (confirmed via M-of-N or score; assigned designation e.g. S-01)` → `CLASSIFIED (surface/submerged/biologic/merchant/warship, from band ratios, tonal presence, blade-rate, transients, depth cue)` → `IDENTIFIED (class/type; requires tonal match with library and sustained SE)` → `LOST (no association for N updates; keep a "last known" ghost with growing uncertainty)` → `DROPPED`. Classification confidence should accumulate over integrated SE time and specific cue detections, and can be wrong (biologics or merchants misread), which is valuable tension.
- [INFERENCE/REC] Association: gate new detections by bearing (and frequency for tonal lines) against predicted bearings from each track's current solution; when two tracks' bearings cross, allow swap/merge ambiguity (a known real-world headache, cheap to simulate with a simple gate overlap rule). A contact heard on multiple arrays should be associable to one "master track" (DW pattern) to reduce UI clutter.
- [INFERENCE/REC] Losing contact should not wipe TMA history by default (contrast with the reported Cold Waters behaviour); instead keep the last solution and grow its uncertainty with time (dead-reckoned ellipse). This rewards good TMA and supports "re-acquire and confirm" gameplay.
- [INFERENCE/REC] Operator reports are a presentation layer over the state machine: "New contact, bearing 247, designate Sierra-3, faint broadband, towed array, ambiguous bearing 247/113"; "Sierra-3 classified submerged, possible twin-screw…"; "Transient on Sierra-3 bearing … consistent with torpedo tube door". Report timing and wording can encode crew skill (classification delay, false-alarm rate). (The "Sierra" designation convention is a common public usage but was not sourced this session.)

### Gaps
- No public source fetched documents a real navy's contact designation or reporting format; avoid presenting any format as authentic doctrine.
- Classification-by-tonal-library behaviour in DW/Cold Waters is described only by community comments; no official manual text was retrieved.

---

## 6. TMA / bearings-only tracking: observability, bearing rate, Ekelund, manual and automatic methods, uncertainty

### Takeaway
From bearings alone, range is unobservable until own ship manoeuvres (out-manoeuvres the target with a cross-line-of-sight component); bearing rate equals relative speed across the line of sight divided by range, which underlies Ekelund ranging and the "1934 rule"; manual solution matching (dot stack / solution-overlay) and automatic estimators (modified-polar EKF, range-parameterised filter banks, batch least squares, particle filters) all produce a solution plus uncertainty that a game can display as an ellipse and a quality score.

### Cited Findings
**Observability**
- [FACT] With a single sensor, the bearings-only estimation problem "will remain unobservable prior to an own ship maneuver"; nonzero own-ship acceleration is necessary but not sufficient — [NUSC technical memo, DTIC ADA102073](https://apps.dtic.mil/sti/pdfs/ADA102073.pdf)
- [FACT] For angle-only tracking the observer must out-manoeuvre the target (at least one higher order of motion than the target, e.g., constant acceleration vs constant velocity), and the component of sensor manoeuvre perpendicular to the line of sight must be non-zero — [MathWorks: Passive Ranging Using a Single Maneuvering Sensor](https://www.mathworks.com/help/fusion/ug/passive-ranging-using-a-single-maneuvering-sensor.html)
- [FACT] Observability of non-manoeuvring targets requires own-ship manoeuvre (citing Nardone & Aidala 1981, "Observability criteria for bearings-only target motion analysis", IEEE TAES) — [arXiv 2302.01729](https://arxiv.org/abs/2302.01729); observability for leg-by-leg observer trajectories analysed via Fisher information — [Pillon, Pérez-Pignol & Jauffret, IEEE TAES (HAL)](https://hal-univ-tln.archives-ouvertes.fr/hal-03661115/file/DBLE%20COL%20IEEE%20TAES%20V4.pdf); wideband sonar TMA: once the platform out-manoeuvres the target, motion can be inferred even from very noisy measurements — [arXiv 1304.2707](https://arxiv.org/abs/1304.2707)

**Bearing rate, range and manual methods**
- [FACT] Wikipedia lists manual TMA methods: Ekelund ranging, the "1934 rule", Spears wheel; Ekelund is designed for a "2 leg – 1 zig" scenario: estimate bearing rates on each leg (BR1, BR2) and compute range at the time of the manoeuvre as r = (SOA2 − SOA1)/(BR1 − BR2) (text garbled in source; cites Wagner, Mylander & Sanders, *Naval Operations Analysis*, Naval Institute Press, 1999) — [Wikipedia: Target Motion Analysis](https://en.wikipedia.org/wiki/Target_Motion_Analysis)
- [FACT] A US patent on recursive TMA criticises the standard Ekelund procedure for using only two legs and ignoring bearing acceleration — [US Patent 5877998](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/5877998)
- [FACT] Bearing rate along a straight relative track follows BR = BR_CPA·cos²(angular offset from CPA); CPA range Rh = K·(relative speed)/(CPA bearing rate) with K = 1934; range at another point = Rh/cos(offset); "the bearing of CPA is always perpendicular to the relative course" — [Naval Submarine League, Short-Range Encounter Problem](https://archive.navalsubleague.org/?p=3882)
- [FACT] Rules of thumb from the same article: a single-leg solution needs an assumed target speed; a speed guess within ~2 kt gives course within ~10° and range within ~15%; allow at least 10° of bearing change for a precise CPA; a second own-ship leg gives a near-exact solution by intersection of relative-course lines; zigs are detected when measured time between bearing points disagrees with time expected from the solution or when implied speed is unrealistic — [Naval Submarine League](https://archive.navalsubleague.org/?p=3882)
- [FACT] "It is hard to get a solution that matches bearing and bearing rate for more than a few seconds" at short range; "a good dot stack and a bad dot stack look about the same in a short-range encounter"; manoeuvring outside sonar range yields no data, while close manoeuvres prolong the encounter; quiet targets imply high counter-detection risk — [Naval Submarine League](https://archive.navalsubleague.org/?p=3882)

**Automatic estimators**
- [FACT] MLE/batch method: fit N bearings to a constant-velocity target model with state X = [x0, y0, vx, vy], an overdetermined nonlinear system solved by Gauss–Newton — [Wikipedia: Target Motion Analysis](https://en.wikipedia.org/wiki/Target_Motion_Analysis)
- [FACT] Cartesian EKF is unstable for bearings-only TMA (covariance ill-conditioning, premature collapse); a modified-polar (MP) EKF separating observable from unobservable components is stable and asymptotically unbiased — Aidala & Hammel, "Utilization of modified polar coordinates for bearings-only tracking," IEEE Trans. Automatic Control 28(3), 1983 — [Scilit record](https://scilit.com/publications/8661992e71b416a72f3fa971facbb017)
- [FACT] MathWorks example: Cartesian EKF "can often be unstable"; modified spherical coordinates (MSC-EKF) keep range covariance large until the manoeuvre; a range-parameterised Gaussian-sum bank of 10 MSC-EKFs spanning 30–80 km reached ~5 km range error vs 10+ km for a single MSC-EKF; angle uncertainty is a thin ellipse while range uncertainty starts large — [MathWorks: Passive Ranging Using a Single Maneuvering Sensor](https://www.mathworks.com/help/fusion/ug/passive-ranging-using-a-single-maneuvering-sensor.html)
- [FACT] Filters used in recent towed-array BOT work include EKF, UKF, cubature KF, Gauss–Hermite and shifted-Rayleigh filters; particle filters are covered in Ristic, Arulampalam & Gordon, *Beyond the Kalman Filter: Particle Filters for Tracking Applications* (Artech House) — [arXiv 2302.01729](https://arxiv.org/abs/2302.01729)

**Games (TMA presentation)**
- [COMMUNITY] Dangerous Waters: TMA "builds on past data"; the player inputs a guess of range, course and speed and watches whether it fits the bearing history over time; a perfect line of dots in the dot stack is the ideal but rarely achieved; a solution "only tells you the past"; the numbers at the top of the dot stack are generally read as bearing error in degrees — [SUBSIM DW thread](https://www.subsim.com/radioroom/showthread.php?p=2749515); [SUBSIM "TMA dot stack display" (search excerpt)](https://www.subsim.com/radioroom/archive/index.php/t-244772.html)
- [COMMUNITY] Cold Waters: solution quality is a percentage; players report bearing rate is crucial to fast solutions, course changes help, crossing the layer and slowing down improve solutions, and active sonar gives near-instant short-range solutions at the cost of revealing position — [SUBSIM Cold Waters thread](https://subsim.com/radioroom/showthread.php?p=2529396)

### Inferences
- [INFERENCE] Kinematic core: bearing rate (rad/time) = (target speed across LOS − own speed across LOS)/range. Converting units gives range (yd) ≈ 1934 × relative speed across LOS (kt) / bearing rate (deg/min) [derivation: 2025.4 yd/nm ÷ 60 min/h ÷ (π/180) ≈ 1934], which is the constant in the Naval Submarine League article and the "1934 rule" named on Wikipedia.
- [INFERENCE] Ekelund follows from the same identity: if the target holds course/speed across an own-ship turn, the change in bearing rate equals the change in own-ship speed across the LOS divided by range, so R ≈ (OSA2 − OSA1)/(BR1 − BR2) using own-ship speed *across* the line of sight (the Wikipedia text's "SOA" labelling is garbled; treat it as own-ship across-LOS speed). It requires measured, stable bearing rates on both legs and degrades if the target zigs during the manoeuvre — which is exactly the gameplay tension (manoeuvre to range vs. stay steady to measure).
- [INFERENCE/REC] Game TMA should expose observability honestly: before a cross-LOS own-ship manoeuvre the solution should be a line of possible positions along the bearing (range unknown), collapsing to an ellipse after a good leg change. A range-parameterised bank (say 5–10 hypotheses along the bearing) or a particle cloud visualises this directly and is a strong, readable UI metaphor.
- [INFERENCE/REC] Solution quality metric options: (a) normalised bearing-residual RMS over the history window (DW-style dot stack scatter); (b) covariance-derived range uncertainty as a percentage of range (the "solution %" shown to the player, Cold Waters pattern); (c) time since last observable manoeuvre. Weapons-employment logic can consume (b): fire-control accuracy and seeker acquisition probability depend on ellipse size.
- [INFERENCE/REC] Target zigs should be detectable through residual growth (rising dot-stack scatter), not announced — matching the NSL "time interval mismatch" zig detection idea.
- [INFERENCE/REC] Frequency/Doppler (tonal frequency change) is an additional observable that can partly substitute for manoeuvres if base frequency is known (FAS); a game could reward tonal classification with faster TMA convergence.

### Gaps
- Full text of Nardone & Aidala (1981) and Aidala & Hammel (1983) was not retrieved; only abstracts/metadata.
- No official Dangerous Waters manual text on MATE, dot stack or solution "ruler" was retrieved; the manual is a PDF shipped with the game ([DW quick reference, Scribd](https://www.scribd.com/document/63649543/DW-Quick-Reference)). The term "MATE" (manual adaptive/aided target evaluator) was not confirmed by any source fetched this session.
- No source on known Ekelund bias (e.g., systematic under/over-ranging during turn transients) was retrieved.

---

## 7. How existing games abstract these systems (patterns only)

### Takeaway
Published/community evidence shows a spectrum: Dangerous Waters exposes near-procedural manual TMA (bearing history, solution guess, dot-stack residuals) with automatic TMA as an aid; Cold Waters compresses TMA into a solution-percentage meter driven by contact persistence, bearing rate, own noise and layer; Silent Hunter (WWII) uses crew-voiced sonar reports plus a manual hydrophone listening station; CMO uses an FOM-to-range model with latitude-indexed layer/CZ and binary detection. No public documentation of Sea Power's sonar model was found.

### Cited Findings
- [COMMUNITY] Dangerous Waters: manual TMA via solution guess and dot stack; merged tracks; master track across arrays; LOFAR waterfall speed work described by one player as "mostly a distraction"; full manual exists as PDF in installation — [SUBSIM DW thread](https://www.subsim.com/radioroom/showthread.php?p=2749515); [DW quick reference (Scribd)](https://www.scribd.com/document/63649543/DW-Quick-Reference)
- [COMMUNITY] Cold Waters: solution percentage; bearing rate, slow own speed, layer crossing, deep diving and surface sensors improve solutions; active reveals position; no developer response in the fetched thread — [SUBSIM Cold Waters thread](https://subsim.com/radioroom/showthread.php?p=2529396). A separate player comment that "in Cold Waters, TMA is not very accurately portrayed" compared with Sonalysts titles appeared only in a search excerpt whose exact thread was not verified — [SUBSIM search results](https://www.subsim.com/radioroom/showthread.php?p=2491698)
- [COMMUNITY] Silent Hunter: sonar man reports bearing + speed category; "Report contacts" and "Range to target" orders (SH4); hydrophone station gives exact bearing on hover; players use the four-bearing method for course/speed — [gry-online SH4 guide](https://www.gry-online.pl/poradniki/silent-hunter-4-wolves-of-the-pacific/sekcja-ii-panel-rozkazow-sonar/zc5cac); [SUBSIM SH threads (search excerpts)](https://www.subsim.com/radioroom/showthread.php?p=1349599)
- [FACT, developer/forum] CMO: FOM-based sharp detection range; latitude-indexed layer and CZ; DSC 200% range boost; surface duct degraded by sea state; bottom depth and polar ice affect reverberation; masking on same bearing; speed-noise non-linear; candidate additions include soft FOM, cumulative ambient, best-silent speed, operator alertness/fatigue, decoys/noisemakers as entities, false contacts, multistatics — [Matrix Games forum](https://forums.matrixgames.com/viewtopic.php?p=4789844)
- [FACT] Real-world analytic tools also exist publicly: the open-source DebriefNG maritime analysis tool has a manual TMA tutorial and supports TMA using sensor measurements from more than one platform — [DebriefNG TMA tutorial](https://debrief.github.io//library/DebriefNG_TMA_Tutorial.pdf); [Debrief multi-platform TMA note](https://debrief.github.io/new-feature-in-development/technical-demonstration/new-feature-in-development-manual-tma-using-sensor-measurements-from-more-than-one-platform)

### Inferences
- [INFERENCE] Pattern A ("procedural sim", DW): high fidelity of *procedure* (bearing history, residual display, manual solution) on top of a moderate-fidelity acoustics model; high learning curve; players report it is the core satisfaction loop for enthusiasts.
- [INFERENCE] Pattern B ("abstracted meter", Cold Waters): hides estimation behind a percentage, but players still learn the right real-world levers (bearing rate, quiet, layer) because the meter's inputs mirror physical causes. Weakness reported: solution speed sometimes inconsistent with geometry, and progress lost on contact loss.
- [INFERENCE] Pattern C ("crew voice", Silent Hunter): contact information delivered via operator reports with quantised descriptors (speed category), plus an optional manual station for players who want precision. Good accessibility layer.
- [INFERENCE] Pattern D ("operational wargame", CMO): environment-indexed parametric propagation and range-based detection, cheap enough for hundreds of units; hard thresholds are its known weakness.
- [INFERENCE/REC] A modern-era command sim can combine B/C as the default UI (operator reports + solution quality meter + uncertainty ellipse) with A as an optional "expert TMA station" over the same underlying estimator/bearing history — one model, two presentation depths.

### Gaps
- No official or community documentation of Sea Power's sonar/TMA model was found in this session's searches.
- Official Cold Waters and Dangerous Waters manual text was not retrieved; game descriptions rely on community statements and should be treated as patterns, not specifications.

---

## 8. Recommendations: minimum effects for tension, what to omit/approximate, and a fidelity ladder with rough cost

### Takeaway
For tension, model the levers a commander can actually pull and feel — own speed vs noise (with depth-dependent cavitation), the layer, baffles, towed-array ambiguity and turn penalty, bearings-only uncertainty that requires manoeuvre, active counter-detection, transients, ambient/sea-state variability and soft detection probability; approximate propagation with per-region parametric rules or precomputed TL tables, and omit full-wave/ray-traced propagation and signal-level processing at runtime.

### Cited Findings
- [FACT] TL anomaly, layer, duct, CZ, DSC and bottom bounce are the canonical propagation features in unclassified training texts — [FAS ES310 Sonar Propagation](https://man.fas.org/dod-101/navy/docs/es310/SNR_PROP/snr_prop.htm)
- [FACT] Range is unobservable without own-ship manoeuvre — [DTIC ADA102073](https://apps.dtic.mil/sti/pdfs/ADA102073.pdf); [MathWorks](https://www.mathworks.com/help/fusion/ug/passive-ranging-using-a-single-maneuvering-sensor.html)
- [FACT] Players of an abstracted game still converge on real-world levers (bearing rate, slow speed, layer, active trade-off) — [SUBSIM Cold Waters thread](https://subsim.com/radioroom/showthread.php?p=2529396)
- [FACT] A hard detection threshold was recognised by a shipping game's developer as a candidate for softening — [Matrix Games forum](https://forums.matrixgames.com/viewtopic.php?p=4789844)
- [FACT] Cartesian EKF instability is a known failure; MP/MSC or range-parameterised filters are stable alternatives — [Aidala & Hammel (Scilit)](https://scilit.com/publications/8661992e71b416a72f3fa971facbb017); [MathWorks](https://www.mathworks.com/help/fusion/ug/passive-ranging-using-a-single-maneuvering-sensor.html)

### Inferences

#### Must model (minimum for tension) — [INFERENCE/REC]
1. **Speed ↔ noise ↔ self-noise**: own SL and own sensor self-noise rise with speed; a cavitation knee whose speed rises with depth. Creates the core "speed vs stealth vs awareness" dilemma.
2. **Layer (above/below)**: cross-layer TL penalty, layer depth varying by region/season; sensors and towed array depth relative to layer. Creates the hide/seek vertical game.
3. **Baffles & coverage arcs**: blind astern; "clear baffles" manoeuvres; trailing tactics.
4. **Bearings-only uncertainty + observability**: no range without cross-LOS manoeuvre; solution quality grows with bearing change; zigs degrade solutions.
5. **Towed-array L/R ambiguity + turn degradation**: mirror ghost contacts; settling time after turns.
6. **Active sonar counter-detection**: ping = immediate solution at short range but announces own position at longer range (one-way vs two-way TL).
7. **Transients**: tube/door/launch/hull-pop events as bearing-revealing spikes.
8. **Ambient & sea state**: shipping density and weather shift NL per band; rain/biologic events create masking and false contacts.
9. **Soft detection (Pd from SE)**: fading/intermittent contacts near limit; contact loss/re-acquisition with decaying solution.
10. **Classification progression**: tonals/transients required to go from "contact" to "submerged, probable hostile".

#### Approximate (parametric) — [INFERENCE/REC]
- Convergence zones as range annuli (k·R_CZ ± width/2) gated by water-depth excess; R_CZ derived from regional SVP or a latitude/season table.
- Surface duct as a band-limited bonus (above cutoff ∝ duct thickness^-1.5 from the empirical form) degraded by sea state.
- Deep sound channel as a TL bonus when both ends near axis depth (CMO-style multiplier pattern).
- Bottom bounce as an alternate path in deep water with per-bounce bottom loss by bottom type.
- Shallow water as: low-frequency cutoff (Pekeris-style), earlier cylindrical spreading, higher reverberation and bottom loss.
- Absorption from a fixed Thorp band table.
- Ambient from Wenz-shaped tables (shipping class × band, sea state × band).

#### Omit (runtime) — [INFERENCE/REC]
- Runtime full-wave propagation (parabolic equation, normal modes), range-dependent ray tracing per pair per tick, internal waves/fronts/eddies detail, multipath interference fading spectra, element-level beamforming, true signal synthesis for detection (audio can be cosmetic), chemistry-level absorption models, exact real platform signatures (also a classification/ethics constraint).

#### Fidelity ladder with rough computational cost — [ESTIMATE] unless noted
Costs below assume ~50 relevant units, ~5 sensors per unit that matters, 4–8 frequency bands, sonar update 1 Hz; "pairs" = sensor-target-band combinations (~1,000–2,000 per tick). GDScript throughput figures are researcher estimates, not sourced; heavy levels (A3+, T3) likely belong in a GDExtension (C++) or a worker thread.

**Acoustics module (propagation + noise)**
| Level | Model | Runtime cost per tick | Notes |
|---|---|---|---|
| A0 | Fixed detection range per sensor/target class, scaled by target speed | O(pairs), trivial | CMO-like; hard edges; no layer |
| A1 | Parametric sonar equation per band: piecewise spreading + Thorp table + rule-based anomalies (layer penalty, duct, CZ annulus, DSC, bottom bounce, shallow cutoff) | ~tens of flops per pair → ≪1 ms in GDScript for ~2k pairs | **Recommended baseline** |
| A2 | Per-province SVP (Mackenzie) → precomputed TL tables (src depth × rcv depth × range × band) built at load/region change by simple 2D ray tracer; runtime bilinear lookup | Runtime O(1) per pair; build ~10⁵–10⁶ ray steps per province (seconds once, threaded) ; ~0.3 MB/province | **Recommended upgrade**; keeps physics-derived layer/CZ consistent |
| A3 | Runtime 2D ray fan per pair on demand (e.g., ~100 rays × ~500 steps) | ~5×10⁴ steps per pair → too heavy for all pairs at 1 Hz; feasible for a few "focus" pairs or async | Use for sonar-prediction display only |
| A4 | PE/normal-mode full-wave (Jensen et al. class methods) | Offline only | Could generate A2 tables in a tools pipeline |

**Noise sub-model**
| Level | Model | Cost | Notes |
|---|---|---|---|
| N0 | Single noise number vs speed | trivial | No classification depth |
| N1 | Broadband per band: base + slope·log(speed) + depth-dependent cavitation step + machinery modes + transient event list | trivial | **Recommended baseline** |
| N2 | N1 + discrete tonal lines (freq, level, machinery-linked, Doppler-shifted) for classification and frequency-aided TMA | O(lines × observers), small | **Recommended for classification gameplay** |
| N3 | Procedurally rendered waterfall/LOFAR displays and audio from N2 | UI/render cost dominates; simulation unaffected | Presentation only |

**Sensor / contact module**
| Level | Model | Cost | Notes |
|---|---|---|---|
| S0 | Omniscient contacts with fuzz | trivial | Not recommended |
| S1 | Coverage masks/baffles, per-band DI, bearing noise σ(SE), towed mirror ghosts, turn settling timer | O(pairs) | **Baseline** |
| S2 | S1 + Pd(SE) soft detection, M-of-N/score track confirmation & deletion, bearing/frequency gating, merge/split, classification confidence accumulation, operator-report generator | O(detections × tracks) gating, small at these counts | **Recommended** |
| S3 | Multi-hypothesis tracking / JPDA across all contacts | Combinatorial; unnecessary | Omit |

**TMA / tracking module**
| Level | Model | Cost per contact per update | Notes |
|---|---|---|---|
| T0 | Solution-% meter accumulating with time-on-contact × bearing-rate factor × own-quiet factor | trivial | Cold Waters-like; opaque |
| T1 | Player manual solution (range/course/speed) scored against stored bearing history; residual "dot stack" display | O(history length), ~100–1000 points | DW-like expert station; can coexist with T2 |
| T2 | Automatic estimator: batch Gauss–Newton LS on [x0, y0, vx, vy] over sliding window, or a bank of ~5–10 MP/MSC-EKFs (range-parameterised); output mean + 4×4 covariance → error ellipse + quality % | 4-state filter update ≈ hundreds of flops; ×10 hypotheses ×50 contacts = negligible; batch LS with 100 bearings × ~5 iterations ≈ 10⁴ flops | **Recommended core**; Cartesian EKF should be avoided (instability) |
| T3 | Particle filter (≈1k–5k particles/contact) handling multi-modal ambiguity (towed mirror, CZ vs direct-path range bands) | ~10⁵–10⁶ particle-updates/s for 50 contacts; likely needs GDExtension | Optional; visually expressive "probability cloud" |

#### Module boundary hints for later architecture — [INFERENCE/REC]
- **Acoustics module** (pure functions/Resources, testable without scene): environment province data (SVP params, bottom, ambient class, sea state), `TL(src_pos, rcv_pos, band) → (dB, path_type)`, `NL(position, band, weather)`, platform `SL(state, band)` and transient events. No knowledge of contacts.
- **Sensor/contact module**: sensor descriptors (coverage, DI, self-noise), per-tick SE computation using the acoustics API, detection draws, association, track state machine, classification, operator report events. Emits bearing measurements (+ optional frequency) with σ.
- **TMA/tracking module**: consumes timestamped measurements and own-ship navigation history; maintains per-track estimators and/or player manual solutions; exposes solution, covariance/ellipse, quality, residual history. No acoustics knowledge.
- Cross-module tests that matter: SE monotonic in range and own speed; layer penalty only when straddling; towed ghost resolves after cross-LOS turn; estimator range uncertainty does not collapse before a manoeuvre; solution converges within tolerance after a two-leg scenario with σθ ≈ 1–2° (cf. scenario values in [arXiv 2302.01729](https://arxiv.org/abs/2302.01729)).

### Gaps
- All computational cost figures are researcher estimates; no benchmark of GDScript vs GDExtension for these specific workloads was located in this session.
- No public source quantifies how much each effect contributes to perceived tension; the "must model" list is a design inference from the physics, the observability literature and player behaviour reported in community threads.
- Sea Power's approach (a modern-era peer title) remains undocumented in this research; a follow-up search of its official manual or developer notes is recommended before final architecture.
