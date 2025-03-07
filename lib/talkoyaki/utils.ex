defmodule Talkoyaki.Utils do
  @moduledoc false

  def brand_color, do: 212_902

  def ephemeral_flag, do: Bitwise.bsl(1, 6)

  def text_input(opts) do
    type =
      case Keyword.get(opts, :type, :short) do
        :short -> 1
        :long -> 2
      end

    %{
      type: 1,
      components: [
        %{
          type: 4,
          custom_id: Keyword.get(opts, :id),
          style: type,
          label: Keyword.get(opts, :label),
          min_length: Keyword.get(opts, :min_length),
          max_length: Keyword.get(opts, :max_length),
          placeholder: Keyword.get(opts, :placeholder),
          required: true
        }
      ]
    }
  end

  def send_dm_danger(author_id, title, message) do
    send_dm(author_id, title, message, "#FF0000")
  end

  def send_dm_success(author_id, title, message) do
    send_dm(author_id, title, message, "#00FF00")
  end

  def send_dm(author_id, title, message, color) do
    {:ok, channel} = Nostrum.Api.User.create_dm(author_id)

    Nostrum.Api.Message.create(channel.id, %{
      embeds: [
        %Nostrum.Struct.Embed{
          title: title,
          color: hex_to_int(color),
          description: message
        }
      ]
    })
  end

  def error_embed(error, ephemeral? \\ true),
    do: [
      embeds: [
        %{
          title: ":x: Whoops!",
          description: error,
          color: 0xFF0000
        }
      ],
      ephemeral?: ephemeral?
    ]

  def success_embed_raw(success) do
    %{
      title: ":white_check_mark: Success!",
      description: success,
      color: 0x00FF00
    }
  end

  def success_embed(success, ephemeral? \\ true),
    do: [
      embeds: [success_embed_raw(success)],
      ephemeral?: ephemeral?
    ]

  def hex_to_int(nil), do: brand_color()

  def hex_to_int(hex) do
    hex
    |> String.downcase()
    |> String.replace_leading("#", "")
    |> String.to_integer(16)
  end

  def get_command_option(options, name) do
    case Enum.find(options, fn %{name: option} -> option == name end) do
      nil -> nil
      option -> Map.get(option, :value)
    end
  end
end
