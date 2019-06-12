defmodule ForgeWorkshopWeb.Router do
  use ForgeWorkshopWeb, :router

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

  scope "/", ForgeWorkshopWeb do
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

    get("/custodian", CustodianController, :index)
    get("/custodian/:address/edit", CustodianController, :edit)
    get("/custodian/:address/tethers", CustodianController, :get)
    get("/custodian/new", CustodianController, :new)
    post("/custodian/:address/verify", CustodianController, :verify)
    post("/custodian/:address/approve", CustodianController, :approve)
    post("/custodian", CustodianController, :create)
    put("/custodian", CustodianController, :update)

    get("/withdrawer", WithdrawerController, :index)
    post("/withdrawer/:hash", WithdrawerController, :withdraw)

    resources("/demo", DemoController)
    resources("/tx", TxController)
    put("/tx", TxController, :create)
  end

  scope "/api", ForgeWorkshopWeb do
    pipe_through(:api)
    get("/auth", AuthController, :request_auth)
    post("/auth", AuthController, :response_auth)
    get("/agreement/:id", AgreementController, :get)

    post("/wallet/recover", WalletController, :create_wallet)
    get("/wallet/:addr", WalletController, :wallet_state)

    get("/workflow/:id", WorkflowController, :request)
    post("/workflow/account/:id", WorkflowController, :response_account)
    post("/workflow/asset/:id", WorkflowController, :response_asset)
    post("/workflow/sig/:id", WorkflowController, :response_sig)
    post("/workflow/multisig/:id", WorkflowController, :response_multi_sig)
    post("/workflow/deposit/:id", WorkflowController, :response_deposit_value)
    post("/workflow/tether/:id", WorkflowController, :response_tether)
  end
end