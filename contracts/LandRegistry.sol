// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract LandRegistry is ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    
    // Custom Roles (kept for other functionality)
    bytes32 public constant PATWARI_ROLE = keccak256("PATWARI_ROLE");
    bytes32 public constant CLERK_ROLE = keccak256("CLERK_ROLE");
    bytes32 public constant TEHSILDAR_ROLE = keccak256("TEHSILDAR_ROLE");
    bytes32 public constant WITNESS_ROLE = keccak256("WITNESS_ROLE");
    
    // Status Enums
    enum DraftStatus { PENDING, VERIFIED, APPROVED, REJECTED, MINTED }
    enum TransferStatus { PENDING, VERIFIED, APPROVED, COMPLETED, REJECTED }
    
    // Counters
    Counters.Counter private _draftIdCounter;
    Counters.Counter private _transferIdCounter;
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _officialIdCounter;
    
    // Verification Flags Structure
    struct VerificationFlags {
        bool noLoan;
        bool noDispute;
        bool noMortgage;
        bool propertyTitleVerified;
        bool documentsAuthentic;
        bool noOutstandingTaxes;
        bool noLegalEncumbrances;
    }
    
    // Official Information Structure (simplified)
    struct Official {
        uint256 id;
        string ipfsHash;
        address walletAddress;
        bytes32 role;
        string aadharCardNumber;
        bool active;
        uint256 registrationDate;
    }
    
    // Owner Information Structure
    struct Owner {
        address walletAddress;
        string name;
        string contactNumber;
        string aadharNumber;
        string ipfsHash;
        uint256 registrationDate;
        uint256 lastActivity;
        uint256[] ownedTokens;
        uint256[] draftHistory;
        uint256[] transferHistory;
    }
    
    // Land Draft Structure
    struct LandDraft {
        string state;
        string district;
        string village;
        string khasraNumber;
        uint256 area;
        string landType;
        address currentOwner;
        string ipfsHash;
        bool ownerApproved;
        DraftStatus status;
    }
    
    // Transfer Request Structure
    struct TransferRequest {
        uint256 tokenId;
        address currentOwner;
        address newOwner;
        string propertyAddress;
        string propertyType;
        string ipfsHash;
        bool clerkVerified;
        bool tehsildarVerified;
        TransferStatus status;
        uint256 initiatedAt;
        uint256 verifiedBy;
        uint256 approvedBy;
        uint256 rejectedBy;
        string rejectionReason;
        address[] sellerWitnesses;
        address[] buyerWitnesses;
        VerificationFlags verificationFlags;
        mapping(address => bool) sellerWitnessApprovals;
        mapping(address => bool) buyerWitnessApprovals;
        bool requireSellerWitnessApproval;
        bool requireBuyerWitnessApproval;
    }
    
    // Mappings
    mapping(uint256 => LandDraft) public landDrafts;
    mapping(uint256 => TransferRequest) public transferRequests;
    mapping(string => bool) public khasraNumbers;
    mapping(address => Owner) public owners;
    mapping(uint256 => Official) public officials;
    mapping(address => uint256) public addressToOfficialId;
    mapping(address => bool) public registeredUsers;
    
    // Events
    event OfficialRegistered(uint256 indexed officialId, address walletAddress, bytes32 role);
    event OfficialUpdated(uint256 indexed officialId);
    event OwnerRegistered(address indexed ownerAddress, string name, string aadharNumber);
    event OwnerUpdated(address indexed ownerAddress, string name);
    event LandDraftCreated(uint256 indexed draftId, string khasraNumber, address owner);
    event OwnerApproval(uint256 indexed draftId, address owner, bool approved);
    event DraftVerified(uint256 indexed draftId, address clerk);
    event DraftApproved(uint256 indexed draftId, address tehsildar);
    event DraftRejected(uint256 indexed draftId, address rejectedBy, string reason);
    event LandNFTMinted(uint256 indexed tokenId, uint256 indexed draftId);
    event TransferInitiated(uint256 indexed transferId, uint256 indexed tokenId, address newOwner);
    event TransferVerified(uint256 indexed transferId, address clerk);
    event TransferApproved(uint256 indexed transferId, address tehsildar);
    event TransferRejected(uint256 indexed transferId, address rejectedBy, string reason);
    event TransferCompleted(uint256 indexed transferId);
    event SellerWitnessAdded(uint256 indexed transferId, address witness);
    event BuyerWitnessAdded(uint256 indexed transferId, address witness);
    event SellerWitnessApproval(uint256 indexed transferId, address witness, bool approved);
    event BuyerWitnessApproval(uint256 indexed transferId, address witness, bool approved);
    event WitnessRequirementUpdated(uint256 indexed transferId, bool requireSeller, bool requireBuyer);

    // Custom Errors
    error ZeroAddress();
    error InvalidRole();
    error AlreadyRegistered();
    error OfficialDoesNotExist();
    error NameEmpty();
    error AadharEmpty();
    error NotRegisteredOwner();
    error NotPending();
    error NotOwner();
    error AlreadyMinted();
    error NotTheOwner();
    error NotRegistered();
    error OnlyCurrentOwner();
    error OnlyNewOwner();
    error NotSellerWitness();
    error NotBuyerWitness();
    error TransferNotPending();
    error TransferNotVerifiedByClerk();
    error TransferDocumentsMissing();
    error NotAllSellerWitnessesApproved();
    error NotAllBuyerWitnessesApproved();
    error LoanExists();
    error DisputeExists();
    error MortgageExists();
    error PropertyTitleNotVerified();
    error DocumentsNotAuthentic();
    error OutstandingTaxesExist();
    error LegalEncumbrancesExist();
    error InvalidIPFSHashLength();
    error InvalidIPFSHashPrefix();
    error CurrentOwnerMismatch();
    error KhasraNumberExists();
    error WitnessAlreadyAdded();
    error OfficialNotRegistered();

    constructor() ERC721("BhoomiNFT", "LAND") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PATWARI_ROLE, msg.sender);
        _grantRole(CLERK_ROLE, msg.sender);
        _grantRole(TEHSILDAR_ROLE, msg.sender);
        
        // Register the deployer as the first official
        uint256 officialId = _officialIdCounter.current();
        _officialIdCounter.increment();
        
        officials[officialId] = Official({
            id: officialId,
            ipfsHash: "",
            walletAddress: msg.sender,
            role: DEFAULT_ADMIN_ROLE,
            aadharCardNumber: "",
            active: true,
            registrationDate: block.timestamp
        });
        
        addressToOfficialId[msg.sender] = officialId;
        registeredUsers[msg.sender] = true;
        
        emit OfficialRegistered(officialId, msg.sender, DEFAULT_ADMIN_ROLE);
    }

    // ======================
    // OFFICIAL MANAGEMENT
    // ======================
    
    function registerOfficial(
        string memory ipfsHash,
        address walletAddress,
        bytes32 role,
        string memory aadharCardNumber
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (walletAddress == address(0)) revert ZeroAddress();
        if (!(role == PATWARI_ROLE || role == CLERK_ROLE || 
               role == TEHSILDAR_ROLE || role == WITNESS_ROLE)) revert InvalidRole();
        if (registeredUsers[walletAddress]) revert AlreadyRegistered();
        
        uint256 newOfficialId = _officialIdCounter.current();
        _officialIdCounter.increment();
        
        officials[newOfficialId] = Official({
            id: newOfficialId,
            ipfsHash: ipfsHash,
            walletAddress: walletAddress,
            role: role,
            aadharCardNumber: aadharCardNumber,
            active: true,
            registrationDate: block.timestamp
        });
        
        addressToOfficialId[walletAddress] = newOfficialId;
        _grantRole(role, walletAddress);
        registeredUsers[walletAddress] = true;
        
        emit OfficialRegistered(newOfficialId, walletAddress, role);
    }
    
    function updateOfficial(
        uint256 officialId,
        string memory ipfsHash,
        bool active
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (officials[officialId].id != officialId) revert OfficialDoesNotExist();
        
        officials[officialId].ipfsHash = ipfsHash;
        officials[officialId].active = active;
        
        emit OfficialUpdated(officialId);
    }
    
    // ======================
    // OWNER MANAGEMENT
    // ======================
    
    function registerOwner(
        string memory name,
        string memory contactNumber,
        string memory aadharNumber,
        string memory ipfsHash
    ) public {
        if (bytes(name).length == 0) revert NameEmpty();
        if (bytes(aadharNumber).length == 0) revert AadharEmpty();
        if (registeredUsers[msg.sender]) revert AlreadyRegistered();
        
        owners[msg.sender] = Owner({
            walletAddress: msg.sender,
            name: name,
            contactNumber: contactNumber,
            aadharNumber: aadharNumber,
            ipfsHash: ipfsHash,
            registrationDate: block.timestamp,
            lastActivity: block.timestamp,
            ownedTokens: new uint256[](0),
            draftHistory: new uint256[](0),
            transferHistory: new uint256[](0)
        });
        
        registeredUsers[msg.sender] = true;
        emit OwnerRegistered(msg.sender, name, aadharNumber);
    }
    
    function updateOwner(
        string memory name,
        string memory contactNumber,
        string memory ipfsHash
    ) public {
        if (owners[msg.sender].walletAddress != msg.sender) revert NotRegisteredOwner();
        
        owners[msg.sender].name = name;
        owners[msg.sender].contactNumber = contactNumber;
        owners[msg.sender].ipfsHash = ipfsHash;
        owners[msg.sender].lastActivity = block.timestamp;
        
        emit OwnerUpdated(msg.sender, name);
    }
    
    // ======================
    // LAND REGISTRATION FLOW
    // ======================

    function createLandDraft(
        string memory state,
        string memory district,
        string memory village,
        string memory khasraNumber,
        uint256 area,
        string memory landType,
        address owner,
        string memory ipfsHash
    ) public onlyRole(PATWARI_ROLE) {
        if (khasraNumbers[khasraNumber]) revert KhasraNumberExists();
        _validateIPFSHash(ipfsHash);
        
        uint256 draftId = _draftIdCounter.current();
        _draftIdCounter.increment();
        
        landDrafts[draftId] = LandDraft({
            state: state,
            district: district,
            village: village,
            khasraNumber: khasraNumber,
            area: area,
            landType: landType,
            currentOwner: owner,
            ipfsHash: ipfsHash,
            ownerApproved: false,
            status: DraftStatus.PENDING
        });
        
        khasraNumbers[khasraNumber] = true;
        owners[owner].draftHistory.push(draftId);
        
        emit LandDraftCreated(draftId, khasraNumber, owner);
    }

    function approveDraftAsOwner(uint256 draftId) public {
        if (landDrafts[draftId].currentOwner != msg.sender) revert NotOwner();
        if (landDrafts[draftId].status != DraftStatus.PENDING) revert NotPending();
        
        landDrafts[draftId].ownerApproved = true;
        landDrafts[draftId].status = DraftStatus.APPROVED;
        
        // Auto-mint NFT upon owner approval
        _mintLandNFT(draftId);
        
        emit OwnerApproval(draftId, msg.sender, true);
    }

    function rejectDraft(uint256 draftId, string memory reason) public onlyRole(TEHSILDAR_ROLE) {
        if (landDrafts[draftId].status != DraftStatus.PENDING) revert NotPending();
        
        uint256 officialId = addressToOfficialId[msg.sender];
        if (officialId == 0) revert OfficialNotRegistered();
        
        landDrafts[draftId].status = DraftStatus.REJECTED;
        
        emit DraftRejected(draftId, msg.sender, reason);
    }

    function _mintLandNFT(uint256 draftId) private {
        if (_draftMinted(draftId)) revert AlreadyMinted();
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        address owner = landDrafts[draftId].currentOwner;
        _safeMint(owner, tokenId);
        _setTokenURI(tokenId, string(abi.encodePacked("ipfs://", landDrafts[draftId].ipfsHash)));
        
        landDrafts[draftId].status = DraftStatus.MINTED;
        owners[owner].ownedTokens.push(tokenId);
        
        emit LandNFTMinted(tokenId, draftId);
    }

    // ======================
    // LAND TRANSFER FLOW
    // ======================

    function initiateTransfer(
        uint256 tokenId,
        address newOwner,
        string memory propertyAddress,
        string memory propertyType,
        string memory ipfsHash,
        bool requireSellerWitness,
        bool requireBuyerWitness
    ) public {
        if (ownerOf(tokenId) != msg.sender) revert NotTheOwner();
        if (newOwner == address(0)) revert ZeroAddress();
        if (owners[newOwner].walletAddress != newOwner) revert NotRegistered();
        _validateIPFSHash(ipfsHash);
        
        uint256 transferId = _transferIdCounter.current();
        _transferIdCounter.increment();
        
        TransferRequest storage newRequest = transferRequests[transferId];
        newRequest.tokenId = tokenId;
        newRequest.currentOwner = msg.sender;
        newRequest.newOwner = newOwner;
        newRequest.propertyAddress = propertyAddress;
        newRequest.propertyType = propertyType;
        newRequest.ipfsHash = ipfsHash;
        newRequest.clerkVerified = false;
        newRequest.tehsildarVerified = false;
        newRequest.status = TransferStatus.PENDING;
        newRequest.initiatedAt = block.timestamp;
        newRequest.verifiedBy = 0;
        newRequest.approvedBy = 0;
        newRequest.rejectedBy = 0;
        newRequest.rejectionReason = "";
        newRequest.requireSellerWitnessApproval = requireSellerWitness;
        newRequest.requireBuyerWitnessApproval = requireBuyerWitness;
        
        // Initialize verification flags
        newRequest.verificationFlags = VerificationFlags({
            noLoan: false,
            noDispute: false,
            noMortgage: false,
            propertyTitleVerified: false,
            documentsAuthentic: false,
            noOutstandingTaxes: false,
            noLegalEncumbrances: false
        });
        
        owners[msg.sender].transferHistory.push(transferId);
        owners[newOwner].transferHistory.push(transferId);
        owners[msg.sender].lastActivity = block.timestamp;
        owners[newOwner].lastActivity = block.timestamp;
        
        emit TransferInitiated(transferId, tokenId, newOwner);
        emit WitnessRequirementUpdated(transferId, requireSellerWitness, requireBuyerWitness);
    }

    function updateWitnessRequirements(
        uint256 transferId,
        bool requireSellerWitness,
        bool requireBuyerWitness
    ) public {
        TransferRequest storage request = transferRequests[transferId];
        if (request.currentOwner != msg.sender) revert OnlyCurrentOwner();
        if (request.status != TransferStatus.PENDING) revert TransferNotPending();
        
        request.requireSellerWitnessApproval = requireSellerWitness;
        request.requireBuyerWitnessApproval = requireBuyerWitness;
        
        emit WitnessRequirementUpdated(transferId, requireSellerWitness, requireBuyerWitness);
    }

    function addSellerWitness(uint256 transferId, address witness) public {
        TransferRequest storage request = transferRequests[transferId];
        if (request.currentOwner != msg.sender) revert OnlyCurrentOwner();
        if (witness == address(0)) revert ZeroAddress();
        
        for (uint i = 0; i < request.sellerWitnesses.length; i++) {
            if (request.sellerWitnesses[i] == witness) revert WitnessAlreadyAdded();
        }
        
        request.sellerWitnesses.push(witness);
        emit SellerWitnessAdded(transferId, witness);
    }

    function addBuyerWitness(uint256 transferId, address witness) public {
        TransferRequest storage request = transferRequests[transferId];
        if (request.newOwner != msg.sender) revert OnlyNewOwner();
        if (witness == address(0)) revert ZeroAddress();
        
        for (uint i = 0; i < request.buyerWitnesses.length; i++) {
            if (request.buyerWitnesses[i] == witness) revert WitnessAlreadyAdded();
        }
        
        request.buyerWitnesses.push(witness);
        emit BuyerWitnessAdded(transferId, witness);
    }

    function approveTransferAsSellerWitness(uint256 transferId) public {
        TransferRequest storage request = transferRequests[transferId];
        if (request.status != TransferStatus.PENDING) revert TransferNotPending();
        
        bool isWitness = false;
        for (uint i = 0; i < request.sellerWitnesses.length; i++) {
            if (request.sellerWitnesses[i] == msg.sender) {
                isWitness = true;
                break;
            }
        }
        if (!isWitness) revert NotSellerWitness();
        
        request.sellerWitnessApprovals[msg.sender] = true;
        
        emit SellerWitnessApproval(transferId, msg.sender, true);
    }

    function approveTransferAsBuyerWitness(uint256 transferId) public {
        TransferRequest storage request = transferRequests[transferId];
        if (request.status != TransferStatus.PENDING) revert TransferNotPending();
        
        bool isWitness = false;
        for (uint i = 0; i < request.buyerWitnesses.length; i++) {
            if (request.buyerWitnesses[i] == msg.sender) {
                isWitness = true;
                break;
            }
        }
        if (!isWitness) revert NotBuyerWitness();
        
        request.buyerWitnessApprovals[msg.sender] = true;
        
        emit BuyerWitnessApproval(transferId, msg.sender, true);
    }

    function verifyTransfer(uint256 transferId, VerificationFlags memory flags) public onlyRole(CLERK_ROLE) {
        TransferRequest storage request = transferRequests[transferId];
        if (request.status != TransferStatus.PENDING) revert TransferNotPending();
        if (bytes(request.ipfsHash).length == 0) revert TransferDocumentsMissing();
        
        if (request.requireSellerWitnessApproval) {
            bool allSellerWitnessesApproved = true;
            for (uint i = 0; i < request.sellerWitnesses.length; i++) {
                if (!request.sellerWitnessApprovals[request.sellerWitnesses[i]]) {
                    allSellerWitnessesApproved = false;
                    break;
                }
            }
            if (!allSellerWitnessesApproved) revert NotAllSellerWitnessesApproved();
        }
        
        if (request.requireBuyerWitnessApproval) {
            bool allBuyerWitnessesApproved = true;
            for (uint i = 0; i < request.buyerWitnesses.length; i++) {
                if (!request.buyerWitnessApprovals[request.buyerWitnesses[i]]) {
                    allBuyerWitnessesApproved = false;
                    break;
                }
            }
            if (!allBuyerWitnessesApproved) revert NotAllBuyerWitnessesApproved();
        }
        
        if (!flags.noLoan) revert LoanExists();
        if (!flags.noDispute) revert DisputeExists();
        if (!flags.noMortgage) revert MortgageExists();
        if (!flags.propertyTitleVerified) revert PropertyTitleNotVerified();
        if (!flags.documentsAuthentic) revert DocumentsNotAuthentic();
        if (!flags.noOutstandingTaxes) revert OutstandingTaxesExist();
        if (!flags.noLegalEncumbrances) revert LegalEncumbrancesExist();
        
        uint256 officialId = addressToOfficialId[msg.sender];
        if (officialId == 0) revert OfficialNotRegistered();
        
        request.clerkVerified = true;
        request.status = TransferStatus.VERIFIED;
        request.verifiedBy = officialId;
        request.verificationFlags = flags;
        
        emit TransferVerified(transferId, msg.sender);
    }

    function approveTransfer(uint256 transferId) public onlyRole(TEHSILDAR_ROLE) {
        TransferRequest storage request = transferRequests[transferId];
        if (request.status != TransferStatus.VERIFIED) revert TransferNotVerifiedByClerk();
        
        uint256 officialId = addressToOfficialId[msg.sender];
        if (officialId == 0) revert OfficialNotRegistered();
        
        request.tehsildarVerified = true;
        request.status = TransferStatus.APPROVED;
        request.approvedBy = officialId;
        
        // Automatically complete the transfer
        _completeTransfer(transferId);
        
        emit TransferApproved(transferId, msg.sender);
    }

    function rejectTransfer(uint256 transferId, string memory reason) public onlyRole(TEHSILDAR_ROLE) {
        TransferRequest storage request = transferRequests[transferId];
        if (request.status != TransferStatus.VERIFIED) revert TransferNotVerifiedByClerk();
        
        uint256 officialId = addressToOfficialId[msg.sender];
        if (officialId == 0) revert OfficialNotRegistered();
        
        request.status = TransferStatus.REJECTED;
        request.rejectedBy = officialId;
        request.rejectionReason = reason;
        
        emit TransferRejected(transferId, msg.sender, reason);
    }

    function _completeTransfer(uint256 transferId) private {
        TransferRequest storage request = transferRequests[transferId];
        if (ownerOf(request.tokenId) != request.currentOwner) revert CurrentOwnerMismatch();
        
        request.status = TransferStatus.COMPLETED;
        _transfer(request.currentOwner, request.newOwner, request.tokenId);
        
        _removeTokenFromOwner(request.currentOwner, request.tokenId);
        owners[request.newOwner].ownedTokens.push(request.tokenId);
        owners[request.currentOwner].lastActivity = block.timestamp;
        owners[request.newOwner].lastActivity = block.timestamp;
        
        emit TransferCompleted(transferId);
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    function getLandDraft(uint256 draftId) public view returns (LandDraft memory) {
        return landDrafts[draftId];
    }

    function getTransferRequest(uint256 transferId) public view returns (
        uint256 tokenId,
        address currentOwner,
        address newOwner,
        string memory propertyAddress,
        string memory propertyType,
        string memory ipfsHash,
        bool clerkVerified,
        bool tehsildarVerified,
        TransferStatus status,
        uint256 initiatedAt,
        uint256 verifiedBy,
        uint256 approvedBy,
        uint256 rejectedBy,
        string memory rejectionReason,
        address[] memory sellerWitnesses,
        address[] memory buyerWitnesses,
        VerificationFlags memory verificationFlags,
        bool requireSellerWitnessApproval,
        bool requireBuyerWitnessApproval
    ) {
        TransferRequest storage request = transferRequests[transferId];
        return (
            request.tokenId,
            request.currentOwner,
            request.newOwner,
            request.propertyAddress,
            request.propertyType,
            request.ipfsHash,
            request.clerkVerified,
            request.tehsildarVerified,
            request.status,
            request.initiatedAt,
            request.verifiedBy,
            request.approvedBy,
            request.rejectedBy,
            request.rejectionReason,
            request.sellerWitnesses,
            request.buyerWitnesses,
            request.verificationFlags,
            request.requireSellerWitnessApproval,
            request.requireBuyerWitnessApproval
        );
    }

    function getOwnerDrafts(address owner) public view returns (uint256[] memory) {
        return owners[owner].draftHistory;
    }

    function getOwnerTokens(address owner) public view returns (uint256[] memory) {
        return owners[owner].ownedTokens;
    }

    function getOwnerTransfers(address owner) public view returns (uint256[] memory) {
        return owners[owner].transferHistory;
    }

    function getDraftStatus(uint256 draftId) public view returns (string memory) {
        if (landDrafts[draftId].status == DraftStatus.PENDING) return "PENDING";
        if (landDrafts[draftId].status == DraftStatus.VERIFIED) return "VERIFIED";
        if (landDrafts[draftId].status == DraftStatus.APPROVED) return "APPROVED";
        if (landDrafts[draftId].status == DraftStatus.REJECTED) return "REJECTED";
        if (landDrafts[draftId].status == DraftStatus.MINTED) return "MINTED";
        return "UNKNOWN";
    }

    function getTransferStatus(uint256 transferId) public view returns (string memory) {
        if (transferRequests[transferId].status == TransferStatus.PENDING) return "PENDING";
        if (transferRequests[transferId].status == TransferStatus.VERIFIED) return "VERIFIED";
        if (transferRequests[transferId].status == TransferStatus.APPROVED) return "APPROVED";
        if (transferRequests[transferId].status == TransferStatus.COMPLETED) return "COMPLETED";
        if (transferRequests[transferId].status == TransferStatus.REJECTED) return "REJECTED";
        return "UNKNOWN";
    }

    function getOfficial(uint256 officialId) public view returns (Official memory) {
        return officials[officialId];
    }
    
    function getOfficialByAddress(address walletAddress) public view returns (Official memory) {
        uint256 officialId = addressToOfficialId[walletAddress];
        return officials[officialId];
    }
    
    function getOwner(address ownerAddress) public view returns (Owner memory) {
        return owners[ownerAddress];
    }

    function isSellerWitnessApproved(uint256 transferId, address witness) public view returns (bool) {
        return transferRequests[transferId].sellerWitnessApprovals[witness];
    }

    function isBuyerWitnessApproved(uint256 transferId, address witness) public view returns (bool) {
        return transferRequests[transferId].buyerWitnessApprovals[witness];
    }

    function areWitnessRequirementsMet(uint256 transferId) public view returns (bool) {
        TransferRequest storage request = transferRequests[transferId];
        
        // Check seller witness requirements
        if (request.requireSellerWitnessApproval) {
            for (uint i = 0; i < request.sellerWitnesses.length; i++) {
                if (!request.sellerWitnessApprovals[request.sellerWitnesses[i]]) {
                    return false;
                }
            }
        }
        
        // Check buyer witness requirements
        if (request.requireBuyerWitnessApproval) {
            for (uint i = 0; i < request.buyerWitnesses.length; i++) {
                if (!request.buyerWitnessApprovals[request.buyerWitnesses[i]]) {
                    return false;
                }
            }
        }
        
        return true;
    }

    // ======================
    // INTERNAL FUNCTIONS
    // ======================

    function _draftMinted(uint256 draftId) internal view returns (bool) {
        return landDrafts[draftId].status == DraftStatus.MINTED;
    }

    function _removeTokenFromOwner(address owner, uint256 tokenId) internal {
        uint256[] storage tokens = owners[owner].ownedTokens;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenId) {
                if (i != tokens.length - 1) {
                    tokens[i] = tokens[tokens.length - 1];
                }
                tokens.pop();
                break;
            }
        }
    }

    function _validateIPFSHash(string memory hash) internal pure {
        if (bytes(hash).length != 46) revert InvalidIPFSHashLength();
        if (!(bytes(hash)[0] == 'Q' && bytes(hash)[1] == 'm')) revert InvalidIPFSHashPrefix();
    }

    // ======================
    // OVERRIDES
    // ======================

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
