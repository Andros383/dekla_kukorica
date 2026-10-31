defmodule Milan do
  @moduledoc """
  Kukorica-kirakós
  @author "Tóth Milán Györhy <milan.gyorgy.toth@gmail.com>"
  @date   "2026-10-27"
  """

  # a csutka sorainak vagy oszlopainak száma
  @type meret() :: pos_integer()
  # egy elem szöveges leírása
  @type elem() :: [String.t()]
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
  # a megoldó-állapot
  @type allapot() :: any()

  @spec megold(n :: meret(), m :: meret(), keszlet :: %{elem() => db()}) ::
          megoldas :: %{elem() => [lehelyezes()]} | nil
  # A n sorból és m oszlopból álló üres csutkán a keszlet elemek
  # egy lehetséges helyes elhelyezése megoldas, vagy nil, ha nincs ilyen.
  def megold(n, m, pieces) do
    bS = kezdet(n, m, pieces)
    # össz hány elem van, ezzel rövidebb a végső ág ellenörzése
    tPN = Enum.reduce(pieces, 0, fn {_k, v}, acc -> acc + v end)

    case solve(bS, tPN) do
      nil ->
        nil

      sol ->
        eMap = Map.new(pieces, fn {piece, _} -> {piece, []} end)

        Enum.reduce(sol, eMap, fn {piece, _coords, x, y, rot}, acc ->
          Map.update!(acc, piece, fn list ->
            [{x, y, rot} | list]
          end)
        end)
    end
  end

  @spec solve(state :: allapot(), pieceNum :: integer()) :: placed :: MapSet
  # rekurzív megoldó függvény
  # megpróbálja a legelső üres cellákat lefedni
  #
  defp solve(state, pieceNum) do
    {
      n,
      m,
      pieces,
      placed,
      _relCords,
      occupied
    } = state

    if pieceNum == 0 do
      placed
    else
      # első üres cella megtalálása, erre próbálunk illeszteni
      firstEmpty =
        Enum.find_value(0..(n - 1), fn i ->
          Enum.find_value(0..(m - 1), fn j ->
            if !MapSet.member?(occupied, {i, j}), do: {i, j}
          end)
        end)

      case firstEmpty do
        nil ->
          nil

        {cX, cY} ->
          poss =
            Enum.flat_map(pieces, fn {p, db} ->
              if db > 0 do
                hova(state, p, cX, cY)
                |> Enum.map(fn place -> {p, place} end)
              else
                []
              end
            end)

          Enum.find_value(poss, fn {p, {x, y, rot}} ->
            nState = lerak(state, p, x, y, rot)
            solve(nState, pieceNum - 1)
          end)
      end
    end
  end

  defp kezdet(n, m, pieces) do
    {
      n,
      m,
      pieces,
      [],
      # elölre kiszámítjuk a relatív koordinátáit az egyes elemeknek
      # elölre kiszámítjuk min/max x érdékét hogy ne kelljen később lelógást ellenőrizni
      Enum.reduce(pieces, Map.new(), fn {k, _v}, acc ->
        cords = getCords(k, false)
        acc = Map.put(acc, {k, false}, cords)

        rotCords =
          cords
          |> Enum.map(fn {x, y} -> {-x, -y} end)
          |> MapSet.new()

        Map.put(acc, {k, true}, rotCords)
      end),
      MapSet.new()
    }
  end

  @spec lerak(
          allapot :: allapot(),
          elem :: elem(),
          i :: sorindex(),
          j :: oszlopindex(),
          f :: forgatas()
        ) :: uj_allapot :: allapot()
  # Az uj_allapot az allapot megoldó-állapotból az elem i, j, f
  # paraméterek szerinti elhelyezésével kapott új megoldó-állapot.
  defp lerak(state, piece, x, y, rot) do
    {
      n,
      m,
      pieces,
      placed,
      relCords,
      occupied
    } = state

    # relatív koordináták eltolása
    nCoords =
      MapSet.new(Map.fetch!(relCords, {piece, rot}), fn {dx, dy} ->
        {x + dx, Integer.mod(y + dy, m)}
      end)

    {
      n,
      m,
      Map.update!(pieces, piece, &(&1 - 1)),
      [{piece, nCoords, x, y, rot} | placed],
      relCords,
      MapSet.union(occupied, nCoords)
    }
  end

  @spec hova(allapot :: allapot(), elem :: elem(), hitCX :: integer(), hitCY :: integer()) ::
          l :: [lehelyezes()]
  # összes olyan legálsi lerakást kiszámolja ami tartalmazza a {hitCX, hitCY} koorinátákat
  defp hova(state, piece, hitCX, hitCY) do
    {
      n,
      m,
      pieces,
      _,
      relCords,
      occupied
    } = state

    if(Map.fetch!(pieces, piece) == 0) do
      []
    else
      normO = Map.fetch!(relCords, {piece, false})
      rotO = Map.fetch!(relCords, {piece, true})

      norm =
        Enum.flat_map(normO, fn {x, y} ->
          i = hitCX - x
          j = Integer.mod(hitCY - y, m)

          if isValidPlacement?(occupied, normO, i, j, n, m) do
            [{i, j, false}]
          else
            []
          end
        end)
        |> Enum.uniq()

      rot =
        Enum.flat_map(rotO, fn {x, y} ->
          i = hitCX - x
          j = Integer.mod(hitCY - y, m)

          if isValidPlacement?(occupied, rotO, i, j, n, m) do
            [{i, j, true}]
          else
            []
          end
        end)
        |> Enum.uniq()

      norm ++ rot
    end
  end

  @spec getCords(piece :: [String.t()], rot :: boolean()) :: {ret :: MapSet}
  # convertálja egy elemet az összes része koordinátájára
  defp getCords(piece, rot) do
    {xX, xY} = findX(piece, 0)

    piece
    # ezzel hozzárendelünk X coordinátákat de el is dobjuk, hogy ne kelljen indexelni
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, pX} ->
      row
      # hasonlóan Y coordinátákkal
      |> String.graphemes()
      |> Enum.with_index()
      # kiszedi a " "
      |> Enum.filter(fn {l, _} -> l == "X" || l == "O" end)
      |> Enum.map(fn {_, pY} ->
        if rot do
          {xX - pX, xY - pY}
        else
          {pX - xX, pY - xY}
        end
      end)
    end)
    |> MapSet.new()
  end

  @spec findX(list :: [String.t()], acc :: integer()) ::
          {relPozX :: sorindex(), relPozY :: oszlopindex()}
  # megkeresi az elemben az x lokális koordinátáját
  defp findX([x | y], acc) do
    case :binary.match(x, "X") do
      {index, _} -> {acc, index}
      :nomatch -> findX(y, acc + 1)
    end
  end

  @spec isValidPlacement?(
          placed :: MapSet,
          piece :: MapSet,
          i :: integer(),
          j :: integer(),
          n :: integer(),
          m :: integer()
        ) :: {val :: boolean()}
  # ellenőrzi, hogy
  # 1. van-e ütközés már lerakott elemmel
  # 2. kilóg-e a tábláról
  defp isValidPlacement?(placed, piece, i, j, n, m) do
    Enum.all?(piece, fn {x, y} ->
      nX = x + i
      nY = Integer.mod(y + j, m)

      nX >= 0 && nX < n && not MapSet.member?(placed, {nX, nY})
    end)
  end
end
