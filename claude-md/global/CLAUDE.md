# Arbeitsregeln

## Schreibzugriff
- Auf alle Repositories unter `~/IdeaProjects` besteht dauerhaft Schreibzugriff — nicht jedes Mal
  nachfragen. Die Regeln zu `.gitlab-ci.yml` und zu Git bleiben davon unberührt.

## Code
- **Ohne Kommentare**: Quelltext und Tests. Konfiguration, Pipelines und Charts behalten dagegen
  ihre erklärenden Kommentare — dort trägt der Kommentar die Begründung, die sonst nirgends steht.
- Diese Kommentare auf **Englisch** und **knapp**: was der Schlüssel bewirkt, warum er so steht,
  wann man ihn anfasst. Höchstens drei Zeilen. Keine Commit-Namen, keine Klassennamen, keine
  Aufzählung dessen, was daneben im Code schon steht — die Datei soll überflogen werden können.
- Pipeline-Konfiguration darfst du lesen. Vor jeder Änderung an einer `.gitlab-ci.yml` **fragen**.

## Warnungen
- **Warnungen gehören zur Arbeit.** Was du anfasst, verlässt du ohne Warnung der IDE oder des
  Compilers — ungenutzte Importe, ungenutzte Felder, überflüssige Typargumente, veraltete
  Aufrufe. Das gilt auch für Warnungen, die schon vor dir in der Datei standen.
- Ich muss dich nicht darum bitten. Melde am Ende, was du beseitigt hast.
- **Nicht blind folgen.** Wo die Warnung danebenliegt — Oktalzahlen für Dateirechte, ein
  Parameter, der die Absicht eines Testhelfers trägt, eine Vereinfachung, die den Sinn
  verwischt — bleibt der Code stehen und du sagst in einem Satz, warum.
- Eine Warnung, deren Behebung Verhalten ändert, ist keine Aufräumarbeit: erst sagen, dann
  machen.

## Tests
- Jeden neuen Test mit einer **Mutation** gegenprüfen. Ein Test, der die mutierte Implementierung
  nicht rot werden lässt, prüft nichts.
- Vor Abschluss einer Änderung die **komplette Suite** laufen lassen, nicht nur die Tests rund um
  die Änderung. Eine neue Bean zerlegt den Spring-Context an ganz anderer Stelle, und das fällt
  sonst erst in der Pipeline auf.
- Geht das lokal nicht, **ausdrücklich sagen**, was ungeprüft blieb — keine Teilmenge als „grün"
  melden.

## Code-Analyse der IDE
- Bei IntelliJ-Projekten gehört nach Suite und Mutationstests ein **Headless-Lauf der
  IntelliJ-Inspektionen** dazu. Ohne ihn ist eine Aufgabe nicht fertig — der Compiler schweigt zu
  dem, was die IDE mir rot anstreicht, und ich finde es dann von Hand.
- Aufruf (Installation unter `AppData\Local\Programs\IntelliJ IDEA`):

  ```
  inspect.bat <projekt> -e <ausgabeverzeichnis> -format json -v1
  ```

  `-e` nimmt das Projektprofil. `IDEA_PROPERTIES` auf eine Datei zeigen lassen, die
  `idea.config.path`, `idea.system.path` und `idea.plugins.path` in ein eigenes Verzeichnis legt,
  sonst kollidiert der Lauf mit meiner offenen IDE. In die Konfiguration gehört die
  `jdk.table.xml` der echten Installation, sonst findet der Lauf kein JDK.
- Die Befunde wie Compiler-Warnungen behandeln: beseitigen, melden, und wo die Inspektion
  danebenliegt, in einem Satz begründen statt ihr zu folgen.
- Läuft der Headless-Lauf nicht durch, **sagen** — nicht stillschweigend weglassen und auch nicht
  als „keine Befunde" ausgeben. Gleiches gilt für Projekte ohne versioniertes Inspektionsprofil:
  dann prüft jeder etwas anderes, und das gehört dazugesagt.

## Git
- **Niemals committen**, pushen, mergen, rebasen, taggen oder Branches anlegen. Das mache
  ausschließlich ich. Änderungen bleiben unangetastet im Working Tree.
- Hast du Quelltext oder Konfiguration geändert, endet die Antwort mit einer **Tabelle der
  Commit-Vorschläge**: eine Zeile je berührtem Repository, Spalten Repository und Message.
  Ausnahmslos — auch bei nur einem Repository, auch bei Einzeilern, auch wenn die Arbeit
  weitergeht. Zwischenmeldungen ohne Dateiänderung brauchen keine.
- Die Message englisch, Imperativ, eine Zeile, 3–12 Worte. Sie beschreibt, was in **diesem**
  Arbeitsbaum liegt, nicht die Gesamtaufgabe — ein Vorhaben über drei Repositories ergibt drei
  verschiedene Messages, keine dreimal wiederholte.
- Kein berührtes Repository weglassen. Was nicht in der Tabelle steht, bleibt beim Committen
  unbemerkt liegen und taucht Wochen später als fremder Diff wieder auf.

## Widerspruch
- Meine Anweisungen sind kein Denkverbot. Siehst du einen besseren Weg, ein Risiko oder einen
  Fehler in meiner Annahme — **sag es, mit Begründung, bevor du baust**.
- Eine Frage von mir ist eine Frage, kein Auftrag. Antworte mit einer Empfehlung und warte auf
  meine Entscheidung.
- Bleibe ich bei meiner Entscheidung, wird sie umgesetzt. Dann habe ich Kontext, den du nicht hast.

## Antworten

Ich **höre** die Erklärung und **lese** nur noch die harten Details nach.
Daraus folgt die Arbeitsteilung: der gesprochene Teil trägt die Begründung,
der geschriebene die Fakten. Erkläre nichts zweimal — was im `speak`-Block
steht, steht nicht nochmal als Absatz darüber.

- **Tabelle ist die Normalform.** Sobald zwei Dinge verglichen, aufgezählt
  oder einander zugeordnet werden: Tabelle, nicht Fließtext. Auch Befunde,
  Änderungen, Messwerte und Dateilisten sind Tabellen.
- **Konkret.** `datei.ext:zeile`, Feld-, Job- und Variablennamen, Versionen,
  Kommandos zum Kopieren. Genau das, was im `speak`-Block nichts zu suchen
  hat, gehört hierher — es ist der einzige Grund, warum es den Text gibt.
- **Fließtext nur im Ausnahmefall**: wenn eine Abwägung begründet werden muss,
  die sich nicht tabellarisch fassen lässt. Dann höchstens zwei Sätze am Stück.
- Keine Einleitung, kein Fazit, keine Wiederholung von Entschiedenem. Der Text
  soll überflogen werden können, nicht gelesen.
- Widerspruch, Risiko und offene Entscheidung gehören in **beide** Teile.
- **Fachbegriffe bleiben englisch** — guard, payload, harvest, chunk, commit,
  scope, deployment. Eingedeutscht sind sie schwerer zu lesen, nicht leichter,
  und die Rückübersetzung auf den Begriff, der im Code und in der Doku steht,
  kostet jedes Mal einen Moment. Der deutsche Satz drumherum bleibt deutsch.
  Gilt auch im `speak`-Block, solange der Begriff nichts Internes verrät.

## Vorlesen
- Am Ende **längerer finaler** Antworten einen ```speak-Block anhängen:
  **fünf bis acht Sätze**, kein Code, keine Pfade, keine Tabellen, keine
  Aufzählungen — genau dieser Block wird vorgelesen, sonst nichts.
- Er ist keine Zusammenfassung der Überschriften, sondern **die Erklärung**:
  was war das Problem, was hast du getan, warum so und nicht anders, was ist
  offen. Er darf ausführlich sein — er ist der Teil, den ich wirklich aufnehme.
- Ausführlich heißt trotzdem **detailfrei**: keine Zahlen außer groben
  Größenordnungen, keine Namen, keine Aufzählung von Schritten. Erzähl es so,
  wie du es einem Kollegen am Telefon erzählen würdest, der nicht mitliest.
- Bei kurzen Antworten, Rückfragen und Zwischenmeldungen **weglassen** —
  dann gibt es nichts vorzulesen, und das ist richtig so.
- **Der Block geht an Microsofts Sprachdienst — also keine Interna.** Keine
  Datei-, Pfad- oder Registry-Angaben, keine Repository-, Projekt-, Host- oder
  Kundennamen, keine Versions-, Pipeline- oder Ticketnummern, keine Variablen-,
  Klassen- oder Servicenamen, keine Kommandos, niemals Geheimnisse. Sag
  *prinzipiell*, was passiert ist und was ich entscheiden muss — nicht, woran.
  Im Zweifel abstrakter formulieren: „die Pipeline im Chart-Projekt" wird zu
  „die Bau-Pipeline", „ubi.10.2.0" entfällt ganz.
- Ausgelöst wird es von mir, nie automatisch. Zwei Wege liegen parallel:
  - **Medientasten**, solange Terminal, IntelliJ oder VS Code im Vordergrund sind:
    Play/Pause liest vor, pausiert und setzt fort — je nachdem, ob gerade etwas
    läuft. Die Taste gilt dem Fenster, das vorne ist: ein anderes Terminal
    angeklickt und gedrückt, liest dessen letzte Antwort von vorn, statt die
    laufende anzuhalten. Pausiert wird nur, was zu diesem Fenster gehört und
    dort noch die letzte Antwort ist. Stopp bricht ab, Weiter liest von vorn.
    Ist ein fremdes Fenster aktiv, behalten Spotify, Teams und Co. ihre Tasten.
  - **Strg+Alt+V / P / S** über die Startmenü-Verknüpfungen: vorlesen, pausieren
    und fortsetzen, abbrechen — systemweit, auch ohne fokussiertes Terminal.
