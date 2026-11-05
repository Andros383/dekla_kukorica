defmodule Peti do
  @moduledoc """
  Kukorica kirakási lépések kiértékelése
  @author "Ferencz Péter <189182@edu.bme.hu>"
  @date   "2026-10-22"
  """

  # a megoldó-állapot
  @type allapot() :: %{
          :pieces => pieces(),
          :state => [{piece(), [position()]}],
          :width => pos(),
          :height => pos()
        }
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

  @type pos() :: pos_integer()
  @type piece() :: %{
          :width => pos(),
          :height => pos(),
          :elements => MapSet.t({position()}),
          :ref => position()
        }
  @type pieces() :: [piece()]
  @type position() :: {pos(), pos()}

  @spec kezdet(n :: meret(), m :: meret(), keszlet :: %{elem() => db()}) ::
          kezdo_allapot :: allapot()
  # Létrehozza az n sorból és m oszlopból álló üres csutkához
  # és a teljes keszlet-hez tartozó kezdeti megoldó-állapotot.
  def kezdet(n, m, keszlet) do
    %{
      :pieces => for({el, count} <- keszlet, into: [], do: {convertPiece(el), count}),
      :state => [],
      :width => m,
      :height => n
    }
  end

  @spec convertPiece(element :: elem()) :: piece()
  defp convertPiece(el) do
    w = String.length(Enum.at(el, 0))
    h = Enum.count(el)

    ref =
      Enum.find_value(0..(h - 1), fn y ->
        Enum.find_value(0..(w - 1), fn x ->
          if String.at(Enum.at(el, y), x) == "X", do: {x, y}
        end)
      end)

    %{
      :width => w,
      :height => h,
      :elements =>
        for(
          y <- 0..(h - 1),
          x <- 0..(w - 1),
          p = String.at(Enum.at(el, y), x),
          p != " ",
          into: MapSet.new(),
          do: {x, y}
        ),
      :ref => ref
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
  def lerak(state, elem, i, j, rotate) do
    piece = convertPiece(elem)
    cells = getCells(state, piece, i, j, rotate)

    %{
      :pieces =>
        Enum.map(state[:pieces], fn {el, count} ->
          if el == piece, do: {el, count - 1}, else: {el, count}
        end),
      :state => [{piece, cells} | state[:state]],
      :width => state[:width],
      :height => state[:height]
    }
  end

  @spec getCells(
          state :: allapot(),
          piece :: piece(),
          i :: pos(),
          j :: pos(),
          rotate :: boolean()
        ) :: MapSet.t(position())
  defp getCells(
         %{:width => state_w},
         %{:elements => elements, :ref => {refx, refy}},
         i,
         j,
         rotate
       ) do
    for {x, y} <- elements, into: MapSet.new() do
      {dx, dy} = {x - refx, y - refy}
      {dx, dy} = if rotate, do: {-dx, -dy}, else: {dx, dy}
      {i + dy, Integer.mod(j + dx, state_w)}
    end
  end

  @spec hova(allapot :: allapot(), elem :: elem()) :: l :: [lehelyezes()]
  # l az allapot megoldó-állapotban az elem összes szabályos
  # elhelyezését felsoroló lista; a lista sorrendje tetszőleges.
  def hova(state, elem) do
    piece = convertPiece(elem)
    available = Enum.any?(state[:pieces], fn {el, count} -> el == piece and count > 0 end)

    if available do
      occupied =
        Enum.reduce(state[:state], MapSet.new(), fn {_piece, cells}, acc ->
          MapSet.union(acc, cells)
        end)

      for y <- 0..(state[:height] - 1),
          x <- 0..(state[:width] - 1),
          f <- [false, true],
          canCellsBePlaced?(getCells(state, piece, y, x, f), state, occupied),
          do: {y, x, f}
    else
      []
    end
  end

  @spec canCellsBePlaced?(
          cells :: [position()],
          state :: allapot(),
          occupied :: MapSet.t({position()})
        ) :: boolean()
  defp canCellsBePlaced?(cells, state, occupied) do
    Enum.all?(cells, fn {y, x} ->
      y >= 0 and y < state[:height] and not MapSet.member?(occupied, {y, x})
    end)
  end

  @spec felvesz(allapot :: allapot()) :: uj_allapot :: allapot()
  # Az uj_allapot az allapot megoldó-állapotból az utoljára lerakott elem
  # felvételével kapott új megoldó-állapot.
  def felvesz(state = %{:state => []}), do: state

  def felvesz(state = %{:state => [{headPiece, _headCells} | tail]}) do
    new_pieces =
      Enum.map(state[:pieces], fn {el, count} ->
        if el == headPiece, do: {el, count + 1}, else: {el, count}
      end)

    %{state | :state => tail, :pieces => new_pieces}
  end
end

# piece_a = ["XO", " O"]
# piece_b = ["X", "O"]
# s0 = Khf3.kezdet(3, 4, %{piece_a => 1, piece_b => 2})
# IO.inspect(Khf3.hova(s0, piece_b) |> Enum.count())
# s1 = Khf3.lerak(s0, piece_a, 1, 0, true)
# IO.inspect(Khf3.hova(s1, piece_b))
# s2 = Khf3.felvesz(s1)
# IO.inspect(Khf3.hova(s2, piece_b) |> length())
# s3 = Khf3.lerak(s2, piece_b, 0, 0, false)
# IO.inspect(Khf3.hova(s3, piece_b))
# s4 = Khf3.lerak(s3, piece_b, 0, 1, false)
# IO.inspect(Khf3.hova(s4, piece_b))
