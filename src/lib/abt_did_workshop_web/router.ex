defmodule AbtDidWorkshopWeb.Router do
  use AbtDidWorkshopWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", AbtDidWorkshopWeb do
    pipe_through(:browser)
    get("/", DidController, :index)
    post("/did", DidController, :create_did)
    get("/did", DidController, :show)
    post("/did/app", DidController, :upsert_app_state)
    post("/did/claims", DidController, :upsert_claims)
    get("/did/claims", DidController, :reselect_claims)
    post("/did/start_over", DidController, :start_over)

    get("/wallet", WalletController, :index)
    get("/wallet/auth", WalletController, :request_auth)
    post("/wallet/auth", WalletController, :response_auth)

    resources("/demo", DemoController)
    resources("/tx", TxController)
    put("/tx", TxController, :create)
  end

  scope "/api", AbtDidWorkshopWeb do
    pipe_through(:api)
    get("/auth", AuthController, :request_auth)
    post("/auth", AuthController, :response_auth)
    get("/agreement/:id", AgreementController, :get)

    post("/wallet/recover", WalletController, :recover_wallet)

    # Util apis for event chains
    post("/requireSig", ApiController, :require_sig)
    post("/requireMultiSig", ApiController, :require_multi_sig)
    post("/requireAsset", ApiController, :require_asset)

    get("/transaction/:id", TransactionController, :request)
    post("/transaction/:id", TransactionController, :response)

    get("/state/account/:addr", StateController, :account)
  end
end
