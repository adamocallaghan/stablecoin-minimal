-include .env

deploy-collateral-token:
	forge create src/CollateralToken.sol:CollateralToken --private-key $(DEPLOYER_PRIVATE_KEY) --constructor-args $(COLLATERAL_TOKEN_OWNER)

mint-collateral-tokens-to-deployer:
	cast send $(COLLATERAL_TOKEN_ADDRESS) "mint(address,uint256)" $(COLLATERAL_TOKEN_OWNER) 500000 --private-key $(DEPLOYER_PRIVATE_KEY)

check-deployer-collateral-tokens-balance:
	cast call $(COLLATERAL_TOKEN_ADDRESS) "balanceOf(address)(uint)" $(COLLATERAL_TOKEN_OWNER)

deploy-stablecoin-engine:
	forge create src/StablecoinEngine.sol:StablecoinEngine --private-key $(DEPLOYER_PRIVATE_KEY) --constructor-args $(COLLATERAL_TOKEN_ADDRESS)

approve-engine-to-spend-collateral-tokens:
	cast send $(COLLATERAL_TOKEN_ADDRESS) "approve(address,uint256)" $(STABLECOIN_ENGINE_ADDRESS) 399000 --private-key $(DEPLOYER_PRIVATE_KEY)

depositTokensAndMintStablecoin:
	cast send $(STABLECOIN_ENGINE_ADDRESS) "depositCollateralAndMintStablecoin(uint256,uint256)" 3 9000 --private-key $(DEPLOYER_PRIVATE_KEY)

check-collateral-in-engine:
	cast call $(STABLECOIN_ENGINE_ADDRESS) "s_userToAmountDeposited(address)(uint)" $(DEPLOYER_PUBLIC_ADDRESS)

check-stablecoins-minted-to-depositer:
	cast call $(STABLECOIN_ENGINE_ADDRESS) "balanceOf(address)(uint)" $(DEPLOYER_PUBLIC_ADDRESS)

fork-mainnet:
	anvil --fork-url $(INFURA_RPC_URL)

mint-collateral-tokens-to-liquidator:
	cast send $(COLLATERAL_TOKEN_ADDRESS) "mint(address,uint256)" $(LIQUIDATOR_PUBLIC_ADDRESS) 123456 --private-key $(DEPLOYER_PRIVATE_KEY)

approve-engine-to-spend-collateral-tokens_liquidator:
	cast send $(COLLATERAL_TOKEN_ADDRESS) "approve(address,uint256)" $(STABLECOIN_ENGINE_ADDRESS) 123000 --private-key $(LIQUIDATOR_PRIVATE_KEY)

depositTokensAndMintStablecoin_liquidator:
	cast send $(STABLECOIN_ENGINE_ADDRESS) "depositCollateralAndMintStablecoin(uint256,uint256)" 15 21000 --private-key $(LIQUIDATOR_PRIVATE_KEY)

liquidate:
	cast send $(STABLECOIN_ENGINE_ADDRESS) "liquidate(address,uint256)" $(DEPLOYER_PUBLIC_ADDRESS) 10 --private-key $(LIQUIDATOR_PRIVATE_KEY)