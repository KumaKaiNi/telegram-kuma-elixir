defmodule KumaBot.Module do
  @bot_name Application.get_env(:kuma_bot, :username)

  defmacro __using__(_options) do
    quote do
      import KumaBot.Module
      import Nadia
      require Logger
      use GenServer

      def start_link(opts \\ []) do
        Logger.debug "Starting bot!"
        GenServer.start_link(__MODULE__, :ok, opts)
      end

      def init(:ok) do
        send self, {:update, 0}
        {:ok, []}
      end

      def handle_info({:update, id}, state) do
        try do
          new_id = get_updates([offset: id]) |> process_updates

          :erlang.send_after(100, self, {:update, new_id + 1})
          {:noreply, state}
        rescue
          error ->
            Logger.error "!! ERROR !!"
            IO.inspect error
            Logger.error "!! ERROR !!"

            :erlang.send_after(100, self, {:update, 0})
            {:noreply, state}
        end
      end

      def handle_info(_object, state), do: {:noreply, state}

      def process_updates({:ok, []}), do: -1
      def process_updates({:ok, updates}) do
        for update <- updates do
          try do
            chat_title = cond do
              Map.has_key?(update.message.chat, :title) -> case update.message.chat.title do
                nil -> "private"
                title -> title
              end
              true -> "private"
            end

            message_text = cond do
              Map.has_key?(update.message, :text) -> case update.message.text do
                nil  -> update.message.caption
                text -> text
              end
              Map.has_key?(update.message, :caption) -> update.message.caption
              true -> nil
            end

            case message_text do
              nil -> nil
              message_text -> Logger.info("[#{chat_title} (#{update.message.chat.id})] #{update.message.from.first_name}: #{message_text}")
            end

            unless Application.get_env(:kuma_bot, :halt_updates) do
              update |> process_update
            end
          rescue
            _error -> nil
          end
        end

        List.last(updates).update_id
      end

      def process_updates({:error, error}) do
        case error do
          %Nadia.Model.Error{reason: msg} -> Logger.warn "Nadia: #{msg}"
          error -> Logger.error "Error: #{error}"
        end

        -1
      end
    end
  end

  defmacro handle(:edited_message, do: body) do
    quote do
      def process_update(
        %Nadia.Model.Update{
          edited_message: var!(message)
        } = var!(update)) when var!(message) != nil do
        unquote(body)
      end
    end
  end

  defmacro handle(:inline_query, do: body) do
    quote do
      def process_update(
        %Nadia.Model.Update{
          inline_query: %{
            query: var!(query),
            id: var!(id)
          } = var!(object)
        } = var!(update)) when var!(object) != nil do
        unquote(body)
      end
    end
  end

  defmacro handle(:chosen_inline_result, do: body) do
    quote do
      def process_update(
        %Nadia.Model.Update{
          chosen_inline_result: var!(object),
          message: var!(message)
        } = var!(update)) when var!(object) != nil do
        unquote(body)
      end
    end
  end

  defmacro handle(:callback_query, do: body) do
    quote do
      def process_update(
        %Nadia.Model.Update{
          callback_query: var!(object),
          message: var!(message)
        } = var!(update)) when var!(object) != nil do
        unquote(body)
      end
    end
  end

  defmacro handle(type, do: body) do
    quote do
      def process_update(
        %Nadia.Model.Update{
          message: %Nadia.Model.Message{
            unquote(type) => var!(object),
            chat: %{id: var!(id)}
          } = var!(message)
        } = var!(update)) when var!(object) != nil do
        unquote(body)
      end
    end
  end

  defmacro command(commands, do: function) when is_list(commands) do
    for text <- commands, do: gen_commands(text, do: function)
  end

  defmacro command(text, do: function) do
    gen_commands(text, do: function)
  end

  defmacro match(matches, do: function) when is_list(matches) do
    for text <- matches, do: gen_matches(text, do: function)
  end

  defmacro match(text, do: function) do
    gen_matches(text, do: function)
  end

  defmacro reply(function) do
    quote do
      var!(id) |> unquote(function)
    end
  end

  defp gen_commands(text, do: function) do
    quote do
      if var!(message) != nil do
        if var!(object) |> String.split |> List.first == "/" <> unquote(text) do
          Task.async(fn -> unquote(function) end)
        end

        if var!(object) |> String.split |> List.first == "/" <> unquote(text) <> "@" <> unquote(@bot_name) do
          Task.async(fn -> unquote(function) end)
        end
      end
    end
  end

  defp gen_matches(text, do: function) do
    quote do
      if var!(message) != nil do
        if var!(object) |> String.trim_trailing == unquote(text) do
          Task.async(fn -> unquote(function) end)
        end
      end
    end
  end
end
