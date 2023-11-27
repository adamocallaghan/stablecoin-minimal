-include .env

deploy-collateral-token:
	forge create src/CollateralToken.sol:CollateralToken --private-key $(DEPLOYER_PRIVATE_KEY) --constructor-args $(COLLATERAL_TOKEN_OWNER)

mint-collateral-tokens-to-deployer:
	cast send $(COLLATERAL_TOKEN_ADDRESS) "mint(address,uint256)" $(COLLATERAL_TOKEN_OWNER) 500000 --private-key $(DEPLOYER_PRIVATE_KEY)

check-deployer-collateral-tokens-balance:
	cast call $(COLLATERAL_TOKEN_ADDRESS) "balanceOf(address)" $(COLLATERAL_TOKEN_OWNER)

deploy-stablecoin-engine:
	forge create src/StablecoinEngine.sol:StablecoinEngine --private-key $(DEPLOYER_PRIVATE_KEY) --constructor-args $(COLLATERAL_TOKEN_ADDRESS) $(DUMMY_ORACLE)

approve-engine-to-spend-collateral-tokens:
	cast send $(COLLATERAL_TOKEN_ADDRESS) "approve(address,uint256)" $(STABLECOIN_ENGINE_ADDRESS) 399000 --private-key $(DEPLOYER_PRIVATE_KEY)

depositTokensAndMintStablecoin:
	cast send $(STABLECOIN_ENGINE_ADDRESS) "depositCollateralAndMintStablecoin(address,uint256,uint256)" $(COLLATERAL_TOKEN_ADDRESS) 98000 32000 --private-key $(DEPLOYER_PRIVATE_KEY)

check-collateral-in-engine:
	cast call $(STABLECOIN_ENGINE_ADDRESS) "s_userToAmountDeposited(address)(address)" $(DEPLOYER_PUBLIC_ADDRESS)

check-stablecoins-minted-to-depositer:
	cast call $(STABLECOIN_ENGINE_ADDRESS) "balanceOf(address)" $(DEPLOYER_PUBLIC_ADDRESS)

fork-mainnet:
	anvil --fork-url $(INFURA_RPC_URL)