// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

error Error__IncorrectCollateralToken();

contract StablecoingEngine {
    address public owner;
    address public stablecoin;

    address public s_collateralToken;
    address public s_collateralTokenPriceFeed;

    mapping(address user => uint256 amountDeposited) public s_userToAmountDeposited;
    mapping(address user => uint256 amountStablecoinMinted) public s_userToAmountStablecoinMinted;

    uint256 public liquidation_threshold;
    uint256 public liquidation_bonus;
    uint256 public min_health_factor;

    event CollateralDeposited(address indexed user, uint256 indexed amount);

    constructor(address _collateralToken, address _collateralTokenPriceFeed, address _stablecoin) {
        s_collateralToken = _collateralToken;
        s_collateralTokenPriceFeed = _collateralTokenPriceFeed;
        stablecoin = _stablecoin;
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

        // update balances + transfer collateral tokens
        s_userToAmountDeposited[msg.sender] += amountCollateral;
        emit CollateralDeposited(msg.sender, amountCollateral);
        bool success = IERC20(collateralTokenAddress).transferFrom(msg.sender, address(this), amountCollateral);

        // ### MINT STABLECOIN ###
    }

    function burnStablecoinAndRedeemCollateral() public {}
}
