# defmodule Khf3 do
#   @moduledoc """
#   Kukorica kirakási lépések kiértékelése
#   @author "Falucskai András <andras.falucskai@gmail.com>"
#   @date   "2026-10-21"

#   A megoldáshoz megkérdeztem a Gemini-t, hogyan kell leírni ezt a típust: MapSet.t({sorindex(), oszlopindex()})
#   """
#   # a csutka sorainak vagy oszlopainak száma
#   @type meret() :: pos_integer()
#   # a csutka egy sorának indexe
#   @type sorindex() :: non_neg_integer()
#   # a csutka egy oszlopának indexe
#   @type oszlopindex() :: non_neg_integer()
#   # false: nincs forgatás; true: 180 fokos forgatás
#   @type forgatas() :: boolean()
#   # egy elem szöveges leírása
#   @type elem() :: [String.t()]
#   # egy elem lehelyezése
#   @type lehelyezes() :: {elem :: elem(), i :: sorindex(), j :: oszlopindex(), f :: forgatas()}
#   # hivatkozás egy lehelyezett elemre
#   @type elemindex() :: non_neg_integer()
#   # lehelyezett elemek ütközése, a < b
#   @type utkozes() :: {a :: elemindex(), b :: elemindex()}

#   @type elem_listakent() :: [{sorindex(), oszlopindex()}]

#   # elemek darabszáma
#   @type db() :: pos_integer()

#   # a megoldóállapot
#   @type allapot() ::
#           {n :: meret(), m :: meret(), keszlet :: %{elem() => db()},
#            {lerakas_lista :: [lehelyezes()],
#             tabla_lista :: [MapSet.t({sorindex(), oszlopindex()})]}}

#   @spec kezdet(n :: meret(), m :: meret(), keszlet :: %{elem() => db()}) ::
#           kezdo_allapot :: allapot()
#   # Létrehozza az n sorból és m oszlopból álló üres csutkához
#   # és a teljes keszlet-hez tartozó kezdeti megoldó-állapotot.
#   # az állapot n, m, készleten kívül sorhelyesen tárolja a lerakott elemeket, és az így kapott táblaállapotokat
#   # a táblaállapotok az elfoglalt mezőket tárolják {i, j} MapSetben
#   # {n, m, készlet, {[lerakott_elemek], [régebbi táblaállapotok]}
#   def kezdet(n, m, keszlet) do
#     {n, m, keszlet, {[], [MapSet.new()]}}
#   end

#   @spec lerak(
#           allapot :: allapot(),
#           elem :: elem(),
#           i :: sorindex(),
#           j :: oszlopindex(),
#           f :: forgatas()
#         ) :: uj_allapot :: allapot()
#   # Az uj_allapot az allapot megoldó-állapotból az elem i, j, f
#   # paraméterek szerinti elhelyezésével kapott új megoldó-állapot
#   # feltételezi, hogy le lehet oda rakni, és van is még ilyen rész
#   def lerak(allapot, elem, i, j, f) do
#     {n, m, keszlet, {lerakottak, [tabla | _] = tabla_history}} = allapot
#     # nem ellenőrzök hibát, mert tudjuk, hogy benne van
#     uj_keszlet = Map.update!(keszlet, elem, fn x -> x - 1 end)
#     # új táblát megkapom, ha az új lerakásnak megfelelő helyeket hozzáteszem a MapSet-hez
#     uj_tabla = MapSet.union(tabla, elem_helyek(n, m, {elem, i, j, f}))

#     uj_lerakasok = [{elem, i, j, f} | lerakottak]
#     uj_tabla_history = [uj_tabla | tabla_history]
#     {n, m, uj_keszlet, {uj_lerakasok, uj_tabla_history}}
#   end

#   @spec hova(allapot :: allapot(), elem :: elem()) :: l :: [lehelyezes()]
#   # hova2 függvényt wrappeli, megnézi, hogy van-e még elem a készletben
#   # nincs nekem tetsző early return az elixirben :(
#   # majd NHF-ben megírom when-el
#   def hova(allapot, elem) do
#     {n, m, keszlet, lehelyezesek} = allapot

#     # ha nincs több elem, akkor nem lehet lerakni
#     if Map.fetch!(keszlet, elem) == 0 do
#       []
#     else
#       hova2(n, m, lehelyezesek, elem)
#     end
#   end

#   @spec hova(allapot :: allapot(), elem :: elem()) :: l :: [lehelyezes()]
#   # l az allapot megoldó-állapotban az elem összes szabályos
#   # elhelyezését felsoroló lista; a lista sorrendje tetszőleges.
#   defp hova2(n, m, lehelyezesek, elem) do
#     {_elemek, [mostani_helyek | _]} = lehelyezesek
#     magassag = length(elem)

#     # TODO elég csak, hogy hanyadik sorban van
#     {ri, _} = elem_ref_hely(elem)

#     # megnézem a referencia elem alatt / felett hány sor van
#     # így pl egy 5 magas táblára egy 5 magas elemet csak egy sorba próbálok meg lerakni
#     felette = ri
#     alatta = magassag - felette - 1

#     combinations1 =
#       for i <- felette..(n - alatta - 1),
#           j <- 0..(m - 1) do
#         {i, j, false}
#       end

#     combinations2 =
#       for i <- alatta..(n - felette - 1),
#           j <- 0..(m - 1) do
#         {i, j, true}
#       end

#     # összes hely ahova le lehet rakni akkor, ha a tábla üres
#     combinations = combinations1 ++ combinations2

#     Enum.filter(combinations, fn {i, j, f} ->
#       # kiszedem az elemből, hogy milyen helyeket fog letakarni, ha ide rakom le
#       # ez is lehetne gyorsabb, mert minden i, j, f párnál újra átalakítom stringből az egészet
#       # vagy akár az is jó lenne, ha egy mapban eltárolom az elem_helyek függvény kimenetét pl 0, 0, false-ra
#       # így csak tolni / forgatni kell a helyeket, nem kell minden hívásnál újra feldolgozni a stringtömböt
#       helyek = elem_helyek(n, m, {elem, i, j, f})
#       # ha az új helyek disjoint, akkor maradhat
#       MapSet.disjoint?(mostani_helyek, helyek)
#     end)
#   end

#   @spec felvesz(allapot :: allapot()) :: uj_allapot :: allapot()
#   # Az uj_allapot az allapot megoldó-állapotból az utoljára lerakott elem
#   # felvételével kapott új megoldó-állapot.
#   def felvesz(allapot) do
#     {n, m, keszlet, {[legutolso | regi_lehelyezesek], [_ | regi_helyek]}} = allapot
#     # készletet frissítem, visszarakom bele az elemet
#     uj_keszlet = Map.update!(keszlet, elem(legutolso, 0), fn x -> x + 1 end)
#     # a régi lerakott elemeket és a táblaállapotot pedig csak kiveszem a listából
#     # elixirnek hála ezek nem fognak végtelen memóriát pazarolni (remélem)
#     {n, m, uj_keszlet, {regi_lehelyezesek, regi_helyek}}
#   end

#   ### Régi feladat innen kezdődik ###

#   # elemet, mint string_list kéri
#   # megmondja, melyik koordinátán van a ref
#   # {ref_i, ref_j}
#   defp elem_ref_hely(elem_list) do
#     list = elem_list

#     # megpróbálom pipeolással
#     list =
#       list
#       # a sorokat kifejező stringek helyett olyan lista van, amiben egy-egy elem {karakter, index} alakban van
#       # [{karakter, oszlopindex}]
#       |> Enum.map(fn sor -> String.to_charlist(sor) |> Enum.with_index() end)
#       # oszlopindexek felrakása a sorok mellé, [{[{karakter, sorindex}], oszlopindex}]
#       |> Enum.with_index()
#       # kilapítom, így megkapom a [{karakter, sorindex, oszlopindex}] listát
#       |> Enum.flat_map(fn {sor, oszlopindex} ->
#         # egy-egy sornak a végére rakom az oszlopindexet
#         sor |> Enum.map(fn {char, i} -> {char, i, oszlopindex} end)
#       end)
#       # ha a karakter space, nem érdekel
#       |> Enum.filter(fn {char, _, _} -> char != ?\s end)
#       # Megcserélem a két koordinátát, mert ahogy nézem fordítva csináltam
#       |> Enum.map(fn {char, i, j} -> {char, j, i} end)

#     # referencia koordináták kiszedése
#     {_, ref_i, ref_j} = Enum.find(list, fn {char, _i, _j} -> char == ?X end)

#     {ref_i, ref_j}
#   end

#   @spec elem_helyek(n :: meret(), m :: meret(), elem :: lehelyezes()) ::
#           MapSet.t({sorindex(), oszlopindex()})
#   # egy lehelyezést átalakít egy listává, amiben fel van sorolva az összes mező amit letakar (elem_listakent() típus)
#   # n-t nem használja, de rosszul érezném magamat, ha nem írnám bele
#   # lehet majd kell egy gömb? alakú játékhoz (tudom hogy nem tileable)
#   defp elem_helyek(_n, m, elem) do
#     {list, eltol_i, eltol_j, forgat} = elem

#     # megpróbálom pipeolással
#     list =
#       list
#       # a sorokat kifejező stringek helyett olyan lista van, amiben egy-egy elem {karakter, index} alakban van
#       # [{karakter, oszlopindex}]
#       |> Enum.map(fn sor -> String.to_charlist(sor) |> Enum.with_index() end)
#       # oszlopindexek felrakása a sorok mellé, [{[{karakter, sorindex}], oszlopindex}]
#       |> Enum.with_index()
#       # kilapítom, így megkapom a [{karakter, sorindex, oszlopindex}] listát
#       |> Enum.flat_map(fn {sor, oszlopindex} ->
#         # egy-egy sornak a végére rakom az oszlopindexet
#         sor |> Enum.map(fn {char, i} -> {char, i, oszlopindex} end)
#       end)
#       # ha a karakter space, nem érdekel
#       |> Enum.filter(fn {char, _, _} -> char != ?\s end)
#       # Megcserélem a két koordinátát, mert ahogy nézem fordítva csináltam
#       |> Enum.map(fn {char, i, j} -> {char, j, i} end)

#     # referencia koordináták kiszedése
#     {_, ref_i, ref_j} = Enum.find(list, fn {char, _i, _j} -> char == ?X end)

#     # karakter információ már nem kell, tudjuk hol a referencia szem
#     list = list |> Enum.map(fn {_, i, j} -> {i, j} end)

#     list =
#       if forgat do
#         list
#         |> Enum.map(fn {i, j} ->
#           # középpontos tükrözés: R + (P -> R) ilyen vektorosan, lerajzolom ha kell
#           diff_i = i - ref_i
#           diff_j = j - ref_j

#           # kibontva 2*ref_i - i
#           {ref_i - diff_i, ref_j - diff_j}
#         end)
#       else
#         # Ha nem forgatom, csak az eredeti lista
#         list
#       end

#     list
#     # eltolás a megadott pozícióba, referencia korrigálás
#     |> Enum.map(fn {i, j} -> {i + eltol_i - ref_i, j + eltol_j - ref_j} end)

#     # tbh csak betippeltem a kettő közül melyik irány a körbefordulás
#     |> Enum.map(fn {i, j} -> {i, Integer.mod(j, m)} end)

#     # minden elem egyedi lesz, és majd intersectiont fogok nézni köztük, ezért mehet halmazba
#     |> MapSet.new()

#     # IO.inspect(list)
#     # IO.inspect({ref_i, ref_j})
#   end
# end

# # piece_a = ["XO", " O"]
# # piece_b = ["X", "O"]
# # s0 = Khf3.kezdet(3, 4, %{piece_a => 1, piece_b => 2})
# # Khf3.hova(s0, piece_b) |> length() |> IO.inspect()

# # s1 = Khf3.lerak(s0, piece_a, 1, 0, true)

# # Khf3.hova(s1, piece_b) |> IO.inspect()

# # s2 = Khf3.felvesz(s1)

# # Khf3.hova(s2, piece_b) |> length() |> IO.inspect()

# # s3 = Khf3.lerak(s2, piece_b, 0, 0, false)

# # Khf3.hova(s3, piece_b) |> IO.inspect()

# # s4 = Khf3.lerak(s3, piece_b, 0, 1, false)

# # Khf3.hova(s4, piece_b) |> IO.inspect()
# # IO.inspect(Khf3.elem_helyek(3, 5, {["OXO"], 0, 0, false}))

# # Új beadás, mert defp-k kellenek.
