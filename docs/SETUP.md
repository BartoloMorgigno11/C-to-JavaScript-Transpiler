# Detailed setup guide

Guida rapida (1-2 pagine) per installare e verificare il transpiler C -> JavaScript.

## Prerequisiti minimi
- **Python** 3.10 o superiore, con `pip`.
- **Flex** >= 2.6 e **Bison** >= 3.8.
- **Compilatore C** con supporto C11 (GCC o Clang).
- Strumenti opzionali: `git`, `make`, un browser moderno per la demo web.

> Suggerimento: usare sempre un ambiente virtuale Python dedicato al progetto.


## Procedura Windows (WSL + PowerShell, ordine completo)
1. **Abilitare WSL** (una sola volta) da PowerShell amministratore:
   ```powershell
   wsl --install
   ```
   Riavviare se richiesto e scegliere una distribuzione (es. Ubuntu).
2. **Aggiornare la distribuzione Linux** (nella console WSL appena installata):
   ```bash
   sudo apt update
   sudo apt upgrade -y
   ```
3. **Seguire i passaggi Linux** (creazione `.venv`, installazione requirements, build, tests) eseguiti dalla shell WSL.


## Procedura Linux / WSL (ordine completo)

1. **Aprire il progetto all'interno di WSL** (es. `\\wsl$\Ubuntu\home\<utente>\Transpiler` oppure montare la cartella Windows sotto `/mnt/c/...`).

2. **Installare i pacchetti di sistema**
   ```bash
      # 'sudo apt update' per aggiornare il sistema/sottosistema Linux
   sudo apt install build-essential flex bison gcc python3 python3-venv -y
   ```
3. **Creare l'ambiente virtuale**
   ```bash
   python3 -m venv .venv      # potrebbe volerci un po' di tempo
   ```
4. **Attivare l'ambiente**
   ```bash
   source .venv/bin/activate
   ```
5. **Aggiornare pip e installare Flask**
   ```bash
   python3 -m pip install --upgrade pip      # potrebbe volerci un po' di tempo
   python3 -m pip install Flask
   ```
6. **Compilare il front-end C**
   ```bash
   python3 scripts/build_transpiler.py --force
   ```
   Output atteso: `Transpiler available at transpiler/build/myTranspiler`.
7. **Transpilare il sorgente di esempio**
   ```bash
   python3 scripts/c_to_js.py transpiler/input/input.c --output transpiler/output/output.js --keep-ast
   ```
   Verificare la presenza di `output/output.js` e `output/output.ast.json`.
8. **Eseguire la suite di regressione**
   ```bash
   python3 scripts/run_tests.py
   ```
   Controllare che `tests/results/ok` e `tests/results/err` vengano popolati e che l'exit code sia 0.
9. **(Opzionale) Avviare l'interfaccia web**
   ```bash
   python3 web/app.py
   ```
   Aprire <http://127.0.0.1:5000> per usare la UI.


## Build e verifica obbligatoria

1. **Compilare il front-end C**
   ```bash
   python scripts/build_transpiler.py --force
   ```
   Output atteso: `Transpiler available at transpiler/build/myTranspiler[.exe]`.

2. **Transpilare il caso di esempio**
   ```bash
   python scripts/c_to_js.py transpiler/input/input.c --output transpiler/output/output.js --keep-ast
   ```
   Controllare che `transpiler/output/output.js` e `transpiler/output/output.ast.json` vengano generati.

3. **Eseguire la suite di regressione**
   ```bash
   python scripts/run_tests.py
   ```
   Vengono ricreati i file in `tests/results/ok` (JS + AST) e `tests/results/err` (diagnostica). L'exit code 0 conferma il superamento di tutti i test richiesti dal bando FLC (3 positivi + 3 negativi).

4. **(Opzionale) Avviare l'interfaccia web**
   ```bash
   python web/app.py
   ```
   Aprire <http://127.0.0.1:5000> per costruire il parser, incollare sorgenti C, vedere gli artefatti e lanciare i test dal browser.

## Risoluzione rapida dei problemi
- **Mancanza di flex/bison**: verificare che gli eseguibili siano nel `PATH` (`which flex`, `which bison` in WSL/macOS, oppure `$env:BISON`/`$env:FLEX` se li esporti in PowerShell).
- **Binary incompatibile su Windows**: lanciare `python scripts/build_transpiler.py --force` dentro WSL; l'eseguibile generato viene usato dal resto degli script.
- **Errori PEP 668** (pip bloccato): lavorare sempre dentro l'ambiente virtuale `.venv`.
- **Errori PEP 668** (pip bloccato): se compare "externally-managed-environment", stai usando il pip di sistema. Usa sempre `python -m pip ...` dopo aver attivato la `.venv`. Verifica con `which python` che punti a `.venv/bin/python`.
- **Venv creato senza pip**: se hai usato `--without-pip`, installa pip nella venv con `python -m ensurepip --upgrade` e poi esegui `python -m pip install Flask`.
- **Parser senza output**: cancellare `transpiler/Front-end/ast.json`, ricostruire il parser e ripetere la pipeline.

Con questi passaggi il progetto è pronto per una build locale e per la dimostrazione tramite riga di comando o interfaccia web.
