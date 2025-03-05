// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interfaces/ITokenRegistry.sol";

/**
 * @title TokenRegistry
 * @dev Manages supported tokens and their price feeds
 */
contract TokenRegistry is ITokenRegistry, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PRICE_FEEDER_ROLE = keccak256("PRICE_FEEDER_ROLE");

    // Maps token symbols to token info
    mapping(string => TokenInfo) private tokenInfos;
    // Maps token symbols to price feed info
    mapping(string => PriceFeed) private priceFeeds;
    // Array of all supported token symbols
    string[] public supportedTokens;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PRICE_FEEDER_ROLE, msg.sender);
    }

    /**
     * @dev Add a new supported token
     * @param _symbol Token symbol
     * @param _tokenAddress Token contract address
     * @param _decimals Token decimals
     * @param _minimumTransferAmount Minimum amount for transfers
     */
    function addToken(
        string calldata _symbol,
        address _tokenAddress,
        uint8 _decimals,
        uint256 _minimumTransferAmount
    ) external onlyRole(ADMIN_ROLE) override {
        require(bytes(_symbol).length > 0, "Symbol cannot be empty");
        require(_tokenAddress != address(0), "Invalid token address");
        require(tokenInfos[_symbol].tokenAddress == address(0), "Token already exists");
        
        tokenInfos[_symbol] = TokenInfo({
            symbol: _symbol,
            tokenAddress: _tokenAddress,
            decimals: _decimals,
            isEnabled: true,
            minimumTransferAmount: _minimumTransferAmount
        });
        
        supportedTokens.push(_symbol);
        
        emit TokenAdded(_symbol, _tokenAddress, _decimals, _minimumTransferAmount);
    }

    /**
     * @dev Update token settings
     * @param _symbol Token symbol
     * @param _isEnabled Whether the token is enabled
     * @param _minimumTransferAmount New minimum transfer amount
     */
    function updateToken(
        string calldata _symbol,
        bool _isEnabled,
        uint256 _minimumTransferAmount
    ) external onlyRole(ADMIN_ROLE) override {
        require(tokenInfos[_symbol].tokenAddress != address(0), "Token does not exist");
        
        tokenInfos[_symbol].isEnabled = _isEnabled;
        tokenInfos[_symbol].minimumTransferAmount = _minimumTransferAmount;
        
        emit TokenUpdated(_symbol, _isEnabled, _minimumTransferAmount);
    }

    /**
     * @dev Set price feed for a token
     * @param _symbol Token symbol
     * @param _feedAddress Price feed contract address
     */
    function setPriceFeed(
        string calldata _symbol,
        address _feedAddress
    ) external onlyRole(ADMIN_ROLE) override {
        require(tokenInfos[_symbol].tokenAddress != address(0), "Token does not exist");
        require(_feedAddress != address(0), "Invalid feed address");
        
        priceFeeds[_symbol].feedAddress = _feedAddress;
        
        emit PriceFeedUpdated(_symbol, _feedAddress, priceFeeds[_symbol].lastPrice);
    }

    /**
     * @dev Update price for a token
     * @param _symbol Token symbol
     * @param _price New price (scaled by 1e8)
     */
    function updatePrice(
        string calldata _symbol,
        uint256 _price
    ) external onlyRole(PRICE_FEEDER_ROLE) override {
        require(tokenInfos[_symbol].tokenAddress != address(0), "Token does not exist");
        
        priceFeeds[_symbol].lastPrice = _price;
        priceFeeds[_symbol].lastUpdateTimestamp = block.timestamp;
        
        emit PriceFeedUpdated(_symbol, priceFeeds[_symbol].feedAddress, _price);
    }

    /**
     * @dev Get token information
     * @param _symbol Token symbol
     * @return Token information
     */
    function getTokenInfo(string calldata _symbol) 
        external 
        view 
        override
        returns (TokenInfo memory) 
    {
        require(tokenInfos[_symbol].tokenAddress != address(0), "Token does not exist");
        return tokenInfos[_symbol];
    }

    /**
     * @dev Get price feed information
     * @param _symbol Token symbol
     * @return Price feed information
     */
    function getTokenPriceFeed(string calldata _symbol) 
        external 
        view 
        override
        returns (PriceFeed memory) 
    {
        require(tokenInfos[_symbol].tokenAddress != address(0), "Token does not exist");
        return priceFeeds[_symbol];
    }

    /**
     * @dev Check if a token is enabled
     * @param _symbol Token symbol
     * @return Whether the token is enabled
     */
    function isTokenEnabled(string calldata _symbol) 
        external 
        view 
        override
        returns (bool) 
    {
        require(tokenInfos[_symbol].tokenAddress != address(0), "Token does not exist");
        return tokenInfos[_symbol].isEnabled;
    }

    /**
     * @dev Convert amount from one token to another
     * @param _fromSymbol Source token symbol
     * @param _toSymbol Destination token symbol
     * @param _amount Amount to convert
     * @return Converted amount
     */
    function convertAmount(
        string calldata _fromSymbol,
        string calldata _toSymbol,
        uint256 _amount
    ) external view override returns (uint256) {
        require(tokenInfos[_fromSymbol].tokenAddress != address(0), "Source token does not exist");
        require(tokenInfos[_toSymbol].tokenAddress != address(0), "Destination token does not exist");
        
        // If same token, no conversion needed
        if (keccak256(bytes(_fromSymbol)) == keccak256(bytes(_toSymbol))) {
            return _amount;
        }
        
        // Get price feeds
        PriceFeed memory fromFeed = priceFeeds[_fromSymbol];
        PriceFeed memory toFeed = priceFeeds[_toSymbol];
        
        require(fromFeed.lastPrice > 0, "Source token price not available");
        require(toFeed.lastPrice > 0, "Destination token price not available");
        
        // Get decimals
        uint8 fromDecimals = tokenInfos[_fromSymbol].decimals;
        uint8 toDecimals = tokenInfos[_toSymbol].decimals;
        
        // Convert amount based on price and decimals
        uint256 valueInUSD = (_amount * fromFeed.lastPrice) / (10 ** fromDecimals);
        uint256 convertedAmount = (valueInUSD * (10 ** toDecimals)) / toFeed.lastPrice;
        
        return convertedAmount;
    }

    /**
     * @dev Get all supported tokens
     * @return Array of token symbols
     */
    function getSupportedTokens() external view returns (string[] memory) {
        return supportedTokens;
    }

    /**
     * @dev Grant price feeder role
     * @param _account Address to grant the role to
     */
    function grantPriceFeederRole(address _account) external onlyRole(ADMIN_ROLE) {
        grantRole(PRICE_FEEDER_ROLE, _account);
    }

    /**
     * @dev Revoke price feeder role
     * @param _account Address to revoke the role from
     */
    function revokePriceFeederRole(address _account) external onlyRole(ADMIN_ROLE) {
        revokeRole(PRICE_FEEDER_ROLE, _account);
    }
}