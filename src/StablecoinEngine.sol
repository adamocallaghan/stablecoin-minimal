// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Stablecoin} from "./Stablecoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/interfaces/AggregatorV3Interface.sol";

error Error__IncorrectCollateralToken();
error Error__CollateralTokenTransferInFailed();
error Error__HealthFactorBroken();
error Error__StablecoinMintFailed();
error Error__StablecoinTransferInFailed();
error Error__CollateralTransferOurUnsuccessful();

contract StablecoinEngine {
    address public owner;
    Stablecoin public stablecoin;

    address public s_collateralToken;
    address public s_collateralTokenPriceFeed;

    mapping(address user => uint256 amountDeposited) public s_userToAmountDeposited;
    mapping(address user => uint256 amountStablecoinMinted) public s_userToAmountStablecoinMinted;

    uint256 public LIQUIDATION_THRESHOLD = 50;
    uint256 public LIQUIDATION_BONUS = 10;
    uint256 public MIN_HEALTH_FACTOR = 1e18;

    event CollateralDeposited(address indexed user, uint256 indexed amount);

    constructor(address _collateralToken, address _collateralTokenPriceFeed, address _stablecoin) {
        s_collateralToken = _collateralToken;
        s_collateralTokenPriceFeed = _collateralTokenPriceFeed;
        stablecoin = Stablecoin(_stablecoin);
    }

    function depositCollateralAndMintStablecoin(
        address collateralTokenAddress,
        uint256 amountCollateral,
        uint256 amountStablecoinToMint
    ) public {
        // ##########################
        // ### DEPOSIT COLLATERAL ###
        // ##########################

        // check that collateral token is correct one
        if (collateralTokenAddress != s_collateralToken) {
            revert Error__IncorrectCollateralToken();
        }

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
        stablecoin.mint(msg.sender, amountStablecoinToMint);
    }

    function burnStablecoinAndRedeemCollateral(uint256 amountCollateral, uint256 amountStablecoinToBurn) public {
        // #######################
        // ### BURN STABLECOIN ###
        // #######################

        // update balances
        s_userToAmountStablecoinMinted[msg.sender] -= amountStablecoinToBurn;

        // transfer stablecoins to this contract
        bool success = stablecoin.transferFrom(msg.sender, address(this), amountStablecoinToBurn);
        if (!success) {
            revert Error__StablecoinTransferInFailed();
        }
        // burn, baby, burn!
        stablecoin.burn(amountStablecoinToBurn);

        // revert if health factor is broken
        uint256 userHealthFactorAfterBurn = healthFactor(msg.sender);
        if (userHealthFactorAfterBurn < MIN_HEALTH_FACTOR) {
            revert Error__HealthFactorBroken();
        }

        // #########################
        // ### REDEEM COLLATERAL ###
        // #########################

        // remove amount of collateral being redeemed from user's balance
        s_userToAmountDeposited[msg.sender] -= amountCollateral;

        // transfer collateral from this contract to the user
        bool successfulCollateralTransfer = IERC20(s_collateralToken).transfer(msg.sender, amountCollateral);
        if (!successfulCollateralTransfer) {
            revert Error__CollateralTransferOurUnsuccessful();
        }

        // revert if health factor is broken
        uint256 userHealthFactorAfterRedeem = healthFactor(msg.sender);
        if (userHealthFactorAfterRedeem < MIN_HEALTH_FACTOR) {
            revert Error__HealthFactorBroken();
        }
    }

    function getAccountCollateralValue(address user) public view returns (uint256) {
        uint256 amount = s_userToAmountDeposited[user]; // amount of collateral user has
        // uint256 totalCollateralValueInUsd = getUsdValue(amount);

        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_collateralTokenPriceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData(); // call oracle to get ETH/USD price

        // calculate and return collateral value in USD
        // uint256 totalCollateralValueInUsd = ((uint256(price) * 1e10) * amount) / 1e18;
        uint256 totalCollateralValueInUsd = 2000;
        return totalCollateralValueInUsd;
    }

    function healthFactor(address user) public view returns (uint256) {
        uint256 totalStablecoinMintedByUser = s_userToAmountStablecoinMinted[msg.sender];
        uint256 collateralValueInUsd = getAccountCollateralValue(msg.sender);
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

    /*
    function getUsdValue(uint256 collateralAmount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_collateralTokenPriceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * 1e10) * collateralAmount) / 1e18;
    }
    */
}
