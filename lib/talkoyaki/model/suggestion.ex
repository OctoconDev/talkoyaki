defmodule Talkoyaki.Model.Suggestion do
  @moduledoc false
  use Memento.Table,
    attributes: [
      :id,
      :title,
      :description,
      :type,
      :author_id,
      :thread_id,
      :bumps
    ],
    index: [:thread_id],
    type: :ordered_set,
    autoincrement: true
end
