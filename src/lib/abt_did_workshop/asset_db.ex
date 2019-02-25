defmodule AbtDidWorkshop.AssetDb do
  # @folder "abt_did_workshop"
  @json "assets.json"

  def create_file do
    home = System.user_home!()

    if File.exists?(Path.join(home, @json)) == false do
      File.touch!(Path.join(home, @json))
    end
  end

  def store(assets) do
    home = System.user_home!()
    path = Path.join(home, @json)

    create_file()

    existing =
      case File.read(path) do
        {:error, _} -> []
        {:ok, content} -> Jason.decode!(content)
      end

    new = Jason.encode!(existing ++ assets)

    File.write!(path, new)
  end
end
