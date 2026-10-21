defmodule Khf3 do
  @moduledoc """
  Kukorica kirakási lépések kiértékelése
  @author "Falucskai András <andras.falucskai@gmail.com>"
  @date   "2026-10-21"

  ELŐZETES BEADÁS, NINCS RENDESEN LEKOMMENTELVE ÉS LESPECELVE
  MEG MI CUCC SINCS BENNE, CSAK KOMMENTKÉNT
  """

  # TODO rendes fejkomment, típusok rendes összeszedése
  # meg megcserélni, hogy az @spec alatt legyen a szöveges komment, hogy mit csinál
  # használtam GMI-t a permutációk szintaxisához (for ciklus belegyűjti egy listába automatikusan)

  # elemek darabszáma
  @type db() :: pos_integer()
  # a megoldó-állapot
  # {n, m, készlet, [lehelyezés]}
  @type allapot() :: any()
  # Létrehozza az n sorból és m oszlopból álló üres csutkához
  # és a teljes keszlet-hez tartozó kezdeti megoldó-állapotot.

  # az állapot n, m, készleten kívül sorhelyesen tárolja a lerakott elemeket
  # {n, m, készlet, [lehelyezés]}
  @spec kezdet(n :: meret(), m :: meret(), keszlet :: %{elem() => db()}) ::
          kezdo_allapot :: allapot()
  def kezdet(n, m, keszlet) do
    {n, m, keszlet, []}
  end

  # Az uj_allapot az allapot megoldó-állapotból az elem i, j, f
  # paraméterek szerinti elhelyezésével kapott új megoldó-állapot.
  @spec lerak(
          allapot :: allapot(),
          elem :: elem(),
          i :: sorindex(),
          j :: oszlopindex(),
          f :: forgatas()
        ) :: uj_allapot :: allapot()
  def lerak(allapot, elem, i, j, f) do
    {n, m, keszlet, lerakottak} = allapot
    # nem ellenőrzök hibát, mert tudjuk, hogy benne van
    uj_keszlet = Map.update!(keszlet, elem, fn x -> x - 1 end)
    {n, m, uj_keszlet, [{elem, i, j, f} | lerakottak]}
  end

  # l az allapot megoldó-állapotban az elem összes szabályos
  # elhelyezését felsoroló lista; a lista sorrendje tetszőleges.
  @spec hova(allapot :: allapot(), elem :: elem()) :: l :: [lehelyezes()]
  def hova(allapot, elem) do
    {n, m, keszlet, lehelyezesek} = allapot

    if Map.fetch!(keszlet, elem) == 0 do
      []
    else
      hova2(n, m, lehelyezesek, elem)
    end
  end

  def hova2(n, m, lehelyezesek, elem) do
    magassag = length(elem)

    # TODO elég csak, hogy hanyadik
    {ri, _} = elem_ref_hely(elem)

    felette = ri
    alatta = magassag - felette - 1

    combinations1 =
      for i <- felette..(n - alatta - 1),
          j <- 0..(m - 1) do
        {i, j, false}
      end

    combinations2 =
      for i <- alatta..(n - felette - 1),
          j <- 0..(m - 1) do
        {i, j, true}
      end

    combinations = combinations1 ++ combinations2

    Enum.filter(combinations, fn {i, j, f} ->
      # hozzárakom az eddigi lehelyezéshez az újat
      uj_lehelyezesek = [{elem, i, j, f} | lehelyezesek]
      # ha nincs ütközés, maradhat a combinationsban
      Enum.empty?(utkozesek(n, m, uj_lehelyezesek))
    end)
  end

  @spec felvesz(allapot :: allapot()) :: uj_allapot :: allapot()
  # Az uj_allapot az allapot megoldó-állapotból az utoljára lerakott elem
  # felvételével kapott új megoldó-állapot.
  def felvesz(allapot) do
    {n, m, keszlet, [legutolso | lehelyezesek]} = allapot
    uj_keszlet = Map.update!(keszlet, elem(legutolso, 0), fn x -> x + 1 end)
    {n, m, uj_keszlet, lehelyezesek}
  end

  # a csutka sorainak vagy oszlopainak száma
  @type meret() :: pos_integer()
  # a csutka egy sorának indexe
  @type sorindex() :: non_neg_integer()
  # a csutka egy oszlopának indexe
  @type oszlopindex() :: non_neg_integer()
  # false: nincs forgatás; true: 180 fokos forgatás
  @type forgatas() :: boolean()
  # egy elem szöveges leírása
  @type elem() :: [String.t()]
  # egy elem lehelyezése
  @type lehelyezes() :: {elem :: elem(), i :: sorindex(), j :: oszlopindex(), f :: forgatas()}
  # hivatkozás egy lehelyezett elemre
  @type elemindex() :: non_neg_integer()
  # lehelyezett elemek ütközése, a < b
  @type utkozes() :: {a :: elemindex(), b :: elemindex()}

  @type elem_listakent() :: [{sorindex(), oszlopindex()}]

  @spec utkozesek(n :: meret(), m :: meret(), lehelyez :: [lehelyezes()]) :: ut :: [utkozes()]
  # Az n sorból és m oszlopból álló csutkára az elemeket a lehelyez lista szerint helyezve pontosan
  # az ut elempárok ütköznek egymással, lexikografikusan növekvő sorrendben felsorolva.
  def utkozesek(n, m, lehelyez) do
    # elemeket lecserélni csak arra, hogy melyik helyeket foglalják el + index, hogy melyik elem
    elemek = Enum.map(lehelyez, fn e -> elem_helyek(n, m, e) end) |> Enum.with_index()

    Enum.reverse(megold(elemek, []))
  end

  @spec megold(elemek :: [elem_listakent()], [utkozes()]) :: [utkozes()]
  # Létrehozza sorrendhelyesen a párokat, és megnézi a lerakásnál van-e átfedés
  defp megold(_elemek = [{head_piece, head_index} | t], accumulator) do
    # a h-t hasonlítjuk össze a maradék elemekkel
    # ide kerülnek azok a hátralévő elemek közül (párba rendezve), amikkel van metszete
    head_intersect_list =
      Enum.reduce(t, [], fn {piece, piece_index}, acc ->
        intersect = MapSet.intersection(head_piece, piece)

        if MapSet.size(intersect) != 0 do
          # ha van átfedés, belerakom a listáb
          [{head_index, piece_index} | acc]
        else
          acc
        end
      end)

    # tovább hívom a tailre
    # balról fűzés, mert a fenti fordított sorrendben hívja, és majd megfordítom
    megold(t, head_intersect_list ++ accumulator)
  end

  # ha vége, csak visszaadom
  defp megold([], accumulator), do: accumulator

  # elemet, mint string_list kéri
  # megmondja, melyik koordinátán van a ref
  # {ref_i, ref_j}
  def elem_ref_hely(elem_list) do
    list = elem_list

    # megpróbálom pipeolással
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

    {ref_i, ref_j}
  end

  @spec elem_helyek(n :: meret(), m :: meret(), elem :: lehelyezes()) :: elem_listakent()
  # egy lehelyezést átalakít egy listává, amiben fel van sorolva az összes mező amit letakar (elem_listakent() típus)
  # n-t nem használja, de rosszul érezném magamat, ha nem írnám bele
  # lehet majd kell egy gömb? alakú játékhoz (tudom hogy nem tileable)
  def elem_helyek(_n, m, elem) do
    {list, eltol_i, eltol_j, forgat} = elem

    # megpróbálom pipeolással
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

    list =
      if forgat do
        list
        |> Enum.map(fn {i, j} ->
          # középpontos tükrözés: R + (P -> R) ilyen vektorosan, lerajzolom ha kell
          diff_i = i - ref_i
          diff_j = j - ref_j

          # kibontva 2*ref_i - i
          {ref_i - diff_i, ref_j - diff_j}
        end)
      else
        # Ha nem forgatom, csak az eredeti lista
        list
      end

    list
    # eltolás a megadott pozícióba, referencia korrigálás
    |> Enum.map(fn {i, j} -> {i + eltol_i - ref_i, j + eltol_j - ref_j} end)

    # tbh csak betippeltem a kettő közül melyik irány a körbefordulás
    |> Enum.map(fn {i, j} -> {i, Integer.mod(j, m)} end)

    # minden elem egyedi lesz, és majd intersectiont fogok nézni köztük, ezért mehet halmazba
    |> MapSet.new()

    # IO.inspect(list)
    # IO.inspect({ref_i, ref_j})
  end
end

# piece_a = ["XO", " O"]
# piece_b = ["X", "O"]
# s0 = Khf3.kezdet(3, 4, %{piece_a => 1, piece_b => 2})
# Khf3.hova(s0, piece_b) |> length() |> IO.inspect()
#
# s1 = Khf3.lerak(s0, piece_a, 1, 0, true)
#
# Khf3.hova(s1, piece_b) |> IO.inspect()
#
# s2 = Khf3.felvesz(s1)
#
# Khf3.hova(s2, piece_b) |> length() |> IO.inspect()
#
# s3 = Khf3.lerak(s2, piece_b, 0, 0, false)
#
# Khf3.hova(s3, piece_b) |> IO.inspect()
#
# s4 = Khf3.lerak(s3, piece_b, 0, 1, false)
#
# Khf3.hova(s4, piece_b) |> IO.inspect()
# IO.inspect(Khf3.elem_helyek(3, 5, {["OXO"], 0, 0, false}))

# IO.puts("1")
# x = Khf2.utkozesek(3, 5, [{["OXO"], 0, 1, false}, {["XO", "O "], 1, 3, false}])
# IO.inspect(x)
#
# IO.puts("2")
#
# x =
#   Khf2.utkozesek(3, 5, [
#     {["OXO"], 1, 4, false},
#     {["XO", "O "], 2, 4, true}
#   ])
#
# IO.inspect(x)
#
# IO.puts("3")
#
# x =
#   Khf2.utkozesek(4, 5, [
#     {["OXO"], 1, 1, false},
#     {["XOO", "  O"], 1, 1, false},
#     {["X", "O"], 2, 3, false}
#   ])
#
# IO.inspect(x)
#
# IO.puts("4")
#
# x =
#   Khf2.utkozesek(3, 4, [
#     {["XO"], 1, 1, false},
#     {["X", "O"], 1, 1, false},
#     {["OOO", " X "], 1, 1, false}
#   ])
#
# IO.inspect(x)
