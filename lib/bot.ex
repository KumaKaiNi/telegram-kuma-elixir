defmodule KumaBot.Bot do
  use KumaBot.Module
  import KumaBot.Util
  require Logger

  handle :text do
    name = message.from.first_name
    user = query_data("users", message.from.id)

    if user == nil or user != name do
      store_data("users", message.from.id, name)
    end

    unless message.chat.type == "private" do
      chat_users = query_data("chats", message.chat.id)

      case chat_users do
        nil -> store_data("chats", message.chat.id, [message.from.id])
        chat_users ->
          unless Enum.member?(chat_users, message.from.id) do
            store_data("chats", message.chat.id, chat_users ++ [message.from.id])
          end
      end
    end

    command "kuma" do
      Logger.warn "== DEBUG =="
      IO.inspect update
      Logger.warn "== DEBUG =="

      reply send_chat_action "record_audio"

      file = download_dep(Enum.random(kuma_replies))
      reply send_voice file
    end

    command "help" do
      reply send_message """
      First ship of the Kuma-class light cruisers, Kuma, kuma.
      Born in Sasebo, kuma. I got some old parts, but I'll try my best, kuma.

      /coin - flips a coin.
      /random - picks a random item from a list.
      /predict - sends a prediction.
      /message - random dark souls message.
      /search - returns the first DuckDuckGo result.
      /tts :Voice text - speaks what you say. Via acapela-group.
      /dan - returns a random recent image using a danbooru.
      /lewd - random nsfw danbooru post.
      /safe - random sfw danbooru post.
      /smug - sends a smug anime girl.

      Source (v3.0.0): https://github.com/KumaKaiNi/telegram-kuma-elixir
      """, [disable_web_page_preview: true]
    end

    command "botsrights" do
      reply send_message "http://reddit.com/r/botsrights"
    end

    command "dank" do
      case message do
        %{from: %{first_name: name}} ->
          reply send_message "Shut the fuck up, #{name}"
        %{from: %{username: name}} ->
          reply send_message "Shut the fuck up, @#{name}"
      end
    end

    command ["s", "find", "search"] do
      try do
        [_ | search_term] = String.split(message.text)

        reply send_chat_action "typing"

        query = search_term |> Enum.join(" ") |> URI.encode_www_form
        request = "http://api.duckduckgo.com/?q=#{query}&format=json" |> HTTPoison.get!
        response = Poison.Parser.parse!((request.body), keys: :atoms)
        result = response."AbstractURL"
        text = response."AbstractText"

        case result do
          "" -> reply send_message "Nothing found!"
          result ->
            try do
              case text do
                "" -> reply send_message result
                text -> reply send_message "#{text}\n\n#{result}", [disable_web_page_preview: true]
              end
            rescue
              error ->
                reply send_message "fsdafsd"
                Logger.log :warn, error
            end
        end
      rescue
        _ -> reply send_message "Nothing found!"
      end
    end

    command ["coin", "flip"] do
      reply send_message Enum.random(["Heads.", "Tails."])
    end

    command ["choose", "pick", "random"] do
      [_ | query] = String.split(message.text)
      choices = query |> Enum.join(" ") |> String.split(", ")
      reply send_message Enum.random(choices)
    end

    command ["predict", "ask"] do
      predictions = [
        "It is certain.",
        "It is decidedly so.",
        "Without a doubt.",
        "Yes, definitely.",
        "You may rely on it.",
        "As I see it, yes.",
        "Most likely.",
        "Outlook good.",
        "Yes.",
        "Signs point to yes.",
        "Reply hazy, try again.",
        "Ask again later.",
        "Better not tell you now.",
        "Cannot predict now.",
        "Concentrate and ask again.",
        "Don't count on it.",
        "My reply is no.",
        "My sources say no.",
        "Outlook not so good.",
        "Very doubtful."
      ]

      cond do
        length(message.text |> String.split) == 1 ->
          reply send_message "What is the question, kuma?"
        length(message.text |> String.split) > 1 ->
          reply send_message Enum.random(predictions)
      end
    end

    command "message" do
      request = "http://souls.riichi.me/api" |> HTTPoison.get!
      response = Poison.Parser.parse!((request.body), keys: :atoms)
      m = response.message

      reply send_message m
    end

    command "smug" do
      url = "https://api.imgur.com/3/album/zSNC1"
      auth = %{"Authorization" => "Client-ID #{Application.get_env(:kuma_bot, :imgur_client_id)}"}

      request = HTTPoison.get!(url, auth)
      response = Poison.Parser.parse!((request.body), keys: :atoms)

      try do
        reply send_chat_action "upload_photo"

        result = response.data.images |> Enum.shuffle |> Enum.find(fn post -> is_image?(post.link) == true end)
        file = download result.link

        reply send_photo file
        File.rm file
      rescue
        error ->
          reply send_message "fsdafsd"
          Logger.warn error
      end
    end

    command ["dan", "danbooru"] do
      try do
        [_ | search_term] = String.split(message.text)
        [tag1 | tag2] = search_term

        dan = cond do
          length(tag2) >= 1 -> danbooru(tag1, List.first(tag2))
          true -> danbooru(tag1, "")
        end

        case dan do
          {artist, post_id, file} ->
            caption = "Artist: #{artist}\n\nvia https://danbooru.donmai.us/posts/#{post_id}"

            reply send_chat_action "upload_photo"

            reply send_photo file, [caption: caption]
            File.rm file
          message -> reply send_message message
        end
      rescue
        _ ->
          {artist, post_id, file} = danbooru("order:rank", "")

          reply send_chat_action "upload_photo"

          caption = "Artist: #{artist}\n\nvia https://danbooru.donmai.us/posts/#{post_id}"

          reply send_photo file, [caption: caption]
          File.rm file
      end
    end

    command ["safe", "sfw"] do
      try do
        [_ | tag] = message.text |> String.split
        dan = danbooru(tag |> List.first, "rating:s")

        case dan do
          {artist, post_id, file} ->
            caption = "Artist: #{artist}\n\nvia https://danbooru.donmai.us/posts/#{post_id}"

            reply send_chat_action "upload_photo"

            reply send_photo file, [caption: caption]
            File.rm file
          message -> reply send_message message
        end
      rescue
        _ ->
          {artist, post_id, file} = danbooru("order:rank", "rating:s")

          reply send_chat_action "upload_photo"

          caption = "Artist: #{artist}\n\nvia https://danbooru.donmai.us/posts/#{post_id}"

          reply send_photo file, [caption: caption]
          File.rm file
      end
    end

    command ["lewd", "nsfw"] do
      try do
        [_ | tag] = message.text |> String.split
        dan = danbooru(tag |> List.first, Enum.random(["rating:q", "rating:e"]))

        case dan do
          {artist, post_id, file} ->
            caption = "Artist: #{artist}\n\nvia https://danbooru.donmai.us/posts/#{post_id}"

            reply send_chat_action "upload_photo"

            reply send_photo file, [caption: caption]
            File.rm file
          message -> reply send_message message
        end
      rescue
        _ ->
          {artist, post_id, file} = danbooru("order:rank", Enum.random(["rating:q", "rating:e"]))

          reply send_chat_action "upload_photo"

          caption = "Artist: #{artist}\n\nvia https://danbooru.donmai.us/posts/#{post_id}"

          reply send_photo file, [caption: caption]
          File.rm file
      end
    end

    command "tts" do
      try do
        [_ | message] = String.split(message.text)
        [first_word | rest] = message
        voice_input = first_word |> String.split(":")

        {voice, input} =
          cond do
            length(voice_input) == 2 ->
              [_ | voice] = voice_input
              {hd(voice), rest}
            true -> {"Will", message}
          end

        text = input |> Enum.join(" ")

        reply send_chat_action "record_audio"

        url = "http://www.acapela-group.com/demo-tts/DemoHTML5Form_V2.php"
        body = [MyLanguages: "sonid10", MySelectedVoice: voice, MyTextForTTS: text, t: "1", SendToVaaS: ""]
        head = %{"User-Agent" => "Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US) AppleWebKit/525.13 (KHTML, like Gecko) Chrome/0.2.149.29 Safari/525.13", "Content-type" => "application/x-www-form-urlencoded"}

        request = HTTPoison.post!(url, {:form, body}, head)
        %{"mp3" => file_url} = Regex.named_captures(~r/(?<mp3>((http:\/\/)?(www)?[-a-zA-Z0-9@:%_\+.~#?\/=]+\.mp3))/, request.body)

        file = download(file_url)

        reply send_voice file
        File.rm file
      rescue
        _ -> reply send_message "What?"
      end
    end

    command "projection", do: reply send_message "Psychological projection is a theory in psychology in which humans defend themselves against their own unpleasant impulses by denying their existence while attributing them to others. For example, a person who is rude may constantly accuse other people of being rude. It can take the form of blame shifting."

    match ["hello", "hi", "hey", "sup"] do
      replies = ["sup loser", "yo", "ay", "go away", "hi", "wassup"]
      if one_to(25) do
        reply send_message Enum.random(replies)
      end
    end

    match ["ty kuma", "thanks kuma", "thank you kuma"] do
      replies = ["np", "don't mention it", "anytime", "sure thing", "ye whateva"]
      reply send_message Enum.random(replies)
    end

    match ["same", "Same", "SAME"] do
      if one_to(25) do
        reply send_message "same"
      end
    end

    command "uid" do
      uid = message.from.id

      cond do
        message.chat.type == "private" ->
          reply send_message "Your user ID is `#{uid}`.",
          [parse_mode: "Markdown"]
        true ->
          reply send_message "#{name}'s user ID is `#{uid}`.",
          [parse_mode: "Markdown"]
      end
    end

    command "coins" do
      coins = query_data("bank", message.from.id)

      coins = case coins do
        nil -> 0
        coins -> coins
      end

      cond do
        message.chat.type == "private" ->
          reply send_message "You have #{coins} coins."
        true ->
          reply send_message "#{name} has #{coins} coins."
      end
    end

    command "transfer" do
      try do
        [_ | query] = String.split(message.text)
        [uid, amount | _] = query

        uid = uid |> String.to_integer
        amount = amount |> String.to_integer

        cond do
          uid == message.from.id -> reply send_message "You can't send money to yourself."
          amount <= 0 -> reply send_message "You have to send more than that."
          true ->
            receiver = query_data("users", uid)
            sender = query_data("users", message.from.id)

            case receiver do
              nil -> reply send_message "That user doesn't exist in the bank."
              receiver ->
                sender_coins = query_data("bank", message.from.id)

                cond do
                  sender_coins < amount -> reply send_message "You do not have enough coins."
                  true ->
                    receiver_coins = query_data("bank", uid)
                    store_data("bank", message.from.id, sender_coins - amount)
                    store_data("bank", uid, receiver_coins + amount)

                    reply send_message "You sent #{amount} to #{receiver}.\nYou now have #{sender_coins - amount} coins."
                    send_message uid, "You received #{amount} from #{sender}!\nYou now have #{receiver_coins + amount} coins."
                end
          end
        end
      rescue
        _ -> reply send_message "That didn't work, make sure you're using the following format:\n\n`/transfer <user_id> <amount>`", [parse_mode: "Markdown"]
      end
    end

    command ["score", "leaderboard"] do
      case message.chat.type do
        "private" ->
          reply send_message "What? Okay, sure. You're #1. Good job!"
        _ ->
          members_count = reply get_chat_members_count

          cond do
            members_count < 3 -> reply send_message "You should have 3 or more members in this chat to check scores."
            true ->
              reply send_chat_action "typing"
              members = query_data("chats", message.chat.id)

              member_coins = for member <- members do
                name = query_data("users", member)
                coins = query_data("bank", member)

                coins = case coins do
                  nil -> 0
                  coins -> coins
                end

                %{coins: coins, name: name}
              end

              member_coins = member_coins |> Enum.sort |> Enum.reverse

              reply send_message "1: *#{Enum.at(member_coins,0).name}* (#{Enum.at(member_coins,0).coins})\n2: *#{Enum.at(member_coins,1).name}* (#{Enum.at(member_coins,1).coins})\n3: *#{Enum.at(member_coins,2).name}* (#{Enum.at(member_coins,2).coins})", [parse_mode: "Markdown"]
          end
      end
    end

    unless message.chat.type == "private" do
      coins = query_data("bank", message.from.id)

      case coins do
        nil -> store_data("bank", message.from.id, 1)
        coins -> store_data("bank", message.from.id, coins + 1)
      end
    end
  end
end
