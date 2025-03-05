// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ITokenRegistry
 * @dev Interface for the TokenRegistry contract
 */
interface ITokenRegistry {
    struct TokenInfo {
        string symbol;
        address tokenAddress;
        uint8 decimals;
        bool isEnabled;
        uint256 minimumTransferAmount;
    }

    struct PriceFeed {
        address feedAddress;
        uint256 lastPrice;
        uint256 lastUpdateTimestamp;
    }

    event TokenAdded(
        string symbol,
        address tokenAddress,
        uint8 decimals,
        uint256 minimumTransferAmount
    );
    
    event TokenUpdated(
        string symbol,
        bool isEnabled,
        uint256 minimumTransferAmount
    );
    
    event PriceFeedUpdated(
        string symbol,
        address feedAddress,
        uint256 price
    );

    function addToken(
        string calldata _symbol,
        address _tokenAddress,
        uint8 _decimals,
        uint256 _minimumTransferAmount
    ) external;

    function updateToken(
        string calldata _symbol,
        bool _isEnabled,
        uint256 _minimumTransferAmount
    ) external;

    function setPriceFeed(
        string calldata _symbol,
        address _feedAddress
    ) external;

    function updatePrice(
        string calldata _symbol,
        uint256 _price
    ) external;

    function getTokenInfo(string calldata _symbol) 
        external 
        view 
        returns (TokenInfo memory);
        
    function getTokenPriceFeed(string calldata _symbol) 
        external 
        view 
        returns (PriceFeed memory);
        
    function isTokenEnabled(string calldata _symbol) 
        external 
        view 
        returns (bool);
        
    function convertAmount(
        string calldata _fromSymbol,
        string calldata _toSymbol,
        uint256 _amount
    ) external view returns (uint256);
}