defmodule BenchmarkInput do
  @moduledoc """
  Egész file ChatGPT-vel generálva, prompt:
  Adott a következő feladat leírása. Szeretném a kódom optimalizálni, viszont nem adtak nagy bemeneteket a felad készítői.

  Feladatot egy olyan elixir függvény írása, ami megkapja bemenetül n-et és m-et, és generál ennek megfelelően egy helyes bemenetet, majd azon meghívja a Nhf1.megold() függvényemet. A függvény futásidejét mérje Benchee modullal. A generált bemenet minden esetben olyan legyen, hogy a táblát ki lehet belőle rakni: csak ezekre az esetekre szeretnék optimalizálni.

  Ha nem egyértelmű a feladat leírása, szívesen válaszolok kérdésekre.

  A kérdésekre adott válasz:
  1:
  Nekem fontos, hogy az elemek mindenképpen összefüggőek legyenek, nem szeretném, ha például a {0, 0}, {3, 5} elem lenne.
  2:
  Szeretném, ha az elemek méretben változatosak lennének. Jó, ha vannak kicsi, és jó ha vannak nagy elemek is. Emellett szeretnék egy opciót arra, hogy benne van-e az 1x1-es elem (mert ezzel kapcsolatban van egy optimalizációs ötletem).
  3:
  Beküldtem neki a már helyes (de lassú) megold függvényemet

  Ha szükséges, egész beszélgetést megmutatom. A generált válaszban vannak ötletei a kódom optimalizálására, de ezek mind olyanok, amiket magamtól is észrevettem beküldés előtt.
  """
  def generate(n, m, opts \\ []) do
    include_singleton? = Keyword.get(opts, :include_singleton, true)
    max_piece_size = Keyword.get(opts, :max_piece_size, 8)

    if n < 1 or m < 1 do
      raise ArgumentError, "n és m legalább 1 kell legyen"
    end

    if max_piece_size < 2 do
      raise ArgumentError, "max_piece_size legalább 2 kell legyen"
    end

    if not include_singleton? and n * m == 1 do
      raise ArgumentError, "1x1-es táblához szükséges az 1x1-es elem"
    end

    remaining =
      for i <- 0..(n - 1),
          j <- 0..(m - 1),
          into: MapSet.new() do
        {i, j}
      end

    # Ha kérünk 1x1-es elemet, előre lefoglalunk
    # egy véletlenszerű mezőt.
    {remaining, pieces} =
      if include_singleton? do
        cell = Enum.random(MapSet.to_list(remaining))

        {
          MapSet.delete(remaining, cell),
          [MapSet.new([cell])]
        }
      else
        {remaining, []}
      end

    pieces =
      partition(remaining, pieces, n, m, max_piece_size)

    # Az esetlegesen megmaradt 1x1-es elemek összevonása.
    pieces =
      if include_singleton? do
        pieces
      else
        merge_singletons(pieces, n, m)
      end

    # Átalakítás a feladatban megadott reprezentációra.
    Enum.reduce(pieces, %{}, fn piece, acc ->
      shape = to_string_shape(piece)

      Map.update(acc, shape, 1, &(&1 + 1))
    end)
  end

  # A teljes tábla felosztása.
  defp partition(remaining, pieces, n, m, max_size) do
    if MapSet.size(remaining) == 0 do
      pieces
    else
      start = Enum.random(MapSet.to_list(remaining))

      remaining = MapSet.delete(remaining, start)

      upper = min(max_size, MapSet.size(remaining) + 1)

      target =
        if upper <= 1 do
          1
        else
          :rand.uniform(upper - 1) + 1
        end

      {piece, remaining} =
        grow_piece(
          MapSet.new([start]),
          remaining,
          target,
          n,
          m
        )

      partition(
        remaining,
        [piece | pieces],
        n,
        m,
        max_size
      )
    end
  end

  # Egy elem növelése véletlenszerű szomszédos mezőkkel.
  defp grow_piece(piece, remaining, target, n, m) do
    if MapSet.size(piece) >= target do
      {piece, remaining}
    else
      frontier =
        piece
        |> Enum.flat_map(&neighbors(&1, n, m))
        |> Enum.uniq()
        |> Enum.filter(&MapSet.member?(remaining, &1))

      if frontier == [] do
        {piece, remaining}
      else
        cell = Enum.random(frontier)

        grow_piece(
          MapSet.put(piece, cell),
          MapSet.delete(remaining, cell),
          target,
          n,
          m
        )
      end
    end
  end

  # A négy ortogonális szomszéd.
  # A generálás során nem használunk modulo oszlopindexelést.
  defp neighbors({i, j}, n, m) do
    [
      {i - 1, j},
      {i + 1, j},
      {i, j - 1},
      {i, j + 1}
    ]
    |> Enum.filter(fn {x, y} ->
      x >= 0 and x < n and y >= 0 and y < m
    end)
  end

  # Az 1x1-es elemek összevonása szomszédos elemekkel.
  defp merge_singletons(pieces, n, m) do
    singleton =
      Enum.find(pieces, fn p ->
        MapSet.size(p) == 1
      end)

    if singleton == nil do
      pieces
    else
      [cell] = MapSet.to_list(singleton)

      others = Enum.reject(pieces, &(&1 == singleton))

      neighbor =
        Enum.find(others, fn piece ->
          Enum.any?(neighbors(cell, n, m), fn neighbor_cell ->
            MapSet.member?(piece, neighbor_cell)
          end)
        end)

      merged = MapSet.union(singleton, neighbor)

      new_pieces =
        [merged | Enum.reject(others, &(&1 == neighbor))]

      merge_singletons(new_pieces, n, m)
    end
  end

  # Egy összefüggő mezőhalmaz átalakítása stringlistává.
  defp to_string_shape(piece) do
    # Véletlenszerű referencia-kukoricaszem.
    reference = Enum.random(MapSet.to_list(piece))

    rows = Enum.map(piece, &elem(&1, 0))
    cols = Enum.map(piece, &elem(&1, 1))

    min_row = Enum.min(rows)
    max_row = Enum.max(rows)
    min_col = Enum.min(cols)
    max_col = Enum.max(cols)

    for i <- min_row..max_row do
      for j <- min_col..max_col do
        cell = {i, j}

        cond do
          cell == reference -> ?X
          MapSet.member?(piece, cell) -> ?O
          true -> ?\s
        end
      end
      |> List.to_string()
    end
  end

  def benchmark(n, m, opts \\ []) do
    keszlet = BenchmarkInput.generate(n, m, opts)

    Benchee.run(
      %{
        "Nhf1.megold #{n}x#{m}" => fn ->
          Nhf1.megold(n, m, keszlet)
        end
      },
      time: 5,
      warmup: 2
    )
  end

  def benchmark2(n, m, opts \\ []) do
    keszlet = BenchmarkInput.generate(n, m, opts)

    {time, result} =
      :timer.tc(fn ->
        Nhf1.megold(n, m, keszlet)
      end)

    IO.puts("Futásidő: #{time / 1000} ms")

    result
  end

  def benchmarkMilan(n, m, opts \\ []) do
    keszlet = BenchmarkInput.generate(n, m, opts)

    Benchee.run(
      %{
        "Milan.megold #{n}x#{m}" => fn ->
          Milan.megold(n, m, keszlet)
        end
      },
      time: 5,
      warmup: 2
    )
  end

  def benchmark2Milan(n, m, opts \\ []) do
    keszlet = BenchmarkInput.generate(n, m, opts)

    {time, result} =
      :timer.tc(fn ->
        Milan.megold(n, m, keszlet)
      end)

    IO.puts("Futásidő Milán: #{time / 1000} ms")

    result
  end
end

IO.inspect("asd")
BenchmarkInput.benchmark2(4, 4)
BenchmarkInput.benchmark2Milan(10, 10)
# (4, 4)->0.4s

# BenchmarkInput.benchmark(15, 15)
# BenchmarkInput.benchmark(20, 20)
# BenchmarkInput.benchmark(30, 30, max_piece_size: 12)

# # Alapértelmezés: lehet 1x1-es elem.
# keszlet = BenchmarkInput.generate(20, 20)
#
# # Garantáltan legyen 1x1-es elem.
# keszlet = BenchmarkInput.generate(20, 20, include_singleton: true)
#
# # Ne legyen 1x1-es elem.
# keszlet = BenchmarkInput.generate(20, 20, include_singleton: false)
#
# # Legfeljebb 15 kukoricaszemes elemek.
# keszlet = BenchmarkInput.generate(20, 20, max_piece_size: 15)
