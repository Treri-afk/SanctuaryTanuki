# Sons du jeu

Fichiers légers produits par `tools/convert_sounds.py` à partir de la banque `sound design/` à la racine du
projet (1,2 Go, ignorée par Godot grâce à `sound design/.gdignore` et par git) : sons courts en WAV mono,
ambiances en MP3 stéréo de ~80 s. Pour changer un extrait (source, découpe, hauteur), modifier la table `SOUNDS`
du script et le relancer :

    python3 tools/convert_sounds.py            # tout
    python3 tools/convert_sounds.py bell cat   # seulement ces sons

Les sons courts remplacent le son synthétisé du même nom (`autoload/sfx.gd`, volumes dans `FILE_GAIN`) ;
les `amb_*` sont les ambiances de `scripts/ambience.gd`. Un fichier déposé ici à la main marche aussi.

**Licences** : les packs (BluezoneCorp, InMotionAudio, Justsoundeffects, Mechanical Wave, Nick McMahan) semblent
venir des bundles GDC de Sonniss (libres de droits, usage commercial). À vérifier et à noter ici avant une sortie.

| Fichier | Source |
|---|---|
| `pickup.wav` | InMotionAudio - Wood — `WOODFric_Scrapes09_InMotionAudio_Wood.wav` |
| `putdown.wav` | InMotionAudio - Wood — `WOODImpt_Drops20_InMotionAudio_Wood.wav` |
| `hammer.wav` | BluezoneCorp - Stone Impact — `Bluezone_BC0297_stone_impact_hammer_015.wav` |
| `snip.wav` | Mechanical Wave - Sound Effects Collection — `TOOLHand_Shears Slide Open Close_ 01_MWSFX_SEC.wav` |
| `slash.wav` | InMotionAudio - Wood — `WOODBrk_Snap09_InMotionAudio_Wood.wav` |
| `coin.wav` | BluezoneCorp - Stone Impact — `Bluezone_BC0297_stone_impact_steel_bar_01_010.wav` |
| `coin_2.wav` | BluezoneCorp - Stone Impact — `Bluezone_BC0297_stone_impact_steel_bar_01_010.wav` |
| `bell.wav` | Mechanical Wave - Sound Effects Collection — `BELLHand_Metallic Bell_ 22_MWSFX_SEC.wav` |
| `paper.wav` | Mechanical Wave - Cardboard and Paper — `PAPRHndl_Large Book Squeak Page Turn_ 01_MWSFX_CDAP.wav` |
| `paper_crumple.wav` | Mechanical Wave - Cardboard and Paper — `PAPRHndl_Paper Sheet Crumple_ 04_MWSFX_CDAP.wav` |
| `door_slide.wav` | Mechanical Wave - Cardboard and Paper — `OBJPack_Big Cardboard Box Slide_ 04_MWSFX_CDAP.wav` |
| `cat.wav` | Mechanical Wave - Sound Effects Collection — `ANMLCat_Cat Moew_ 03_MWSFX_SEC.wav` |
| `match_strike.wav` | Mechanical Wave - Sound Effects Collection — `ICEMisc_Ice Sizzle_05_MWSFX_SEC.wav` |
| `plop.wav` | InMotionAudio - Cave Design — `WATRDrip_SingleDrip03_InMotionAudio_CaveDesign.wav` |
| `drip.wav` | InMotionAudio - Cave Design — `WATRDrip_SingleDrip03_InMotionAudio_CaveDesign.wav` |
| `water_draw.wav` | InMotionAudio - Cave Design — `AMBUndwtr_WaterFlow05_InMotionAudio_CaveDesign.wav` |
| `rope.wav` | InMotionAudio - Wood — `WOODMvmt_FoleyMovement01_InMotionAudio_Wood.wav` |
| `tea.wav` | InMotionAudio - Cave Design — `AMBUndwtr_WaterFlow05_InMotionAudio_CaveDesign.wav` |
| `pour_loop.wav` | InMotionAudio - Cave Design — `AMBUndwtr_WaterFlow05_InMotionAudio_CaveDesign.wav` |
| `woodpecker.wav` | Justsoundeffects - Forests of Norway — `BIRDMisc_Green Woodpeckers Calling On Lakeshore Far Away_JSE_FoN.wav` |
| `woodpecker_2.wav` | Justsoundeffects - Forests of Norway — `BIRDMisc_Green Woodpeckers Calling On Lakeshore Far Away_JSE_FoN.wav` |
| `basin_drips.wav` | InMotionAudio - Cave Design — `WATRDrip_SingleDripDesign05_InMotionAudio_CaveDesign.wav` |
| `amb_morning.mp3` | Justsoundeffects - Forests of Norway — `AMBForst_Morning Small Birch Forest Willow Warbler Singing Many Insects Humming_JSE_FoN_Quad.wav` |
| `amb_day.mp3` | Justsoundeffects - Forest Ambiences — `AMBForst_Spring Noon Deciduous Forest Gentle Wind Leaves Rustling Blackbird Raven in Background_JSE_FA.wav` |
| `amb_day_b.mp3` | Justsoundeffects - Forest Ambiences — `BIRDSong_Spring Noon Coniferous Forest Coal Tit Wind_JSE_FA.wav` |
| `amb_evening.mp3` | Justsoundeffects - Forest Ambiences — `AMBForst_Spring Afternoon Edge of Mixed Forest Yellowhammer Eurasian Blackcap Tree Pipit Insects_JSE_FA.wav` |
| `amb_night.mp3` | Justsoundeffects - Forest Ambiences — `BIRDPrey_Spring Night Deciduous Forest Many Tawny Owls Wind Leaves Rustling_JSE_FA.wav` |
| `amb_forest.mp3` | InMotionAudio - The Forest — `AMBForst_Forest08_InMotionAudio_TheForestSamples.wav` |
| `amb_wind.mp3` | Justsoundeffects - Forests of Norway — `WINDVege_Mixed Forest Wind Blowing Through Birches Beeches And Spruces Tree Trunk Squeaking_JSE_FoN_Quad.wav` |
| `amb_stream.mp3` | Nick McMahan - Cascadia Flowing Water — `WATRFlow_Stream Small Alpine Loop_Cascadia FW.wav` |
| `amb_falls.mp3` | Nick McMahan - Cascadia Flowing Water — `WATRFlow_Creek Rocky Distant Falls Loop_Cascadia FW.wav` |
