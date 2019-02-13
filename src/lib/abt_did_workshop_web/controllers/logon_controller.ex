defmodule AbtDidWorkshopWeb.LogonController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.AppState
  alias AbtDidWorkshop.UserDb
  alias AbtDidWorkshop.Util

  def request(conn, %{"user_did" => did}) do
    case UserDb.get(did) do
      nil -> json(conn, request_reg())
      _ -> json(conn, gen_and_sign())
    end
  end

  def request(conn, _),
    do: send_resp(conn, 400, "The request must contain valid DID.")

  def auth(conn, %{"user_pk" => pk, "challenge" => challenge}) do
    pk_bin = hex_to_bin(pk)

    if false === AbtDid.Jwt.verify(challenge, pk_bin) do
      send_resp(conn, 422, "The signature of the challenge does not match the public key.")
    else
      body =
        challenge
        |> String.split(".")
        |> Enum.at(1)
        |> Base.url_decode64!(padding: false)
        |> Jason.decode!()

      case match_claims?(body) do
        true ->
          add_user(pk, body)
          json(conn, gen_and_sign())

        false ->
          send_resp(conn, 422, "Authentication failed.")
      end
    end
  end

  def auth(conn, _),
    do: send_resp(conn, 400, "The request must contain valid public key and challenge.")

  defp add_user(pk, body) do
    user = %{
      did: body["iss"],
      pk: pk
    }

    profile =
      body
      |> get_profile()
      |> Map.delete("type")
      |> Map.delete("meta")

    UserDb.add(Map.merge(user, profile))
  end

  defp match_claims?(body) do
    expected = AppState.get().profile |> IO.inspect(label: "%% expected %%")
    actual = get_profile(body) |> IO.inspect(label: "%% actual %%")
    check_profile(expected, actual)
  end

  defp get_profile(body) do
    IO.inspect(binding())

    body
    |> Map.get("requestedClaims", [])
    |> Enum.filter(fn claim -> claim["type"] == "profile" end)
    |> List.first() || %{}
  end

  defp check_profile([], _), do: true

  defp check_profile(expected, actual) do
    Enum.reduce(expected, true, fn claim, acc -> acc and check_profile_item(claim, actual) end)
  end

  defp check_profile_item(_, nil), do: false

  defp check_profile_item("fullName", actual) do
    case actual["fullName"] do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  defp check_profile_item("birthday", actual) do
    case actual["birthday"] do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  defp check_profile_item("ssn", actual) do
    case actual["ssn"] do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  defp request_reg() do
    claims = gen_claims()
    callback = Util.get_callback()
    gen_and_sign(%{responseAuth: callback, requestedClaims: claims})
  end

  defp gen_and_sign(extra \\ %{}) do
    state = AppState.get()
    did_type = AbtDid.get_did_type(state.did)
    challenge = AbtDid.Jwt.gen_and_sign(did_type, state.sk, extra)

    %{
      app_pk: state.pk |> Base.encode16(case: :lower),
      challenge: challenge
    }
  end

  defp gen_claims() do
    profile = AppState.get().profile
    agreements = AppState.get().agreements

    profile_claim =
      case profile do
        [] ->
          nil

        profile ->
          %{
            type: "profile",
            meta: %{
              description: "Please provide your profile information."
            },
            parameters: profile
          }
      end

    agreement_claims =
      case agreements do
        [] -> []
        _ -> Enum.map(agreements, &get_agreement/1)
      end

    [profile_claim] ++ agreement_claims
  end

  def get_agreement(_) do
    %{}
  end

  defp hex_to_bin("0x" <> hex), do: hex_to_bin(hex)
  defp hex_to_bin(hex), do: Base.decode16!(hex, case: :mixed)
end
