// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IDocumentRegistry.sol";

/**
 * @title DocumentRegistry
 * @dev Stores hashes of important documents for verification
 */
contract DocumentRegistry is IDocumentRegistry, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DOCUMENT_MANAGER_ROLE = keccak256("DOCUMENT_MANAGER_ROLE");

    // Maps document hash to Document struct
    mapping(bytes32 => Document) public documents;
    // Maps address to array of document hashes they've registered
    mapping(address => bytes32[]) public userDocuments;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DOCUMENT_MANAGER_ROLE, msg.sender);
    }

    /**
     * @dev Register a document hash
     * @param _docHash Hash of the document
     * @param _docType Type of document
     * @param _docReference External reference or description
     */
    function registerDocument(
        bytes32 _docHash,
        DocumentType _docType,
        string calldata _docReference
    ) external onlyRole(DOCUMENT_MANAGER_ROLE) override {
        require(_docHash != bytes32(0), "Invalid document hash");
        require(documents[_docHash].docHash == bytes32(0), "Document already registered");
        
        documents[_docHash] = Document({
            docHash: _docHash,
            registeredBy: msg.sender,
            timestamp: block.timestamp,
            docType: _docType,
            docReference: _docReference,
            isRevoked: false
        });
        
        userDocuments[msg.sender].push(_docHash);
        
        emit DocumentRegistered(_docHash, msg.sender, _docType, _docReference);
    }

    /**
     * @dev Register multiple document hashes in a batch
     * @param _docHashes Array of document hashes
     * @param _docTypes Array of document types
     * @param _docReferences Array of references
     */
    function batchRegisterDocuments(
        bytes32[] calldata _docHashes,
        DocumentType[] calldata _docTypes,
        string[] calldata _docReferences
    ) external onlyRole(DOCUMENT_MANAGER_ROLE) override {
        require(_docHashes.length == _docTypes.length, "Array length mismatch");
        require(_docTypes.length == _docReferences.length, "Array length mismatch");
        
        for (uint256 i = 0; i < _docHashes.length; i++) {
            bytes32 docHash = _docHashes[i];
            
            require(docHash != bytes32(0), "Invalid document hash");
            require(documents[docHash].docHash == bytes32(0), "Document already registered");
            
            documents[docHash] = Document({
                docHash: docHash,
                registeredBy: msg.sender,
                timestamp: block.timestamp,
                docType: _docTypes[i],
                docReference: _docReferences[i],
                isRevoked: false
            });
            
            userDocuments[msg.sender].push(docHash);
            
            emit DocumentRegistered(docHash, msg.sender, _docTypes[i], _docReferences[i]);
        }
    }

    /**
     * @dev Revoke a document (mark as invalid)
     * @param _docHash Hash of the document to revoke
     * @param _reason Reason for revocation
     */
    function revokeDocument(bytes32 _docHash, string calldata _reason) 
        external 
        onlyRole(DOCUMENT_MANAGER_ROLE) 
        override 
    {
        require(documents[_docHash].docHash != bytes32(0), "Document not registered");
        require(!documents[_docHash].isRevoked, "Document already revoked");
        
        documents[_docHash].isRevoked = true;
        
        emit DocumentRevoked(_docHash, msg.sender, _reason);
    }

    /**
     * @dev Verify a document hash exists and is valid
     * @param _docHash Hash to verify
     * @return exists Whether the document exists
     * @return isValid Whether the document is valid (not revoked)
     * @return documentData The document data
     */
    function verifyDocument(bytes32 _docHash) 
        external 
        view 
        override
        returns (bool exists, bool isValid, Document memory documentData) 
    {
        documentData = documents[_docHash];
        exists = (documentData.docHash != bytes32(0));
        isValid = exists && !documentData.isRevoked;
        
        return (exists, isValid, documentData);
    }

    /**
     * @dev Get all documents registered by a user
     * @param _user Address of the user
     * @return Array of document hashes
     */
    function getUserDocuments(address _user) external view returns (bytes32[] memory) {
        return userDocuments[_user];
    }

    /**
     * @dev Grant document manager role
     * @param _account Address to grant the role to
     */
    function grantDocumentManagerRole(address _account) external onlyRole(ADMIN_ROLE) {
        grantRole(DOCUMENT_MANAGER_ROLE, _account);
    }

    /**
     * @dev Revoke document manager role
     * @param _account Address to revoke the role from
     */
    function revokeDocumentManagerRole(address _account) external onlyRole(ADMIN_ROLE) {
        revokeRole(DOCUMENT_MANAGER_ROLE, _account);
    }
}