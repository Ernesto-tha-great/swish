// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IDocumentRegistry
 * @dev Interface for the DocumentRegistry contract
 */
interface IDocumentRegistry {
    enum DocumentType {
        Invoice,
        PayrollRecord,
        Contract,
        Receipt,
        Statement,
        Other
    }

    struct Document {
        bytes32 docHash;
        address registeredBy;
        uint256 timestamp;
        DocumentType docType;
        string docReference;
        bool isRevoked;
    }

    event DocumentRegistered(
        bytes32 indexed docHash,
        address indexed registeredBy,
        DocumentType docType,
        string docReference
    );
    
    event DocumentRevoked(
        bytes32 indexed docHash,
        address indexed revokedBy,
        string reason
    );

    function registerDocument(
        bytes32 _docHash,
        DocumentType _docType,
        string calldata _docReference
    ) external;

    function batchRegisterDocuments(
        bytes32[] calldata _docHashes,
        DocumentType[] calldata _docTypes,
        string[] calldata _docReferences
    ) external;

    function revokeDocument(bytes32 _docHash, string calldata _reason) external;

    function verifyDocument(bytes32 _docHash) 
        external 
        view 
        returns (bool exists, bool isValid, Document memory documentData);
}