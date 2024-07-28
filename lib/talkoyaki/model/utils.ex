defmodule Talkoyaki.Model.Utils do
  @moduledoc false

  defmacro transaction(do: block) do
    quote do
      Memento.transaction!(fn -> unquote(block) end)
    end
  end
end
