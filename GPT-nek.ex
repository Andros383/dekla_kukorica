def megold(n, m, string_keszlet) do
  meret = {n, m}

  keszlet = %{}
  elem_stringtomb_map = %{}

  # TODO ChatGPT dupla map reduce a kettő helyett, ha sokkal gyorsabb
  # mivel szintaktikai trükk, nem gondolom problémának, hogy MI-ztem
  keszlet =
    Map.new(string_keszlet, fn {k, v} ->
      {elem_helyek(meret, k), v}
    end)

  # vissza lehessen írni alap reprezentációs mapra
  elem_stringtomb_map =
    Map.new(string_keszlet, fn {k, _v} ->
      {elem_helyek(meret, k), k}
    end)

  meret = {n, m}

  # állapot: méret, készlet, tábla, lehelyezések, {elem_ref_hellyel, lehelyezés} formátumban
  allapot = {meret, keszlet, MapSet.new(), Map.new()}

  # domainek mindenképpen azok, hogy egy elemet hova lehet lerakni, nem pedig hogy egy helyre milyen elemek kerülhetnek
  # mert egy helyet másik lerakással is le lehet fedni
  solution = lerak(allapot)

  if solution == nil do
    nil
  else
    Map.new(solution, fn {k, v} ->
      {Map.fetch!(elem_stringtomb_map, k), v}
    end)
  end
end

def lerak(allapot) do
  {meret, keszlet, tabla, sol} = allapot

  # elm nem érdemes a készletet find_valueozni, mert a végén úgy is mindet le kell rakni
  # meg lehet adni az elemek egy sorrendjét, csak ugye nem érdemes
  # szóval a külső for felesleges

  # az első elem, amiből nem 0 darab van
  {elem, _db} = Enum.find(keszlet, fn {k, v} -> v > 0 end)
  # itt már csak a valid lerakások vannak, készletben lehet 0 is, akkor nem ad lerakást rá
  lerakasok = hova(allapot, elem)

  # kiveszem az elemet
  uj_keszlet = Map.update!(keszlet, elem, fn x -> x - 1 end)

  # megtalálja az első értéket, és visszaadja a listát amire nem nil-t ad vissza
  Enum.find_value(lerakasok, nil, fn lerakas ->
    lerakott_elem_helyek = elem_lerak(meret, elem, lerakas)

    if MapSet.disjoint?(tabla, lerakott_elem_helyek) do
      # sikeres lerakás, megyünk tovább
      uj_tabla = MapSet.union(tabla, lerakott_elem_helyek)
      uj_sol = Map.update(sol, elem, [lerakas], fn x -> [lerakas | x] end)
      uj_allapot = {meret, uj_keszlet, uj_tabla, uj_sol}

      if Enum.all?(uj_keszlet, fn {_k, v} -> v == 0 end) do
        uj_sol
      else
        lerak(uj_allapot)
      end
    else
      nil
    end
  end)
end

# hova lehet lerakni egy adott elemet egy állapotban
# Ezt lehet utána fogom szűrni, de most jó ez így
def hova(allapot, elem) do
  {meret = {n, m}, keszlet, tabla, _lerakasok} = allapot

  {elem_lista, ref_i, _ref_j} = elem
  # ha nincs több elem, akkor nem lehet lerakni
  if Map.fetch!(keszlet, elem) == 0 do
    []
  else

    # combinations = combinations1 ++ combinations2
    combinations =
      for i <- 0..(n - 1),
          j <- 0..(m - 1),
          f <- [true, false] do
        {i, j, f}
      end

    Enum.filter(combinations, fn {i, j, f} ->
      mostani_helyek = elem_lerak(meret, elem, {i, j, f})

      # ha az új helyek disjoint, akkor maradhat
      lelog_e =
        Enum.any?(mostani_helyek, fn {i, j} ->
          i < 0 || n <= i
        end)

      MapSet.disjoint?(mostani_helyek, tabla) && !lelog_e
    end)
  end
end

# itt most csak az elemet, mint listát kapja meg, megadja melyik mezők vannak letakarva
def elem_helyek(meret, elem) do
  {_n, m} = meret
  list = elem

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
    list
    |> Enum.map(fn {i, j} -> {i, Integer.mod(j, m)} end)
    |> MapSet.new()

  {list, ref_i, ref_j}
end

def elem_lerak(meret, elem_reffel, lehelyezes) do
  {_n, m} = meret
  {list, ref_i, ref_j} = elem_reffel
  {eltol_i, eltol_j, forgat} = lehelyezes

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
end
