# TODO

## Widget Android: dati che mancano rispetto al pannello del PC

- [ ] **In crescita / secchi**: sul PC compare per esempio "2 in crescita · 1 secco". Va letto in `datiWidget` ([pipeline/genera.ts](pipeline/genera.ts)), aggiunto a `widget.json` e mostrato nel pannello grande.
- [ ] **Ultimo albero piantato**: sul PC compare per esempio "Ultimo albero piantato 3 giorni fa". Meglio salvare la data piuttosto che il testo, così il widget calcola da solo quanto tempo è passato.
- [ ] **Aggiornato alle**: il dato `generato` è già in `widget.json` ma il widget non lo mostra. Va messo in piccolo in fondo al pannello, così si vede quando la foto è vecchia (telefono offline, job fermati dal sistema).
- [ ] **Meteo vero o di riserva**: sul PC "a Milano" compare solo quando il meteo arriva da Open-Meteo. Va salvato in `widget.json` se il meteo è vero (per esempio `meteoVero: true`). Se non lo è, il widget nasconde cielo e temperatura invece di mostrare il "sereno" di riserva.

## Widget Android: app

- [x] **Release firmata**: creare il keystore (`keytool`, vedi README) e impostare i secret `ANDROID_KEYSTORE`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Poi creare il tag `android-v0.1.0` e installare l'APK della Release al posto della build di sviluppo.
- [x] **Variante piccola** (sotto 200dp): solo ora e data, provata sul telefono.
- [x] **Carrellata**: ampiezza ±7% e velocità 25 s in [carrellata.xml](android/app/src/main/res/anim/carrellata.xml), va bene così.

## Più avanti

- [ ] **Sfondo del telefono**: formato `telefono` nella pipeline e un'opzione nell'app per impostarlo come sfondo (vedi "Prossimi passi" nel README).
