FPU-Check 1.44
---------------

(Dear english reader!
 I'm sorry, but until now there is no full english description of "FPU-Check"
 available. "FPU-Check" is a program to check the reliability of the 
 floating point unit (FPU) of your Atari TT, or any other Atari computer 
 which is equipped with a Line-F floating point coprocessor, including
 the Falcon and accelerator boards for the ST series. 
 The dialog box is held in english and, I hope so, is easy to use. If you 
 have problems with "FPU-Check" please contact me via email: 
                  sk@lumumba.shnet.org   (Stefan Krey))

Fuer die deutschsprachigen Leser:

0. Allgemeines

FPU-Check 1.0 ist eigentlich als "Quick-Hack" (Puristen wrden sagen, das
ist es immer noch:-) in einer Zeit des ungeduldigen Wartens auf die letzten
Bauteile meiner PAK-68/3 entstanden. In dieser Zeit verfolgte ich ausserdem
die rege Diskussion in 'maus.sys.atari.hardware' ber dieses Projekt und
las des ”fteren von FPU-Problemen, 11 Bomben (Line-F-Exception) etc.,
insbesondere bei tuning-Versuchen auf Taktfrequenzen >32 MHz. Da es m.W.
noch kein Programm gab, mit dem man die FPU richtig fordern konnte und
das aufgetretene Fehler, Rechenfehler wie Exceptions, im Klartext zurck-
meldete, habe ich mich darangesetzt ein solches zu schreiben. Die Fraktal-
und Raytrace-Programme mit FPU-Untersttzung sind zwar immer ein guter
Test fr die FPU, aber Zuverl„ssigkeitsaussagen lassen sich schwer treffen,
wenn das Programm sich beim ersten Fehler mit Bombenwurf verabschiedet.

FPU-Check f„ngt die auftretenden FPU-Exceptions ab und meldet sie im
Klartext, zusammen mit dem Namen des aktuellen Tests, soda man evtl.
feststellen kann, ob Fehler nur bei bestimmten Routinen auftreten. Im
'Handbetrieb' hat man bei einem Fehler die Wahl, ob man mit dem n„chsten
Test fortfahren oder den Testlauf beenden m”chte. L„t man ein Logfile
ausgeben, so wird grunds„tzlich der komplette Testlauf absolviert und
eventuelle Fehler werden protokolliert. Das gilt allerdings nicht fr
die 'ganz harten' F„lle wie Bus- und Adrefehler, sie werden zwar auch
abgefangen, fhren aber immer zur Beendigung des Testlaufs, da in den
meisten F„llen kein Weiterarbeiten mehr m”glich ist.


1. Funktionen

  FPU-Type    :  gibt den Typ der gefundenen FPU aus. Dient nur zur Unterscheidung
                 der beiden Typen 68881 und 68882. Die Angabe 'Line-F' ist
                 eigentlich berflssig, da mit diesem Programm nur Line-F-FPU's
                 getestet werden k”nnen.

                 Wer sich nicht ganz sicher ist, vor was fr einem Rechner er sitzt,
                 der kann sich auch mit dem beiliegenden Progr„mmchen CPUFPU.PRG
                 Klarheit verschaffen.

  RealMath,
  TrigLog     :  Die bekannten Hochsprachen-Benchmarks der c't, allerdings
                 um den Faktor 10 gestreckt! Zeitmessung fr
                 Geschwindigkeitsvergleiche. Rechenfehler werden gemeldet!

  Fractal,
  SinCos      :  Die Ausfhrungszeit dieser Routinen wird ebenfalls fr
                 Benchmarkzwecke ausgegeben.
                 'Fractal' zeigt den Ausschnitt Re(z)=-1.257231..-1.255960
                                                Im(z)= 0.03024525..0.03151625
                 der Mandelbrot-Menge bei max. 211 Iterationen. Berechnet wird
                 der Ausschnitt in einfacher Genauigkeit. Die Iterations-
                 routine wurde in Assembler codiert.

                 SinCos zeigt den seltsamen Attraktor der Iteration
                 x <- cos(y) - sin(a*x)
                 y <- x + y
                 Mit dem Parameter a nahe bei pi. Es werden 50000 Iterationen
                 durchlaufen.

                 Aufgrund der Vielzahl der FPU-Operationen, ist es sehr
                 wahrscheinlich, da bei fehlerhaft arbeitender FPU auch
                 ein Fehler entdeckt wird. Auerdem versehen sie die
                 ansonsten langweiligen Testl„ufe mit ein wenig
                 'Augenschmaus'. Rechenfehler werden hier nicht automatisch
                 erkannt, sollten aber im Bild sichtbar sein, wenn es nicht
                 nur ein Pixel ist. Exceptions werden natrlich sofort
                 gemeldet. Im Fractal-Test zeigen sich Fehler meist durch
                 groe fl„chig-schwarze Gebiete. Im Extremfall wird nur
                 schwarz gezeichnet.

                 Diese beiden Tests sind jetzt ab Version 1.42 abschaltbar,
                 da sie sehr lange dauern und bei hartn„ckigen Fehlern sonst
                 ein zgiges 'debuggen' verhindern.

  Performance :  Diese Anzeige wurde in der Version 1.42 grundlegend
                 berarbeitet. Es wird nur noch einmal am Anfang der Tests
                 die Performance gemessen und nicht mehr fr jeden Test
                 einzelnd. Geeicht wurde die Anzeige jetzt mit meiner 48 MHz
                 PAK/3 mit 68882. Die MHz-Anzeige ist immer noch nicht ganz
                 ernst zu nehmen, sondern nur als Benchmark zu gebrauchen.
                 Bei einer PAK/2 werden z.B. prinzipbedingt zu kleine
                 Werte gemessen, hier macht sich der Level-2-Cache der
                 PAK/3 bemerkbar. Die Performance-Anzeige wurde jetzt mit
                 eingeschaltetem-Cache geeicht!

  Check       :  Hier wird der Name des aktuell laufenden Tests eingeblendet.
                 Es werden fast alle mathematischen Operationen berprft.
                 Zwangsl„ufig natrlich auch die Datentransportbefehle. Ein
                 paar Programmsteuerbefehle (Vergleiche, Sprnge) kommen
                 im 'Fractal'-code zum Einsatz.

  Last Error  :  Gibt den letzten gefundenen Fehler im Kurztext aus.

  Tests       :  Z„hlt die absolvierten Tests.

  Errors      :  Z„hlt die gefundenen Fehler.

  Loops       :  Fr Langzeittests. Man kann eine Anzahl von Testl„ufen
                 vorgeben, die den Rechner auch mal ber Nacht besch„ftigen
                 k”nnen, um ein ausfhrliches Fehlerprotokoll zu bekommen.
                 Die Schleife kann vorzeitig mit einem Maus-Button-Druck
                 oder mit einer der Tasten CTRL, Shift, Alt. zwischen(!)
                 den Tests abgebrochen werden.

  Logfile     :  Ebenfalls fr Langzeittests. Gefundene Fehler werden nicht
                 mit einer Alertbox angezeigt, sondern in einem File mit
                 Datum und Uhrzeit protokolliert.

  Cache       :  Der Cache des 68020/30 kann hiermit ein- bzw. ausgeschaltet
                 werden.

  Start       :  Startet den Testlauf.

  Quit        :  Beendet das Programm.

  QuickTest   :  Fhrt einen Schnelltest der FPU-Funktionen durch.

  INFO-Button :  Halt das bliche. Insbesondere das...


2. Copyright

   Dieses Programm darf zu nicht kommerziellen Zwecken frei kopiert und
   weitergegeben werden.


3. Schlubemerkung

   Als Autor bin ich natrlich sehr an Erfahrungen mit diesem Programm
   interessiert. Insbesondere, ob es bei wirklich fehlerhaften FPU's so
   funktioniert wie es soll, oder ob es trotzdem noch zu katastrophalen
   Abstrzen kommt. In diesem (und nur in diesem;-) Zusammenhang stellte
   es sich als nachteilig heraus, da ich zwei einwandfreie FPU's besitze,
   soda ich Fehler nur simulieren konnte.

   Eigentlich ist der obige Absatz inzwischen hinf„llig geworden, denn
   mittlerweile konnte ich eine nichtfunktionierende FPU live erleben (s.u.)
   und ich mu sagen, da FPU-Check zu meiner vollsten Zufriedenheit
   funktioniert. Sollte es dennoch Probleme mit FPU-Check geben, bitte
   ich um Benachrichtigung.

   Auch Verbesserungsvorschl„gen gegenber bin ich aufgeschlossen, nur
   am grundlegenden Aufbau des Programms werde ich nicht mehr viel „ndern.

   Also: Bitte meldet Euch bei Problemen mit FPU-Check! Vielleich hilft das
   dann auch anderen.


4. Erg„nzungen

   Als zus„tzlichen Test kann ich noch das Programm "Ikarus" von
   Christoph Zwerschke @KA empfehlen.
   Download in:     Maus KA und MTK
   Es benutzt ausgiebig die FPU, strzt allerdings beim ersten Fehler
   ab.

   FPU-Check gibt's in der aktuellen Version immer in den Mailboxen
   Galactica: 07151 908549
   Mars-Box : 040 76621205
   Auf Wunsch auch uuencoded per mail.

   zur V. 1.41: Es werden jetzt die Magic-Dials von Peter Hellinger benutzt,
                daher jetzt cross-check-buttons und Deaktivierung des Hinter-
                grunddialoges. Leider ist dadurch das Programm bedeutend
                gr”er geworden, ohne an Funktionalit„t zu gewinnen. Wen
                das st”rt, der m”ge weiterhin die V. 1.40 benutzen.
                Die Maus wird jetzt zwingend bei Fehlermeldungen eingeschaltet,
                damit Dialoge auch beantwortet werden k”nnen.
                Zwei Nachkommastellen werden bei der Reliability-
                (=Zuverl„ssigkeits-) Angabe im Logfile ausgegeben, damit
                dort bei seltenen Fehlern nicht 100% steht. Kleinere
                Sch”nheitskorrekturen.

   zur 1.42:   nderung der Performance-Anzeige (s.o).
                "Fractal-" und "SinCos"-Test sind jetzt abschaltbar.
                Zus„tzlich wurde ein "Quicktest" aufgenommen fr
                Tests bei ganz harten Fehlern, die sich sofort zeigen.
                Angesichts des Pentium-FDIV-Fehlers habe ich noch drei
                Rechengenauigkeits-Tests aufgenommen. Werden regelm„ig
                Fehler in den Tests "Accurac1"..."Accurac3" gemeldet, so
                sollte man berprfen, ob nicht ein Pentium anstelle einer
                68881/2-FPU eingebaut ist;-)
                Auch alle anderen Tests reagieren jetzt wesentlich
                empfindlicher auf Rechenfehler.
                Dies ist eine ”ffentliche beta-Version. Ich habe etliche
                umfangreiche nderungen unternommen, deren Auswirkungen
                ich bis jetzt noch nicht vollst„ndig testen konnte.
                FPU-Check l„uft unter MagicMac.

   zur 1.43:   T. Tempelmann hatte in den Assemblerroutinen einige nicht
                restaurierte Register entdeckt. Das ist jetzt behoben.
                Eventuell l„uft FPU-Check jetzt auf der Medusa -- mu noch
                getestet werden. Zum "" siehe Version 1.42.

   zur 1.44:   Nur kleinere kosmetische Korrekturen im Code.
                Zum "" siehe Version 1.42.

5. Mit FPU-Check gefundene FPU-Fehler

   Inzwischen kann ich bereits von Erfahrungen mit FPU-Check berichten:

   - Der Rechner eines Freundes erzeugte einen Bus-Error beim Bewegen der
     Maus w„hrend der FPU-Check-Testl„ufe. Die FPU sitzt in einer PAK/3.
     Als šbelt„ter wurde inzwischen die 68020/30-Version von "Petra"
     entlarvt.

   - Leider war das noch nicht alles. Derselbe Rechner hat immer noch
     Probleme mit der FPU, die bis heute (25.08.96) nicht gel”st werden
     konnten. Nach einer relativ kurzen Aufw„rmzeit (ca. 5..10 min.)
     treten sehr h„ufig Rechenfehler und auch Exceptions auf. Die
     Fehlerrate steigt, wie so oft, mit Erh”hung der Taktfrequenz.
     Ich k”nnte hier sehr viel darber erz„hlen, was wir alles versucht
     haben, den Fehler zu finden: Z.B. kompletter Austausch der Atari-
     Custom-Chips, ebenso der PAK-Bestckung etc., nichts hat geholfen.

     Der "Witz" an der Sache ist, da diese PAK in meinem Rechner
     fehlerfrei l„uft und meine PAK in seinem Rechner ebenfalls. D.h.
     weder seine PAK noch sein Mainboard k”nnen einen ernsthaften Defekt
     aufweisen. Wir sind hier im Moment ratlos. FPU-Check hat uns aber
     wertvolle Hilfe bei der Fehlereingrenzung geleistet.

     Mittlerweile hat er eine FRAK (Fast-RAM-Karte) auf seine PAK gesetzt
     und erstaunlicherweise traten die Fehler bei FPU-Check im Fast-RAM
     nicht mehr auf, blieben aber im ST-RAM unver„ndert. Demnach scheint
     der PAK/FRAK-Turm einwandfrei zu funktionieren, nur das Zusammenspiel
     mit dem ST-Mainboard klappt nicht.

   - Bei einem TT mit einer mit 40 MHz getakteten FPU traten nach ca.
     40 min. sporadisch Rechenfehler im 'Realmath' oder 'Triglog'-Test
     auf. Wohlgemerkt reine Rechenfehler und keine Exceptions! Aufgrund
     der Zuf„lligkeit und des sp„ten Auftretens nach l„ngerer Rechenzeit
     habe ich auf einen thermischen Fehler getippt.

   - Wie mir gemeldet wurde, l„uft FPU-Check bis jetzt noch nicht auf
     der Medusa mit der im 68040 integrierten FPU. Ich werde mich drum
     kmmern.

   - Inzwischen ist auch klar warum: Indem ich mit FPU-Check die
     FPU-Exceptions abfange, h„nge ich den Exception-Handler zur
     Softwareemulation der transzendenten FP-Operationen aus. Wie
     gesagt, ich werde mich darum kmmern. Bemerkenswert ist noch,
     da FPU-Check auf einem 68040-MAC unter MagicMac l„uft und zwar
     mit der Softwareemulation, die der Medusa mitgeliefert wird.
     MagicMac verschiebt die Exception-Vektoren, soda es nicht zu
     einer Kollision zwischen FPU-Check und Emulator kommt. Dank
     gebhrt Thomas Tempelmann, der mir diesbezglich weiterhalf.

     Mit der Version 1.43 besteht zumindest die Chance, da sie jetzt
     auf der Medusa l„uft. Ich bitte alle Medusa-Besitzer um Mitteilung,
     daher das ''.

   - Wieder ein TT: Mit FPU-Check 1.40 wurde ein TT getestet und alle
     23 Tests, bis auf die mit Grafikausgabe, schlugen fehl. Der TT
     soll ungetuned im Originalzustand gewesen sein, mehr wurde mir
     nicht mitgeteilt.

   - (Noch ein TT) Ich bekam folgende Fehlermeldung:
     "Ich besitze einen TT030, der bis vor kurzem noch mit 4 Mbyte ST-Ram
     ausgestattet war (0 TT-Ram), Dein Programm FPU-Check 1.4 arbeitete bis
     dahin auch ohne Erkennung von Fehlern. Seit ein paar Tagen habe ich nun
     eine original TT-Ram Karte (4Mbyte) eingebaut, und mehr durch Zufall noch
     mal Dein Programm angestartet.

     Siehe da: "inexact result, err=4.06E-003" beim Test "Realmath".

     Und der Fehler ist reproduzierbar."

   - Ich pers”nlich teste dieses Programm mit einem Mega ST2 (4MB) und
     einer PAK/3 mit 48 MHz, sowie einem Mega ST1 (2MB) mit einer PAK/2
     und 20 MHz 68882. Zum Glck lief es bisher immer einwandfrei durch.
     (25.08.96): Die PAK/2 des "Testequipments" wurde in der Zwischenzeit
     durch eine PAK/3-020 mit 68882 bei 16 MHz ersetzt.

     TT-Kenner sollten sich mal mit mir in Verbindung setzen, ob
     Serienfehler bei der FPU-Ansteuerung in diesen Ger„ten bekannt
     sind.

   Ich bin unter der email-Adresse:

                           sk@lumumba.shnet.org   (Stefan Krey)

   zu erreichen. Die alte Adresse bitte nicht mehr benutzen!

   Stefan Krey
