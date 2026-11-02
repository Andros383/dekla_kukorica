defmodule Nhf1 do
  @moduledoc """
  Kukorica-kirakós
  @author "Falucskai András <andras.falucskai@gmail.com>"
  @date   "2026-10-31"


  MI dolgok:
  find_value függvényt tanácsolta
  Map.new/2


  AZ ELSŐ ELEM MINDEGY, HOGY HOL VAN KÖRKÖRÖSEN
  VÁLASSZUK A LEGMAGASABBAT, ÉS CSAK EGY OSZLOPNYI HELYET KELL MEGNÉZNI
  EZ A NEM MEGOLDHATÓ ESETEKBEN A SZÉLESSÉGGEL ARÁNYOS SPEEDUP
  MEG A TÖBBIBEN IS, MERT LEHET ROSSZ IRÁNYBAN KEZDI EL VÉGIGNÉZNI (ha jobbra tolja, semmi se változik)
  nagy esetekre lefuttatni
  megcsinálni, hogy a hova tudja a magasságot
  	precomputeolni az elem forgatásokat, kell neki a magasság
  megcsinálni az ID-zést
  1-es lyuk optim
  bitmaskok
  Milántól példa, hogy lehet tuple helyett m*x + y formában egy számként tárolni a bemenetet

  átírni a segédfüggvényeket defp-re
  felkommentezni, lespecelni
  """

  def megold(n, m, string_keszlet) do
    meret = {n, m}

    # akarok egy olyat, hogy {id -> elem_lerakások}, {id -> elem_stringek}

    {id_to_string, id_to_lehelyezes, id_to_db, _} =
      Enum.reduce(string_keszlet, {Map.new(), Map.new(), Map.new(), 0}, fn {elem_stringkent, db},
                                                                           {id_to_string_acc,
                                                                            id_to_lehelyezes_acc,
                                                                            id_to_db_acc, id} ->
        {Map.put(id_to_string_acc, id, elem_stringkent),
         Map.put(id_to_lehelyezes_acc, id, elem_minden_lehelyezese(meret, elem_stringkent)),
         Map.put(id_to_db_acc, id, db), id + 1}
      end)

    # állapot: méret, készlet, tábla, lehelyezések, {elem_id, lehelyezés} formátumban
    allapot = {meret, id_to_lehelyezes, id_to_db, MapSet.new(), Map.new()}

    # domainek mindenképpen azok, hogy egy elemet hova lehet lerakni, nem pedig hogy egy helyre milyen elemek kerülhetnek
    # mert egy helyet másik lerakással is le lehet fedni
    solution = lerak(allapot, 0)
    #
    if solution == nil do
      nil
    else
      Map.new(solution, fn {k, v} ->
        {Map.fetch!(id_to_string, k), v}
      end)
    end
  end

  def lerak(allapot, depth) do
    # TODO darabszámokat külön mapba? Könnyebben lehessen megoldani
    {meret, id_to_lerakasok, keszlet, tabla, sol} = allapot

    # azt a részt rakom le, ami a legkevesebb helyre lerakható
    # ez kiemelhető a vége felé, hogy megkapja automatikusan a lerak függvény, mert ott amúgy is átmegyek mindig a listákon
    {id, db, _hossz} =
      Enum.reduce(keszlet, {-1, -1, -1}, fn {id, db}, {id_accum, db_accum, hossz} ->
        lerakasok = Map.fetch!(id_to_lerakasok, id)

        l = length(lerakasok)

        if l < hossz || hossz == -1 do
          {id, db, l}
        else
          {id_accum, db_accum, hossz}
        end
      end)

    uj_keszlet =
      if db == 1 do
        Map.delete(keszlet, id)
      else
        Map.put(keszlet, id, db - 1)
      end

    # [{lerakás, MapSet}]
    lerakasok = Map.fetch!(id_to_lerakasok, id)

    Enum.find_value(lerakasok, nil, fn lerakas ->
      {lerakas_leiras, helyek} = lerakas

      # sikeres lerakás, megyünk tovább
      uj_tabla = MapSet.union(tabla, helyek)

      uj_id_to_lerakasok =
        Enum.reduce_while(id_to_lerakasok, %{}, fn {id_inner, lerakasok}, acc ->
          # lehet condozni, nem fogom
          if db == 1 && id == id_inner do
            # ha csak 1 db volt, akkor a most lerakott id-jű elem elfogyott
            {:cont, acc}
          else
            # filterelem az elemet, hogy melyik lerakásai lehetségesek még
            # lementem a hosszát az egyes filterezéseknek, hogy a legrövidebbet megkaphassa a függvény
            # {lerakas_filtered, filtered_length} =
            #   Enum.reduce(lerakasok, {[], 0}, fn lerakas = {_lerakas_leiras, helyek},
            #                                      {acc_list, acc_len} ->
            #     if MapSet.disjoint?(uj_tabla, helyek) do
            #       {[lerakas | acc_list], acc_len + 1}
            #     else
            #       {acc_list, acc_len}
            #     end
            #   end)
            lerakas_filtered =
            	Enum.filter(lerakasok, fn {_leiras, helyek} ->
             		MapSet.disjoint?(uj_tabla, helyek)
             	end)

            # Ha nincs már valid lerakása, az egész accum nil-lesz
            # ezzel jelezve, hogy lehetetlen megoldani a feladatot
            if(Enum.empty?(lerakas_filtered)) do
              {:halt, nil}
            else
              {:cont, {Map.put(acc, id_inner, lerakas_filtered), id_inner, lerakas_filtered}}
            end
          end
        end)

      # van olyan elem, amiből még van, de nem lehet lerakni
      if uj_id_to_lerakasok == nil do
        nil
      else
        uj_sol = Map.update(sol, id, [lerakas_leiras], fn x -> [lerakas_leiras | x] end)
        uj_allapot = {meret, uj_id_to_lerakasok, uj_keszlet, uj_tabla, uj_sol}
        # nincs több elem, azaz mindent jól leraktunk
        if map_size(uj_keszlet) == 0 do
          uj_sol
        else
          lerak(uj_allapot, depth + 1)
        end
      end
    end)
  end

  def elem_minden_lehelyezese(meret, elem_stringkent) do
    {n, m} = meret
    list = elem_stringkent

    # 1. lépés: A stringtömb átalakítása egy MapSet-é
    list =
      list
      # a sorokat kifejező stringek helyett olyan lista van, amiben egy-egy elem {karakter, index} alakban van
      # [{karakter, oszlopindex}]
      |> Enum.map(fn sor -> String.to_charlist(sor) |> Enum.with_index() end)
      # oszlopindexek felrakása a sorok mellé, [{[{karakter, sorindex}], oszlopindex}]
      |> Enum.with_index()
      # kilapítom, így megkapom a [{karakter, sorindex, oszlopindex}] listát
      |> Enum.flat_map(fn {sor, oszlopindex} ->
        # egy-egy sornak a végére rakom az oszlopindexet
        sor |> Enum.map(fn {char, i} -> {char, i, oszlopindex} end)
      end)
      # ha a karakter space, nem érdekel
      |> Enum.filter(fn {char, _, _} -> char != ?\s end)
      # Megcserélem a két koordinátát, mert ahogy nézem fordítva csináltam
      |> Enum.map(fn {char, i, j} -> {char, j, i} end)

    # referencia koordináták kiszedése
    {_, ref_i, ref_j} = Enum.find(list, fn {char, _i, _j} -> char == ?X end)

    # karakter információ már nem kell, tudjuk hol a referencia szem
    list = list |> Enum.map(fn {_, i, j} -> {i, j} end)

    # 2. lépés: minden lehetséges lerakásnál a MapSet legenerálása, és elrakása egy map-ba.
    # Így egy {NEM ÍGY VAN, lehelyezes} kulccsal meg lehet indexelni azt a MapSet-et, ami a lerakás eredménye

    magassag = length(elem_stringkent)

    # megnézem a referencia elem alatt / felett hány sor van
    # így pl egy 5 magas táblára egy 5 magas elemet csak egy sorba próbálok meg lerakni
    felette = ref_i
    alatta = magassag - felette - 1

    # nem forgatott változat
    lehelyezesek_1 =
      for i <- felette..(n - alatta - 1),
          j <- 0..(m - 1) do
        {i, j}
      end

    # forgatott változat
    lehelyezesek_2 =
      for i <- alatta..(n - felette - 1),
          j <- 0..(m - 1) do
        {i, j}
      end

    list_1 =
      for {eltol_i, eltol_j} <- lehelyezesek_1 do
        elem_helyek =
          list
          # eltolás a megadott pozícióba, referencia korrigálás
          |> Enum.map(fn {i, j} -> {i + eltol_i - ref_i, j + eltol_j - ref_j} end)
          # tbh csak betippeltem a kettő közül melyik irány a körbefordulás
          |> Enum.map(fn {i, j} -> {i, Integer.mod(j, m)} end)
          |> MapSet.new()

        {{eltol_i, eltol_j, false}, elem_helyek}
      end

    list_2 =
      for {eltol_i, eltol_j} <- lehelyezesek_2 do
        elem_helyek =
          list
          # forgatás
          |> Enum.map(fn {i, j} ->
            # középpontos tükrözés: R + (P -> R) ilyen vektorosan, lerajzolom ha kell
            diff_i = i - ref_i
            diff_j = j - ref_j

            # kibontva 2*ref_i - i
            {ref_i - diff_i, ref_j - diff_j}
          end)
          # eltolás a megadott pozícióba, referencia korrigálás
          |> Enum.map(fn {i, j} -> {i + eltol_i - ref_i, j + eltol_j - ref_j} end)
          # tbh csak betippeltem a kettő közül melyik irány a körbefordulás
          |> Enum.map(fn {i, j} -> {i, Integer.mod(j, m)} end)
          |> MapSet.new()

        {{eltol_i, eltol_j, true}, elem_helyek}
      end

    list_1 ++ list_2
  end
end

meret = {3, 4}

#
# IO.inspect("### NHF1 ###")
#
piece_a = ["XO", "O "]
piece_b = ["XO", "OO", "OO"]
keszlet = %{piece_a => 2, piece_b => 1}
sol = Nhf1.megold(3, 4, keszlet)
IO.inspect(sol)
#
# IO.inspect(sol)
# # %{["XO", "O "] => [{0, 1, false}, {2, 2, true}],
# #  ["XO", "OO", "OO"] => [{0, 3, false}]}
#
# IO.inspect("### NHF1 ###")
#

# elem_reffel = Nhf1.elem_helyek(meret, piece_a)
# IO.inspect(elem_reffel)
# lerakott = Nhf1.elem_lerak(meret, elem_reffel, {1, 1, true})
# IO.inspect(lerakott)
