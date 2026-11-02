defmodule Nhf1 do
  @moduledoc """
  Kukorica-kirakós
  @author "Falucskai András <andras.falucskai@gmail.com>"
  @date   "2026-10-31"

  A feladat megoldásához ChatGPT-t használtam a benchmarkolásra, valamint hogy melyik beépített függvényeket használjam.
  (Tudtam mit akartam elérni, de nem tudtam van-e rá függvény / hogy lehetne szépen, feladatról nem kapott információt ezeknél a kérdéseknél.)
  A modell által írt benchmarkoló fájl automatikusan generál és tesztel bemeneteket.
  Annyiban segített, hogy a kreatív optimalizációmról észrevettem, hogy kevésbé fog működni, és össze tudtam hasonlítani barátom megoldásával a sebességet.
  Ebből látszódott, hogy 10x10-es táblánál nagyon nagy a szórás: Egyes bemenetekre egyik / másikunk kódja akár 200x gyorsabb.
  Érdekesebb, hogy egyes esetekre egyáltalán le se fut értelmes időn belül (30 mp), másokra pedig 10 ms alatt kész van, a két tesztelt megoldás akár ugyan azon a bemeneten.

  De legalább minden teszteset 1 mp alatt kész.
  """

  # a csutka sorainak vagy oszlopainak száma
  @type meret() :: pos_integer()
  # a tábla egész mérete
  @type tabla_meret() :: {meret(), meret()}
  # egy elem szöveges leírása
  @type elem_stringkent() :: [String.t()]
  # elemek darabszáma
  @type db() :: pos_integer()

  # a csutka egy sorának indexe
  @type sorindex() :: non_neg_integer()
  # a csutka egy oszlopának indexe
  @type oszlopindex() :: non_neg_integer()
  # false: nincs forgatás; true: 180 fokos forgatás
  @type forgatas() :: boolean()
  # egy elem lehelyezése
  @type lehelyezes() :: {i :: sorindex(), j :: oszlopindex(), f :: forgatas()}

  # elem egyedi azonosítója
  @type elem_id() :: integer()
  # egy hely a táblán
  @type hely() :: {sorindex(), oszlopindex()}
  # lehelyezés leírása referenciahellyel és forgatással
  @type(lehelyezes_leiras() :: sorindex(), oszlopindex(), boolean())
  # a megoldáshoz használt egy-egy állapot
  @type allapot() ::
          {
            # tábla mérete
            tabla_meret(),
            # elem_id-hez hozzárendeli a még szabályos lehelyezéseit
            %{elem_id() => [{lehelyezes_leiras(), MapSet.t(hely())}]},
            # elem_id-hez hogy mennyi van még belőle (legalább 1)
            %{elem_id() => db()},
            # A tábla, foglalt helyei
            MapSet.t(hely()),
            # megoldás, minden elem_id-hez hogy milyen helyekre raktam le őket
            %{elem_id() => [lehelyezes_leiras()]}
          }

  @spec megold(n :: meret(), m :: meret(), keszlet :: %{elem_stringkent() => db()}) ::
          megoldas :: %{elem_stringkent() => [lehelyezes()]} | nil
  # A n sorból és m oszlopból álló üres csutkán a keszlet elemek
  # egy lehetséges helyes elhelyezése megoldas, vagy nil, ha nincs ilyen.
  def megold(n, m, string_keszlet) do
    meret = {n, m}

    # id_to_string: visszaváltja az elem_id()-ket elem_stringkent()-re
    # id_to_lehelyezes: minden elem_id()-hez hozzárendeli a még szabályos lehelyezéseit
    # id_to_db: minden elem_id()-hez hozzárendeli, hogy még mennyi van a készletben
    {id_to_string, id_to_lehelyezes, id_to_db, _} =
      Enum.reduce(string_keszlet, {Map.new(), Map.new(), Map.new(), 0}, fn {elem_stringkent, db},
                                                                           {id_to_string_acc,
                                                                            id_to_lehelyezes_acc,
                                                                            id_to_db_acc, id} ->
        {Map.put(id_to_string_acc, id, elem_stringkent),
         Map.put(id_to_lehelyezes_acc, id, elem_minden_lehelyezese(meret, elem_stringkent)),
         Map.put(id_to_db_acc, id, db), id + 1}
      end)

    # állapot: méret, még érvényes lehelyezések, készlet, tábla, megoldás
    allapot = {meret, id_to_lehelyezes, id_to_db, MapSet.new(), Map.new()}

    # azt a részt rakom le először, ami a legkevesebb helyre lerakható
    # az elsőnél ezt manuálisan számítom, valójában az lesz, ami a legmagasabb
    {elso_id, _db, _hossz, elso_lerakasok} =
      Enum.reduce(id_to_db, {-1, -1, -1, []}, fn {id, db},
                                                 {id_accum, db_accum, hossz_accum,
                                                  lerakasok_accum} ->
        lerakasok = Map.fetch!(id_to_lehelyezes, id)

        l = length(lerakasok)

        if l < hossz_accum || hossz_accum == -1 do
          {id, db, l, lerakasok}
        else
          {id_accum, db_accum, hossz_accum, lerakasok_accum}
        end
      end)

    # az első elemet csak egy oszlopban érdemes megpróbálni lerakni
    lerakasok_filtered =
      Enum.filter(elso_lerakasok, fn {{_eltol_i, eltol_j, _}, _} ->
        eltol_j == 0
      end)

    # a lerak függvénynek meg kell mondani melyik részt és milyen helyekre próbálja meg lerakni
    # a megoldáshoz mindig azt a részt választom, amit a legkevesebb helyre lehet lerakni
    solution = lerak(allapot, elso_id, lerakasok_filtered)

    if solution == nil do
      nil
    else
      Map.new(solution, fn {k, v} ->
        {Map.fetch!(id_to_string, k), v}
      end)
    end
  end

  @spec lerak(
          # a megoldóállapot
          allapot :: allapot(),
          # melyik elemet próbálja meg lerakni következőnek, ez a legkevesebb helyre lerakható elem
          melyiket :: elem_id(),
          # hova próbálja meg lerakni
          hova_lehet :: [lehelyezes_leiras()]
        ) ::
          nil | %{elem_id() => [lehelyezes_leiras()]}
  # megpróbálja az elemet az adott helyekre lerakni
  # ha ezzel megoldáshoz jut, visszaadja a teljes megoldást: minden elem_id-hez egy listában, hogy hova kell lerakni
  # ha nem lehet megoldani ennek az elemnek a lehelyezésével, akkor nil-t ad vissza
  defp lerak(allapot, melyiket, hova_lehet) do
    {meret, id_to_lerakasok, keszlet, tabla, sol} = allapot

    # itt a melyiket a legkevesebb helyre lerakható elem, az előzőből számítva
    id = melyiket
    db = Map.fetch!(keszlet, id)
    lerakasok = hova_lehet

    # elem felhasználása a készletből
    uj_keszlet =
      if db == 1 do
        Map.delete(keszlet, id)
      else
        Map.put(keszlet, id, db - 1)
      end

    # megkeresi az első lerakást, ami megoldáshoz vezet
    # ha van, akkor az értéke az a lerakás
    # ha nincs, akkor nil
    #
    # find_value az enumerable-on végigmenve keresi az első függvény visszatérési értéket, ami nem nil

    Enum.find_value(lerakasok, nil, fn lerakas ->
      {lerakas_leiras, helyek} = lerakas

      # új tábla előállítása
      uj_tabla = MapSet.union(tabla, helyek)

      # id_to_lerakasok tábla szűrése
      # csak azokat hagyom meg benne, amik valid lehelyezések
      # hamar kilép nil-el, ha van olyan elem, amit nem lehet lerakni
      # kiszedi, melyik id-jű elem a legkevesebb helyre lerakható, hogy egyből kezdhesse ezzel a következő

      result =
        Enum.reduce_while(id_to_lerakasok, {%{}, {nil, -1, nil}}, fn {id_inner, lerakasok},
                                                                     acc =
                                                                       {acc_map,
                                                                        {shortest_id,
                                                                         shortest_length,
                                                                         shortest_where}} ->
          # ez a kódblokk egy-egy elem még lehetséges lerakásain megy át

          # lehet condozni, nem fogom
          if db == 1 && id == id_inner do
            # ha csak 1 db volt, és az a most lerakott elem, akkor elfogyott
            {:cont, acc}
          else
            # filterelem a lerakásokat, hogy melyik lehetséges még
            # lementem a hosszát az egyes filterezéseknek, hogy a legrövidebbet megkaphassa a továbbhívás
            {lerakas_filtered, filtered_length} =
              Enum.reduce(lerakasok, {[], 0}, fn lerakas = {_lerakas_leiras, helyek},
                                                 {acc_list, acc_len} ->
                if MapSet.disjoint?(uj_tabla, helyek) do
                  {[lerakas | acc_list], acc_len + 1}
                else
                  {acc_list, acc_len}
                end
              end)

            # Ha nincs már valid lerakása, az egész accum nil-lesz
            # ezzel jelezve, hogy lehetetlen megoldani a feladatot
            # és hamarabb kilép
            if(filtered_length == 0) do
              {:halt, nil}
            else
              # legkevesebb helyre rakható kimentése
              if filtered_length < shortest_length || shortest_length == -1 do
                {:cont,
                 {Map.put(acc_map, id_inner, lerakas_filtered),
                  {id_inner, filtered_length, lerakas_filtered}}}
              else
                {:cont,
                 {Map.put(acc_map, id_inner, lerakas_filtered),
                  {shortest_id, shortest_length, shortest_where}}}
              end
            end
          end
        end)

      # van olyan elem, amiből még van, de nem lehet lerakni
      if result == nil do
        nil
      else
        {uj_id_to_lerakasok, {shortest_id, _shortest_length, shortest_where}} = result
        # a megoldásban az elem végére fűzöm a lerakását
        uj_sol = Map.update(sol, id, [lerakas_leiras], fn x -> [lerakas_leiras | x] end)
        uj_allapot = {meret, uj_id_to_lerakasok, uj_keszlet, uj_tabla, uj_sol}
        # nincs több elem, azaz mindent jól leraktunk
        if map_size(uj_keszlet) == 0 do
          uj_sol
        else
          # következő elem lerakása
          lerak(uj_allapot, shortest_id, shortest_where)
        end
      end
    end)
  end

  @spec elem_minden_lehelyezese(meret :: tabla_meret(), elem_stringkent :: elem_stringkent()) ::
          [{lehelyezes_leiras(), MapSet.t(hely())}]
  # A bemenetként megadott elemre visszaadja az összes szabályos lerakását az üres táblán
  defp elem_minden_lehelyezese(meret, elem_stringkent) do
    {n, m} = meret
    list = elem_stringkent

    # 1. lépés: A stringtömb átalakítása egy MapSet-é, minden elem {i, j} formátumban
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
    # Így egy-egy lehelyezéshez számítás nélkül el tudjuk tárolni pontosan milyen helyek tartoznak

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
          # MapSet disjoint legyen gyorsabb, tuple helyett a helyeket csak számként tárolom
          |> Enum.map(fn {i, j} -> m * i + j end)
          |> MapSet.new()

        {{eltol_i, eltol_j, false}, elem_helyek}
      end

    # 1x1-es elemet nem kell forgatni
    # belerakom, mert lehet optimalizál valamit...
    list_2 =
      if length(list) == 1 do
        []
      else
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
            # MapSet disjoint legyen gyorsabb, tuple helyett a helyeket csak számként tárolom
            |> Enum.map(fn {i, j} -> m * i + j end)
            |> MapSet.new()

          {{eltol_i, eltol_j, true}, elem_helyek}
        end
      end

    list_1 ++ list_2
  end
end
