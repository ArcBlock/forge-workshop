defmodule AbtDidWorkshopWeb.AuthController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.AppState
  alias AbtDidWorkshop.UserDb
  alias AbtDidWorkshop.Util

  def request_auth(conn, %{"userDid" => did}) do
    user = UserDb.get(did)

    if user != nil and filled_all_claims?(user) do
      json(conn, gen_and_sign())
    else
      json(conn, request_reg())
    end
  end

  def request_auth(conn, _),
    do: send_resp(conn, 400, "The request must contain valid DID.")

  def response_auth(conn, %{"userPk" => pk, "userInfo" => user_info}) do
    pk_bin = Util.str_to_bin(pk)

    if false === AbtDid.Signer.verify(user_info, pk_bin) do
      send_resp(conn, 422, "The signature of the user info does not match the public key.")
    else
      user_info
      |> Util.get_body()
      |> do_response_auth(pk, conn)
    end
  end

  def response_auth(conn, _),
    do: send_resp(conn, 400, "The request must contain valid public key and user info.")

  defp do_response_auth(user_info, pk, conn) do
    user_did = Map.get(user_info, "iss")
    user = UserDb.get(user_did)

    if user != nil and Map.get(user_info, "requestedClaims", []) == [] do
      case filled_all_claims?(user) do
        true ->
          json(conn, gen_and_sign())

        false ->
          json(conn, request_reg())
      end
    else
      do_response_auth_add(conn, pk, user_info)
    end
  end

  defp do_response_auth_add(conn, pk, user_info) do
    case match_claims?(user_info) do
      true ->
        add_user(pk, user_info)
        json(conn, gen_and_sign())

      false ->
        send_resp(conn, 422, "Authentication failed.")
    end
  end

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
    expected = AppState.get().profile
    actual = get_profile(body)
    check_profile(expected, actual)
  end

  defp get_profile(body) do
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

  defp check_profile_item(claim_id, actual) do
    case actual[claim_id] do
      nil -> false
      "" -> false
      _ -> true
    end
  end

  defp request_reg() do
    claims = gen_claims()
    callback = Util.get_callback()

    gen_and_sign(%{
      url: callback,
      action: "responseAuth",
      requestedClaims: claims,
      appInfo: %{
        "name" => "ABT DID Workshop",
        "description" =>
          "A simple workshop for developers to quickly develop, design and debug the DID flow.",
        "logo" => "https://example-application/logo"
      }
    })
  end

  defp gen_and_sign(extra \\ %{}) do
    state = AppState.get()
    did_type = AbtDid.get_did_type(state.did)
    auth_info = AbtDid.Signer.gen_and_sign(did_type, state.sk, extra)

    %{
      appPk: state.pk |> Multibase.encode!(:base58_btc),
      authInfo: auth_info
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
            items: profile
          }
      end

    agreement_claims =
      case agreements do
        [] -> []
        _ -> Enum.map(agreements, &get_agreement/1)
      end

    [profile_claim] ++ agreement_claims
  end

  defp get_agreement(_) do
    %{}
  end

  defp filled_all_claims?(user) do
    app_sate = AppState.get()
    Enum.all?(app_sate.profile, fn claim_id -> Map.get(user, claim_id) != nil end)
  end
end
