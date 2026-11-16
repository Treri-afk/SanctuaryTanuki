"""Convertit des extraits de la banque « sound design/ » (1,2 Go, ignorée par Godot et git) en sons légers pour
le jeu, dans assets/sounds/ : chaque son du jeu (nom attendu par autoload/sfx.gd ou scripts/ambience.gd) a sa
source, son extrait et son traitement dans la table SOUNDS ci-dessous.

  - sons courts : WAV mono 44,1 kHz 16 bits, recadrés autour de l'attaque, crête normalisée à -1 dB ;
  - ambiances : MP3 stéréo 44,1 kHz 128 kb/s, ~80 s, fondus aux deux bouts (le jeu les enchaîne en fondu croisé).

Lancer depuis la racine du projet :  python3 tools/convert_sounds.py   (ffmpeg requis)
"""
import os, subprocess, sys, wave, struct, tempfile, re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "sound design")
DST = os.path.join(ROOT, "assets", "sounds")

# nom du son -> (dossier/fichier source, réglages)
#   start/dur : extrait en secondes ; "peak" : recadre automatiquement autour de la crête la plus forte
#   pitch : facteur de hauteur ; fade : fondu de sortie (s) ; amb : ambiance (MP3 stéréo)
SOUNDS = {
    # ---- gestes et objets
    "pickup":       ("InMotionAudio - Wood/WOODFric_Scrapes09_InMotionAudio_Wood.wav", {}),
    "putdown":      ("InMotionAudio - Wood/WOODImpt_Drops20_InMotionAudio_Wood.wav", {}),
    "hammer":       ("BluezoneCorp - Stone Impact/Bluezone_BC0297_stone_impact_hammer_015.wav", {"fade": 0.15}),
    "snip":         ("Mechanical Wave - Sound Effects Collection/TOOLHand_Shears Slide Open Close_ 01_MWSFX_SEC.wav", {"peak": (0.06, 0.32)}),
    "slash":        ("InMotionAudio - Wood/WOODBrk_Snap09_InMotionAudio_Wood.wav", {"peak": (0.05, 0.75), "fade": 0.25}),
    "coin":         ("BluezoneCorp - Stone Impact/Bluezone_BC0297_stone_impact_steel_bar_01_010.wav", {"peak": (0.01, 0.55), "pitch": 1.7, "fade": 0.2}),
    "coin_2":       ("BluezoneCorp - Stone Impact/Bluezone_BC0297_stone_impact_steel_bar_01_010.wav", {"peak": (0.01, 0.55), "pitch": 2.0, "fade": 0.2}),
    "bell":         ("Mechanical Wave - Sound Effects Collection/BELLHand_Metallic Bell_ 22_MWSFX_SEC.wav", {"fade": 1.5}),
    "paper":        ("Mechanical Wave - Cardboard and Paper/PAPRHndl_Large Book Squeak Page Turn_ 01_MWSFX_CDAP.wav", {"dur": 1.2, "fade": 0.3}),
    "paper_crumple": ("Mechanical Wave - Cardboard and Paper/PAPRHndl_Paper Sheet Crumple_ 04_MWSFX_CDAP.wav", {"dur": 1.0, "fade": 0.3}),
    "door_slide":   ("Mechanical Wave - Cardboard and Paper/OBJPack_Big Cardboard Box Slide_ 04_MWSFX_CDAP.wav", {"dur": 1.1, "fade": 0.3}),
    "cat":          ("Mechanical Wave - Sound Effects Collection/ANMLCat_Cat Moew_ 03_MWSFX_SEC.wav", {"fade": 0.3}),
    "match_strike": ("Mechanical Wave - Sound Effects Collection/ICEMisc_Ice Sizzle_05_MWSFX_SEC.wav", {"peak": (0.02, 1.1), "fade": 0.4}),
    "plop":         ("InMotionAudio - Cave Design/WATRDrip_SingleDrip03_InMotionAudio_CaveDesign.wav", {"pitch": 0.75}),
    "drip":         ("InMotionAudio - Cave Design/WATRDrip_SingleDrip03_InMotionAudio_CaveDesign.wav", {}),
    "water_draw":   ("InMotionAudio - Cave Design/AMBUndwtr_WaterFlow05_InMotionAudio_CaveDesign.wav", {"start": 1.0, "dur": 1.6, "fade": 0.6}),
    "rope":         ("InMotionAudio - Wood/WOODMvmt_FoleyMovement01_InMotionAudio_Wood.wav", {"dur": 1.3, "fade": 0.4}),
    "tea":          ("InMotionAudio - Cave Design/AMBUndwtr_WaterFlow05_InMotionAudio_CaveDesign.wav", {"start": 4.0, "dur": 2.0, "fade": 0.8}),
    "pour_loop":    ("InMotionAudio - Cave Design/AMBUndwtr_WaterFlow05_InMotionAudio_CaveDesign.wav", {"start": 0.5, "dur": 9.5, "fade": 0.5}),
    "woodpecker":   ("Justsoundeffects - Forests of Norway/BIRDMisc_Green Woodpeckers Calling On Lakeshore Far Away_JSE_FoN.wav", {"start": 2.0, "dur": 7.0, "fade": 1.5}),
    "woodpecker_2": ("Justsoundeffects - Forests of Norway/BIRDMisc_Green Woodpeckers Calling On Lakeshore Far Away_JSE_FoN.wav", {"start": 15.0, "dur": 7.0, "fade": 1.5}),
    "basin_drips":  ("InMotionAudio - Cave Design/WATRDrip_SingleDripDesign05_InMotionAudio_CaveDesign.wav", {"fade": 0.5}),
    "leaves":       ("Sonic Bat - Videogame Foley Essentials Vol. II/SBvfe2_Dry Tree Branches Contact 024.wav", {"peak": (0.04, 0.55), "fade": 0.25}),
    "ui_click":     ("Rogue Waves - Kawaii UI/UIClick_Operating System UI Cursor_RogueWaves_KawaiiUI.wav", {}),
    "tick":         ("Rogue Waves - Kawaii UI/UIClick_Hand Pop UI Diminished 1_RogueWaves_KawaiiUI.wav", {}),
    # ---- ambiances (enchaînées en fondu croisé par scripts/ambience.gd)
    "amb_morning":  ("Justsoundeffects - Forests of Norway/AMBForst_Morning Small Birch Forest Willow Warbler Singing Many Insects Humming_JSE_FoN_Quad.wav", {"amb": True, "start": 20, "dur": 80}),
    "amb_day":      ("Justsoundeffects - Forest Ambiences/AMBForst_Spring Noon Deciduous Forest Gentle Wind Leaves Rustling Blackbird Raven in Background_JSE_FA.wav", {"amb": True, "start": 6, "dur": 80}),
    "amb_day_b":    ("Justsoundeffects - Forest Ambiences/BIRDSong_Spring Noon Coniferous Forest Coal Tit Wind_JSE_FA.wav", {"amb": True, "start": 6, "dur": 80}),
    "amb_evening":  ("Justsoundeffects - Forest Ambiences/AMBForst_Spring Afternoon Edge of Mixed Forest Yellowhammer Eurasian Blackcap Tree Pipit Insects_JSE_FA.wav", {"amb": True, "start": 4, "dur": 80}),
    "amb_night":    ("Justsoundeffects - Forest Ambiences/BIRDPrey_Spring Night Deciduous Forest Many Tawny Owls Wind Leaves Rustling_JSE_FA.wav", {"amb": True, "start": 0, "dur": 52}),
    "amb_forest":   ("InMotionAudio - The Forest/AMBForst_Forest08_InMotionAudio_TheForestSamples.wav", {"amb": True, "start": 10, "dur": 80}),
    "amb_wind":     ("Justsoundeffects - Forests of Norway/WINDVege_Mixed Forest Wind Blowing Through Birches Beeches And Spruces Tree Trunk Squeaking_JSE_FoN_Quad.wav", {"amb": True, "start": 10, "dur": 80}),
    "amb_stream":   ("Nick McMahan - Cascadia Flowing Water/WATRFlow_Stream Small Alpine Loop_Cascadia FW.wav", {"amb": True, "start": 10, "dur": 60, "mono": True}),
    "amb_room":     ("Systematic Sound - General Ambience Series - Quiet Rooms 01/AMBRoom_Quiet Room Flat C Livingroom 02_SYSO_SYSO0013.wav", {"amb": True, "start": 20, "dur": 60}),
    "amb_meadow":   ("Systematic Sound - General Ambience Series - Rural Countryside 01/AMBRurl_Field Wheat Dry Sizzle Insects Wind Soft_SYSO_SYSO011.wav", {"amb": True, "start": 15, "dur": 70}),
    "amb_falls":    ("Nick McMahan - Cascadia Flowing Water/WATRFlow_Creek Rocky Distant Falls Loop_Cascadia FW.wav", {"amb": True, "start": 10, "dur": 60, "mono": True}),
}


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("ffmpeg : " + r.stderr[-600:])
    return r


def peak_time(path):
    """Instant (s) de la crête la plus forte : décodage mono 16 bits temporaire puis recherche."""
    with tempfile.TemporaryDirectory() as d:
        tmp = os.path.join(d, "a.wav")
        run(["ffmpeg", "-y", "-v", "error", "-i", path, "-ac", "1", "-ar", "22050", "-sample_fmt", "s16", tmp])
        w = wave.open(tmp)
        n = w.getnframes()
        data = struct.unpack("<%dh" % n, w.readframes(n))
        i = max(range(n), key=lambda k: abs(data[k]))
        return i / 22050.0


def max_volume(path, flt):
    r = run(["ffmpeg", "-v", "info", "-i", path, "-af", flt + ",volumedetect", "-f", "null", "-"])
    m = re.search(r"max_volume: (-?[\d.]+) dB", r.stderr)
    return float(m.group(1)) if m else 0.0


def convert(name, rel, opt):
    src = os.path.join(SRC, rel)
    if not os.path.exists(src):
        print("ABSENT", rel)
        return
    start, dur = opt.get("start", 0.0), opt.get("dur", None)
    if "peak" in opt:
        before, after = opt["peak"]
        t = peak_time(src)
        start, dur = max(0.0, t - before), before + after
    filters = []
    if opt.get("pitch"):
        p = opt["pitch"]
        filters.append(f"asetrate=96000*{p},aresample=96000")
    trim = f"atrim=start={start}" + (f":duration={dur}" if dur else "")
    filters.insert(0, trim)
    filters.append("asetpts=PTS-STARTPTS")
    amb = opt.get("amb", False)
    if amb:
        filters.append("afade=t=in:st=0:d=2.5")
        if dur:
            filters.append(f"afade=t=out:st={dur - 2.5}:d=2.5")
    else:
        filters.append("afade=t=in:st=0:d=0.004")
        if opt.get("fade") and dur:
            filters.append(f"afade=t=out:st={max(0.0, dur - opt['fade'])}:d={opt['fade']}")
        elif opt.get("fade"):
            filters.append("areverse,afade=t=in:st=0:d=%s,areverse" % opt["fade"])
    chain = ",".join(filters)
    gain = -1.0 - max_volume(src, chain + (",pan=mono|c0=0.5*c0+0.5*c1" if not amb else ""))
    chain += f",volume={gain:.2f}dB"
    if amb:
        out = os.path.join(DST, name + ".mp3")
        ch = "1" if opt.get("mono") else "2"
        run(["ffmpeg", "-y", "-v", "error", "-i", src, "-map", "0:a:0", "-vn", "-map_metadata", "-1", "-af", chain,
             "-ac", ch, "-ar", "44100", "-c:a", "libmp3lame", "-b:a", "96k" if ch == "1" else "128k", out])
    else:
        out = os.path.join(DST, name + ".wav")
        run(["ffmpeg", "-y", "-v", "error", "-i", src, "-map", "0:a:0", "-vn", "-map_metadata", "-1", "-af", chain,
             "-ac", "1", "-ar", "44100", "-sample_fmt", "s16", out])
    print("OK %-14s %6.1f Ko  <- %s" % (name, os.path.getsize(out) / 1024, os.path.basename(rel)[:60]))


if __name__ == "__main__":
    os.makedirs(DST, exist_ok=True)
    only = set(sys.argv[1:])
    for name, (rel, opt) in SOUNDS.items():
        if not only or name in only:
            convert(name, rel, opt)
