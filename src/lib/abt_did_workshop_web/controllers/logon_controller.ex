defmodule AbtDidWorkshopWeb.LogonController do
  use AbtDidWorkshopWeb, :controller

  alias AbtDidWorkshop.AppState
  alias AbtDidWorkshop.UserDb
  alias AbtDidWorkshop.Util

  def logon(conn, %{"user_pk" => pk, "challenge" => challenge}) do
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

      # did = body["iss"]
      # iat = body["iat"]
      # nbf = body["nbf"]
      case UserDb.get(body["iss"]) do
        nil -> json(conn, request_reg())
        _ -> json(conn, gen_and_sign())
      end
    end
  end

  def logon(conn, _),
    do: send_resp(conn, 400, "The request must contain valid public key and challenge.")

  defp request_reg() do
    state = AppState.get()
    claims = gen_claims(state.claims)
    callback = Util.get_callback()
    gen_and_sign(%{callback: callback, requested: claims})
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

  defp gen_claims(claims) do
    claims
    |> Enum.map(fn "claim_" <> claim -> get_claim(claim) end)
  end

  defp get_claim("full_name"),
    do: %{
      id: "FullName",
      tile: "Full Name (with suffix)",
      type: "string"
    }

  defp get_claim("ssn"),
    do: %{
      id: "SSN",
      title: "Social Security No.",
      type: "string",
      format: "###-##-####"
    }

  defp get_claim("birthday"),
    do: %{
      id: "birthday",
      title: "Birthday (must be over 21)",
      type: "date"
    }

  defp hex_to_bin("0x" <> hex), do: hex_to_bin(hex)
  defp hex_to_bin(hex), do: Base.decode16!(hex, case: :mixed)
end
