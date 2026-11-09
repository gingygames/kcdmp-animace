# Testovací plán pro kcdmp-animace

Postup ověření funkčnosti modulu na KCD:MP testovacím serveru.

---

## 1. Automatické testy (Offline)

Před nasazením na server vždy spusťte offline testovací sadu v Lua 5.4:

```sh
pip install lupa
python test/run.py
```

Ověřuje se:
* Registrace příkazů a inicializace modulu
* Načtení a indexace katalogu animací (6 000+ položek)
* Izolace hráče v soukromém světě
* Vytvoření a ovládání figuríny
* Synchronizace a 600 ms usazení partnera u párových animací
* Přepínání pohlaví figuríny (muž/žena)
* Přehrávání přímo na hráči přes emoty
* Úklid všech entit po zavření, odpojení i smrti hráče
* Ochrana proti otevření po zásahu (cooldown)

---

## 2. Testy ve hře

### Krok 1: Otevření a soukromí
1. Připojte se na server se dvěma klienty (Hráč A a Hráč B).
2. Hráč A napíše `/animace`.
   * **Očekávaný výsledek:** Hráči A se otevře panel, vpravo se objeví figurína a kamera se na ni zaměří.
   * **Kontrola soukromí:** Hráč B nesmí vidět figurínu, nábytek ani Hráče A (ten je v privátním světě `30000000 + pid`).

### Krok 2: Přehrávání a rekvizity
1. V seznamu vyhledejte např. `Baker_kneeding` nebo `drink`.
2. Klikněte pro jednorázové přehrání, dvojklikem spusťte smyčku.
3. Klávesou **S** nebo tlačítkem **Stop** animaci zastavte.
4. Ověřte, že u animací s rekvizitou (např. korbel, loutna, koště) má figurína předmět v ruce.

### Krok 3: Párové animace a synchronizace
1. Zaškrtněte filtr **dvojice** a vyberte párovou animaci (např. `Party_Duo_Standing_Dancing_Loop` nebo `Loot`).
2. Spusťte přehrávání.
   * **Očekávaný výsledek:** Vedle figuríny vznikne partner a po 600 ms usazení začnou obě postavy hrát své odpovídající části synchronně.

### Krok 4: Přehrávání na sobě
1. V horní části přepněte z **Figurína** na **Na mně**.
2. Vyberte animaci (např. `GreetingsUpperBody`).
   * **Očekávaný výsledek:** Animace se přehraje přímo na těle vaší postavy.

### Krok 5: Úklid a návrat
1. Stiskněte **Esc** nebo tlačítko **✕**.
   * **Očekávaný výsledek:** Rozhraní se zavře, kamera se plynule vrátí, figurína i partner zmizí a Hráč A se vrátí do původního světa, kde ho Hráč B opět vidí.
