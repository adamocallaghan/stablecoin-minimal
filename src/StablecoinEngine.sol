// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/interfaces/AggregatorV3Interface.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

error Error__CollateralTokenTransferInFailed();
error Error__HealthFactorBroken();
error Error__HealthFactorBrokenOnRedeem();
error Error__StablecoinMintFailed();
error Error__StablecoinTransferInFailed();
error Error__CollateralTransferOutUnsuccessful();
error Error__UserIsNotLiquidatable();
error Error__UserHealthFactorShouldBeHigherAfterLiquidation();

contract StablecoinEngine is ERC20 {
    address public owner;

    address public s_collateralToken;
    address public s_collateralTokenPriceFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    mapping(address user => uint256 amountDeposited) public s_userToAmountDeposited;
    mapping(address user => uint256 amountStablecoinMinted) public s_userToAmountStablecoinMinted;

    uint256 public LIQUIDATION_THRESHOLD = 50;
    uint256 public LIQUIDATION_BONUS = 10;
    uint256 public MIN_HEALTH_FACTOR = 1e18;

    event CollateralDeposited(address indexed user, uint256 indexed amount);

    constructor(address _collateralToken) ERC20("StableX", "USDX") {
        s_collateralToken = _collateralToken;
    }

    function depositCollateralAndMintStablecoin(uint256 amountCollateral, uint256 amountStablecoinToMint) public {
        // ##########################
        // ### DEPOSIT COLLATERAL ###
        // ##########################

        // update balances
        s_userToAmountDeposited[msg.sender] += amountCollateral;
        // emit event
        emit CollateralDeposited(msg.sender, amountCollateral);
        // transfer collateral tokens
        bool success = IERC20(s_collateralToken).transferFrom(msg.sender, address(this), amountCollateral);
        // revert if inbound collateral token transfer unsuccessful
        if (!success) {
            revert Error__CollateralTokenTransferInFailed();
        }

        // #######################
        // ### MINT STABLECOIN ###
        // #######################

        // update balances
        s_userToAmountStablecoinMinted[msg.sender] += amountStablecoinToMint;
        // revert if health factor is broken
        uint256 userHealthFactor = healthFactor(msg.sender);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert Error__HealthFactorBroken();
        }
        // mint stablecoin to user
        _mint(msg.sender, amountStablecoinToMint);
    }

    function burnStablecoinAndRedeemCollateral(uint256 amountCollateral, uint256 amountStablecoinToBurn) public {
        // #######################
        // ### BURN STABLECOIN ###
        // #######################

        // update balances
        s_userToAmountStablecoinMinted[msg.sender] -= amountStablecoinToBurn;

        // burn, baby, burn!
        _burn(msg.sender, amountStablecoinToBurn);

        // revert if health factor is broken
        uint256 userHealthFactorAfterBurn = healthFactor(msg.sender);
        if (userHealthFactorAfterBurn < MIN_HEALTH_FACTOR) {
            revert Error__HealthFactorBrokenOnRedeem();
        }

        // #########################
        // ### REDEEM COLLATERAL ###
        // #########################

        // remove amount of collateral being redeemed from user's balance
        s_userToAmountDeposited[msg.sender] -= amountCollateral;

        // transfer collateral from this contract to the user
        bool successfulCollateralTransfer = IERC20(s_collateralToken).transfer(msg.sender, amountCollateral);
        if (!successfulCollateralTransfer) {
            revert Error__CollateralTransferOutUnsuccessful();
        }

        // revert if health factor is broken
        uint256 userHealthFactorAfterRedeem = healthFactor(msg.sender);
        if (userHealthFactorAfterRedeem < MIN_HEALTH_FACTOR) {
            revert Error__HealthFactorBrokenOnRedeem();
        }
    }

    function getAccountCollateralValue(address user) public view returns (uint256) {
        uint256 amount = s_userToAmountDeposited[user]; // amount of collateral user has
        // // uint256 totalCollateralValueInUsd = getUsdValue(amount);

        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_collateralTokenPriceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData(); // call oracle to get ETH/USD price

        // calculate and return collateral value in USD
        uint256 totalCollateralValueInUsd = ((uint256(price) * 1e10) * amount) / 1e18;
        // uint256 totalCollateralValueInUsd = 2000;
        return totalCollateralValueInUsd;
    }

    function healthFactor(address user) public view returns (uint256) {
        uint256 totalStablecoinMintedByUser = s_userToAmountStablecoinMinted[user];
        uint256 collateralValueInUsd = getAccountCollateralValue(user);
        // uint256 collateralValueInUsd = 2000;
        if (totalStablecoinMintedByUser == 0) {
            // no stables minted means they're good to go
            return 100e18;
        }
        if (totalStablecoinMintedByUser > 0) {
            // calculate health factor
            uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / 100;
            return (collateralAdjustedForThreshold * 1e18) / totalStablecoinMintedByUser;
        }
    }

    function liquidate(address user, uint256 debtToCover) external {
        // check if requested user is liquidatable
        uint256 startingUserHealthFactor = healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert Error__UserIsNotLiquidatable();
        }

        // call oracle to get Eth price
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_collateralTokenPriceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData(); // call oracle to get ETH/USD price

        // get the amount of token from the debtToCover
        uint256 tokenAmountFromDebtToCover = (uint256(price) * 1e10 * 1e18) / debtToCover;

        // calculate liquidation bonus
        uint256 bonusCollateral = (tokenAmountFromDebtToCover * LIQUIDATION_BONUS) / 100;

        // amount of collateral to be taken
        uint256 amountCollateral = (tokenAmountFromDebtToCover + bonusCollateral);

        // remove amount of collateral being redeemed from the liquidated user's balance
        s_userToAmountDeposited[user] -= amountCollateral;

        // transfer collateral from this contract to the liquidator
        bool successfulCollateralTransfer = IERC20(s_collateralToken).transfer(msg.sender, amountCollateral);
        if (!successfulCollateralTransfer) {
            revert Error__CollateralTransferOutUnsuccessful();
        }

        // update liquidated user's balances
        s_userToAmountStablecoinMinted[user] -= debtToCover;

        // liquidator burns their stables (pays off debt) to grab the collateral
        _burn(msg.sender, debtToCover);

        uint256 endingUserHealthFactor = healthFactor(user);
        if (startingUserHealthFactor > endingUserHealthFactor) {
            revert Error__UserHealthFactorShouldBeHigherAfterLiquidation();
        }
    }
}
