# Instalimi i 22 ilustrimeve te tregimit (Samsung S23)

Keto jane **vizatime ilustruese**, jo fotografi personale. Tregimi eshte vetem pilot; Living Library AI mbetet nje aplikacion i pergjithshem per libra dhe dokumente.

## Pa kompjuter dhe pa ngarkim ne GitHub

1. Shkarko `Living_Library_22_Fotografite_Assets.zip` ne telefon. **Mos e nxirr ZIP-in.**
2. Instalo APK-ne ekzistuese te Living Library AI nga artefakti i GitHub Actions.
3. Hap aplikacionin, zgjidh **Studio AI** dhe hap tregimin pilot.
4. Perdore kontrollin e importit te ilustrimeve dhe zgjidh ZIP-in nga **Downloads**.
5. Aplikacioni verifikon te gjitha 22 skedaret `frame_01.jpg` deri `frame_22.jpg`, pastaj i ruan lokalisht. Kontrollo treguesin **22/22** dhe pamjet e skenave.

Kodi perkates: `lib/features/ai_film/pilot_assets.dart` dhe `lib/main.dart` (`_PilotImportControl`). Importi nuk kerkon server, API key ose publikim ne repository.

**Kufizim:** Kjo procedure importon vizatimet ne instalimin lokal; nuk i fut ato ne APK e ndertuar. Per APK me ilustrimet te perfshira ne build duhet nje pipeline i vecante dhe kontroll i permbajtjes se APK-se. Mos deklaro se jane te integruara ne APK pa kete verifikim.
