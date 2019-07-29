defmodule KumaBot.Unsync do
  use GenServer
  import KumaBot.Util

  def start_link(tags \\ ["-rating:s"]) do
    GenServer.start_link(__MODULE__, {:ok, tags})
  end

  def get_danbooru_listings(tags, page) do
    request_tags = tags |> Enum.take(6) |> Enum.join("+")
    request_url = "https://danbooru.donmai.us/posts.json?page=#{page}&limit=200&tags=#{request_tags}"
    request_auth = [hackney: [basic_auth: {
      Application.get_env(:kuma_bot, :danbooru_login),
      Application.get_env(:kuma_bot, :danbooru_api_key)
    }]]

    request = request_url |> HTTPoison.get!(%{}, request_auth)
    results = Poison.Parser.parse!((request.body), keys: :atoms)
  end

  def init({:ok, tags}) do
    results = get_danbooru_listings(tags, 1) |> Enum.shuffle

    if results == [] do
      chat_id = Application.get_env(:kuma_bot, :rekcoa)

      Nadia.send_message chat_id, "Nothing found!"

      KumaBot.Util.store_data(:unsync, "pid", 0)
      {:stop, {:shutdown, "Nothing found!"}, []}
    else
      send self, {:update, tags, 1, 0, results}
    end

    {:ok, []}
  end

  def handle_info({:update, tags, page, post, results}, state) do
    blacklist = Application.get_env(:kuma_bot, :blacklist)
    result = Enum.at(results, post)

    cond do
      is_image?(result.file_url) == true
      && (String.split(result.tag_string_general) -- blacklist) == String.split(result.tag_string_general) 
      && result.is_deleted == false ->
        image = if URI.parse(result.file_url).host do
          result.file_url
        else
          "http://danbooru.donmai.us#{result.file_url}"
        end
  
        post_id = Integer.to_string(result.id)
        artist =
          result.tag_string_artist
          |> String.split("_")
          |> Enum.join(" ")
        character_tags = result.tag_string_character |> String.split
        copyright_tags = result.tag_string_copyright |> String.split
  
        character_tags_cleaned = for tag <- character_tags do
          tag
          |> String.split("_(")
          |> List.first
          |> titlecase("_")
        end |> Enum.uniq
  
        copyright = 
          copyright_tags 
          |> List.first
          |> titlecase("_")
  
        characters = case length(character_tags_cleaned) do
          1 -> character_tags_cleaned |> List.first
          2 -> character_tags_cleaned |> Enum.join(" and ")
          _ -> [
                character_tags_cleaned
                |> Enum.drop(-1)
                |> Enum.join(", "), 
                List.last(character_tags_cleaned)
              ]
              |> Enum.join(", and ")
        end
  
        caption_string = case characters do
          ", and " -> "#{copyright}"
          _ -> "#{characters} - #{copyright}"
        end
  
        caption = """
        *#{caption_string}*
        [Drawn by #{artist}](https://danbooru.donmai.us/posts/#{post_id})
        """
        chat_id = Application.get_env(:kuma_bot, :rekcoa)
    
        Nadia.send_chat_action chat_id, "upload_photo"
        Nadia.send_photo chat_id, image, [caption: caption, parse_mode: "Markdown"]
    
        File.rm image

        cond do
          post + 1 >= length(results) ->
            page = page + 1
            results = get_danbooru_listings(tags, page) |> Enum.shuffle

            if results == [] do
              chat_id = Application.get_env(:kuma_bot, :rekcoa)

              Nadia.send_message chat_id, "No more entries!"

              KumaBot.Util.store_data(:unsync, "pid", 0)
              {:stop, {:shutdown, "No more entries!"}, state}
            else
              :erlang.send_after(10000, self, {:update, tags, page, 0, results})
            end            
          true ->
            :erlang.send_after(10000, self, {:update, tags, page, post + 1, results})
        end
      true ->
        cond do
          post + 1 >= length(results) ->
            page = page + 1
            results = get_danbooru_listings(tags, page) |> Enum.shuffle

            if results == [] do
              chat_id = Application.get_env(:kuma_bot, :rekcoa)

              Nadia.send_message chat_id, "No more entries!"
              
              KumaBot.Util.store_data(:unsync, "pid", 0)
              {:stop, {:shutdown, "No more entries!"}, state}
            else
              send self, {:update, tags, page, 0, results}  
            end                      
          true ->
            send self, {:update, tags, page, post + 1, results}
        end
    end

    {:noreply, state}
  end
end