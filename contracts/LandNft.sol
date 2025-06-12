// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract LandRegistry is ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    
    // Custom Roles
    bytes32 public constant PATWARI_ROLE = keccak256("PATWARI_ROLE");
    bytes32 public constant CLERK_ROLE = keccak256("CLERK_ROLE");
    bytes32 public constant TEHSILDAR_ROLE = keccak256("TEHSILDAR_ROLE");
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    bytes32 public constant WITNESS_ROLE = keccak256("WITNESS_ROLE");
    
    // Status Enums
    enum DraftStatus { PENDING, VERIFIED, APPROVED, REJECTED, MINTED }
    enum TransferStatus { PENDING, VERIFIED, APPROVED, COMPLETED, REJECTED }
    
    // Counters
    Counters.Counter private _draftIdCounter;
    Counters.Counter private _transferIdCounter;
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _officialIdCounter;
    
    // Official Information Structure
    struct Official {
        uint256 id;
        string name;
        string designation;
        string department;
        string jurisdiction;
        string contactNumber;
        string officialId;
        string ipfsHash;
        address walletAddress;
        bool active;
        uint256 registrationDate;
        uint256 lastActivity;
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
    
    // Witness Information Structure
    struct Witness {
        address walletAddress;
        string name;
        string contactNumber;
        string relationToProperty;
        uint256[] witnessedTokens;
        uint256[] witnessedTransfers;
        uint256 lastActivity;
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
        bool witnessApproved;
        DraftStatus status;
        uint256 createdBy;
        uint256 verifiedBy;
        uint256 approvedBy;
        uint256 rejectedBy;
        string rejectionReason;
    }
    
    // Transfer Request Structure
    struct TransferRequest {
        uint256 tokenId;
        address currentOwner;
        address newOwner;
        string propertyAddress;
        string propertyType;
        string ipfsHash;
        bool sellerWitnessApproved;
        bool buyerWitnessApproved;
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
    }
    
    // Mappings
    mapping(uint256 => LandDraft) public landDrafts;
    mapping(uint256 => TransferRequest) public transferRequests;
    mapping(string => bool) public khasraNumbers;
    mapping(address => Owner) public owners;
    mapping(address => Witness) public witnesses;
    mapping(uint256 => Official) public officials;
    mapping(address => uint256) public addressToOfficialId;
    mapping(uint256 => address[]) public tokenToWitnesses;
    mapping(address => bool) public registeredUsers;
    
    // Events
    event OfficialRegistered(uint256 indexed officialId, string name, string designation, address walletAddress);
    event OfficialUpdated(uint256 indexed officialId, string name, string designation);
    event OwnerRegistered(address indexed ownerAddress, string name, string aadharNumber);
    event OwnerUpdated(address indexed ownerAddress, string name);
    event WitnessRegistered(address indexed witnessAddress, string name);
    event WitnessUpdated(address indexed witnessAddress, string name);
    event LandDraftCreated(uint256 indexed draftId, string khasraNumber, address owner);
    event OwnerApproval(uint256 indexed draftId, address owner, bool approved);
    event WitnessApproval(uint256 indexed draftId, address witness, bool approved);
    event DraftVerified(uint256 indexed draftId, address clerk);
    event DraftApproved(uint256 indexed draftId, address tehsildar);
    event DraftRejected(uint256 indexed draftId, address rejectedBy, string reason);
    event LandNFTMinted(uint256 indexed tokenId, uint256 indexed draftId);
    event TransferInitiated(uint256 indexed transferId, uint256 indexed tokenId, address newOwner);
    event TransferVerified(uint256 indexed transferId, address clerk);
    event TransferApproved(uint256 indexed transferId, address tehsildar);
    event TransferRejected(uint256 indexed transferId, address rejectedBy, string reason);
    event TransferCompleted(uint256 indexed transferId);
    event WitnessAdded(uint256 indexed tokenId, address witness);
    event SellerWitnessApproval(uint256 indexed transferId, address witness, bool approved);
    event BuyerWitnessApproval(uint256 indexed transferId, address witness, bool approved);

    constructor() ERC721("BhoomiNFT", "LAND") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PATWARI_ROLE, msg.sender);
        _grantRole(CLERK_ROLE, msg.sender);
        _grantRole(TEHSILDAR_ROLE, msg.sender);
        _grantRole(REGISTRAR_ROLE, msg.sender);
        
        // Register the deployer as the first official
        uint256 officialId = _officialIdCounter.current();
        _officialIdCounter.increment();
        
        officials[officialId] = Official({
            id: officialId,
            name: "Initial Admin",
            designation: "Administrator",
            department: "Land Registry",
            jurisdiction: "All",
            contactNumber: "",
            officialId: "ADMIN-001",
            ipfsHash: "",
            walletAddress: msg.sender,
            active: true,
            registrationDate: block.timestamp,
            lastActivity: block.timestamp
        });
        
        addressToOfficialId[msg.sender] = officialId;
        registeredUsers[msg.sender] = true;
        
        emit OfficialRegistered(officialId, "Initial Admin", "Administrator", msg.sender);
    }

    // ======================
    // OFFICIAL MANAGEMENT
    // ======================
    
    function registerOfficial(
        string memory name,
        string memory designation,
        string memory department,
        string memory jurisdiction,
        string memory contactNumber,
        string memory officialId,
        string memory ipfsHash,
        address walletAddress,
        bytes32 role
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // Requirements checks
        require(bytes(name).length > 0, "Empty name");
        require(bytes(designation).length > 0, "Empty designation");
        require(bytes(officialId).length > 0, "Empty officialId");
        require(walletAddress != address(0), "Zero address");
        require(role == PATWARI_ROLE || role == CLERK_ROLE || 
               role == TEHSILDAR_ROLE || role == REGISTRAR_ROLE, "Invalid role");
        require(!registeredUsers[walletAddress], "Already registered");
        
        // Get new official ID
        uint256 newOfficialId = _officialIdCounter.current();
        _officialIdCounter.increment();
        
        // Create official record
        officials[newOfficialId] = Official({
            id: newOfficialId,
            name: name,
            designation: designation,
            department: department,
            jurisdiction: jurisdiction,
            contactNumber: contactNumber,
            officialId: officialId,
            ipfsHash: ipfsHash,
            walletAddress: walletAddress,
            active: true,
            registrationDate: block.timestamp,
            lastActivity: block.timestamp
        });
        
        // Update mappings
        addressToOfficialId[walletAddress] = newOfficialId;
        _grantRole(role, walletAddress);
        registeredUsers[walletAddress] = true;
        
        emit OfficialRegistered(newOfficialId, name, designation, walletAddress);
    }
    
    function updateOfficial(
        uint256 officialId,
        string memory name,
        string memory designation,
        string memory department,
        string memory jurisdiction,
        string memory contactNumber,
        string memory ipfsHash,
        bool active
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(officials[officialId].id == officialId, "Official does not exist");
        
        officials[officialId].name = name;
        officials[officialId].designation = designation;
        officials[officialId].department = department;
        officials[officialId].jurisdiction = jurisdiction;
        officials[officialId].contactNumber = contactNumber;
        officials[officialId].ipfsHash = ipfsHash;
        officials[officialId].active = active;
        officials[officialId].lastActivity = block.timestamp;
        
        emit OfficialUpdated(officialId, name, designation);
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
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(aadharNumber).length > 0, "Aadhar number cannot be empty");
        require(!registeredUsers[msg.sender], "Address already registered");
        
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
        require(owners[msg.sender].walletAddress == msg.sender, "Not a registered owner");
        
        owners[msg.sender].name = name;
        owners[msg.sender].contactNumber = contactNumber;
        owners[msg.sender].ipfsHash = ipfsHash;
        owners[msg.sender].lastActivity = block.timestamp;
        
        emit OwnerUpdated(msg.sender, name);
    }
    
    // ======================
    // WITNESS MANAGEMENT
    // ======================
    
    function registerWitness(
        string memory name,
        string memory contactNumber
    ) public {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(!registeredUsers[msg.sender], "Address already registered");
        
        witnesses[msg.sender] = Witness({
            walletAddress: msg.sender,
            name: name,
            contactNumber: contactNumber,
            relationToProperty: "",
            witnessedTokens: new uint256[](0),
            witnessedTransfers: new uint256[](0),
            lastActivity: block.timestamp 
        });
        
        _grantRole(WITNESS_ROLE, msg.sender);
        registeredUsers[msg.sender] = true;
        emit WitnessRegistered(msg.sender, name);
    }
    
    function updateWitness(
        string memory name,
        string memory contactNumber,
        string memory relationToProperty
    ) public {
        require(witnesses[msg.sender].walletAddress == msg.sender, "Not a registered witness");
        
        witnesses[msg.sender].name = name;
        witnesses[msg.sender].contactNumber = contactNumber;
        witnesses[msg.sender].relationToProperty = relationToProperty;
        
        emit WitnessUpdated(msg.sender, name);
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
        require(bytes(state).length > 0, "State cannot be empty");
        require(bytes(district).length > 0, "District cannot be empty");
        require(bytes(village).length > 0, "Village cannot be empty");
        require(bytes(khasraNumber).length > 0, "Khasra number cannot be empty");
        require(area > 0, "Area must be greater than zero");
        require(bytes(landType).length > 0, "Land type cannot be empty");
        require(owner != address(0), "Owner cannot be zero address");
        require(!khasraNumbers[khasraNumber], "Khasra number already exists");
        require(owners[owner].walletAddress == owner, "Owner not registered");
        _validateIPFSHash(ipfsHash); // Validate the IPFS hash
        
        uint256 draftId = _draftIdCounter.current();
        _draftIdCounter.increment();
        
        uint256 officialId = addressToOfficialId[msg.sender];
        require(officialId != 0, "Official not registered");
        
        landDrafts[draftId] = LandDraft({
            state: state,
            district: district,
            village: village,
            khasraNumber: khasraNumber,
            area: area,
            landType: landType,
            currentOwner: owner,
            ipfsHash: ipfsHash, // Set the IPFS hash here
            ownerApproved: false,
            witnessApproved: false,
            status: DraftStatus.PENDING,
            createdBy: officialId,
            verifiedBy: 0,
            approvedBy: 0,
            rejectedBy: 0,
            rejectionReason: ""
        });
        
        khasraNumbers[khasraNumber] = true;
        owners[owner].draftHistory.push(draftId);
        officials[officialId].lastActivity = block.timestamp;
        
        emit LandDraftCreated(draftId, khasraNumber, owner);
    }

    function approveDraftAsOwner(uint256 draftId) public {
        require(landDrafts[draftId].currentOwner == msg.sender, "Not the owner of this draft");
        require(landDrafts[draftId].status == DraftStatus.PENDING, "Draft not in pending status");
        
        landDrafts[draftId].ownerApproved = true;
        owners[msg.sender].lastActivity = block.timestamp;
        
        emit OwnerApproval(draftId, msg.sender, true);
    }

    function approveDraftAsWitness(uint256 draftId) public onlyRole(WITNESS_ROLE) {
        require(landDrafts[draftId].status == DraftStatus.PENDING, "Draft not in pending status");
        
        landDrafts[draftId].witnessApproved = true;
        witnesses[msg.sender].lastActivity = block.timestamp;
        
        emit WitnessApproval(draftId, msg.sender, true);
    }

    function verifyDraft(uint256 draftId) public onlyRole(CLERK_ROLE) {
        require(landDrafts[draftId].status == DraftStatus.PENDING, "Draft not in pending status");
        require(landDrafts[draftId].ownerApproved, "Owner has not approved the draft");
        // Witness approval is now optional - removed this requirement
        require(bytes(landDrafts[draftId].ipfsHash).length > 0, "Documents not attached");
        
        uint256 officialId = addressToOfficialId[msg.sender];
        require(officialId != 0, "Official not registered");
        
        landDrafts[draftId].status = DraftStatus.VERIFIED;
        landDrafts[draftId].verifiedBy = officialId;
        officials[officialId].lastActivity = block.timestamp;
        
        emit DraftVerified(draftId, msg.sender);
    }

    function approveDraft(uint256 draftId) public onlyRole(TEHSILDAR_ROLE) {
        require(landDrafts[draftId].status == DraftStatus.VERIFIED, "Draft not verified by clerk");
        
        uint256 officialId = addressToOfficialId[msg.sender];
        require(officialId != 0, "Official not registered");
        
        landDrafts[draftId].status = DraftStatus.APPROVED;
        landDrafts[draftId].approvedBy = officialId;
        officials[officialId].lastActivity = block.timestamp;
        
        emit DraftApproved(draftId, msg.sender);
    }

    function rejectDraft(uint256 draftId, string memory reason) public onlyRole(TEHSILDAR_ROLE) {
        require(landDrafts[draftId].status == DraftStatus.VERIFIED, "Draft not verified by clerk");
        
        uint256 officialId = addressToOfficialId[msg.sender];
        require(officialId != 0, "Official not registered");
        
        landDrafts[draftId].status = DraftStatus.REJECTED;
        landDrafts[draftId].rejectedBy = officialId;
        landDrafts[draftId].rejectionReason = reason;
        officials[officialId].lastActivity = block.timestamp;
        
        emit DraftRejected(draftId, msg.sender, reason);
    }

    function mintLandNFT(uint256 draftId) public onlyRole(REGISTRAR_ROLE) {
        require(landDrafts[draftId].status == DraftStatus.APPROVED, "Draft not approved by tehsildar");
        require(!_draftMinted(draftId), "Land already minted as NFT");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        address owner = landDrafts[draftId].currentOwner;
        
        _safeMint(owner, tokenId);
        _setTokenURI(tokenId, string(abi.encodePacked("ipfs://", landDrafts[draftId].ipfsHash)));
        
        landDrafts[draftId].status = DraftStatus.MINTED;
        owners[owner].ownedTokens.push(tokenId);
        owners[owner].lastActivity = block.timestamp;
        
        uint256 officialId = addressToOfficialId[msg.sender];
        officials[officialId].lastActivity = block.timestamp;
        
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
        string memory ipfsHash
    ) public {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        require(newOwner != address(0), "Zero address");
        require(owners[newOwner].walletAddress == newOwner, "Not registered");
        _validateIPFSHash(ipfsHash);
        
        uint256 transferId = _transferIdCounter.current();
        _transferIdCounter.increment();
        
        transferRequests[transferId] = TransferRequest({
            tokenId: tokenId,
            currentOwner: msg.sender,
            newOwner: newOwner,
            propertyAddress: propertyAddress,
            propertyType: propertyType,
            ipfsHash: ipfsHash,
            sellerWitnessApproved: false,
            buyerWitnessApproved: false,
            clerkVerified: false,
            tehsildarVerified: false,
            status: TransferStatus.PENDING,
            initiatedAt: block.timestamp,
            verifiedBy: 0,
            approvedBy: 0,
            rejectedBy: 0,
            rejectionReason: "",
            sellerWitnesses: new address[](0),
            buyerWitnesses: new address[](0)
        });
        
        owners[msg.sender].transferHistory.push(transferId);
        owners[newOwner].transferHistory.push(transferId);
        owners[msg.sender].lastActivity = block.timestamp;
        owners[newOwner].lastActivity = block.timestamp;
        
        emit TransferInitiated(transferId, tokenId, newOwner);
    }

    function addWitness(uint256 tokenId, address witness, bool isBuyerWitness) public {
        require(ownerOf(tokenId) == msg.sender, "Not the owner of this land NFT");
        require(hasRole(WITNESS_ROLE, witness), "Address is not a registered witness");
        
        if (isBuyerWitness) {
            transferRequests[_getLatestTransferForToken(tokenId)].buyerWitnesses.push(witness);
        } else {
            transferRequests[_getLatestTransferForToken(tokenId)].sellerWitnesses.push(witness);
        }
        
        tokenToWitnesses[tokenId].push(witness);
        witnesses[witness].witnessedTokens.push(tokenId);
        witnesses[witness].lastActivity = block.timestamp;
        
        emit WitnessAdded(tokenId, witness);
    }

    function approveTransferAsSellerWitness(uint256 transferId) public onlyRole(WITNESS_ROLE) {
        TransferRequest storage request = transferRequests[transferId];
        require(request.status == TransferStatus.PENDING, "Transfer not in pending status");
        
        bool isWitness = false;
        for (uint i = 0; i < request.sellerWitnesses.length; i++) {
            if (request.sellerWitnesses[i] == msg.sender) {
                isWitness = true;
                break;
            }
        }
        require(isWitness, "Not a seller witness for this property");
        
        request.sellerWitnessApproved = true;
        witnesses[msg.sender].lastActivity = block.timestamp;
        
        emit SellerWitnessApproval(transferId, msg.sender, true);
    }

    function approveTransferAsBuyerWitness(uint256 transferId) public onlyRole(WITNESS_ROLE) {
        TransferRequest storage request = transferRequests[transferId];
        require(request.status == TransferStatus.PENDING, "Transfer not in pending status");
        
        bool isWitness = false;
        for (uint i = 0; i < request.buyerWitnesses.length; i++) {
            if (request.buyerWitnesses[i] == msg.sender) {
                isWitness = true;
                break;
            }
        }
        require(isWitness, "Not a buyer witness for this property");
        
        request.buyerWitnessApproved = true;
        witnesses[msg.sender].lastActivity = block.timestamp;
        
        emit BuyerWitnessApproval(transferId, msg.sender, true);
    }

    function verifyTransfer(uint256 transferId) public onlyRole(CLERK_ROLE) {
        TransferRequest storage request = transferRequests[transferId];
        require(request.status == TransferStatus.PENDING, "Transfer not in pending status");
        // Witness approvals are now optional - removed these requirements
        // require(request.sellerWitnessApproved, "Seller witnesses not approved");
        // require(request.buyerWitnessApproved, "Buyer witnesses not approved");
        require(bytes(request.ipfsHash).length > 0, "Transfer documents missing");
        
        uint256 officialId = addressToOfficialId[msg.sender];
        require(officialId != 0, "Official not registered");
        
        request.clerkVerified = true;
        request.status = TransferStatus.VERIFIED;
        request.verifiedBy = officialId;
        officials[officialId].lastActivity = block.timestamp;
        
        emit TransferVerified(transferId, msg.sender);
    }

    function approveTransfer(uint256 transferId) public onlyRole(TEHSILDAR_ROLE) {
        TransferRequest storage request = transferRequests[transferId];
        require(request.status == TransferStatus.VERIFIED, "Transfer not verified by clerk");
        
        uint256 officialId = addressToOfficialId[msg.sender];
        require(officialId != 0, "Official not registered");
        
        request.tehsildarVerified = true;
        request.status = TransferStatus.APPROVED;
        request.approvedBy = officialId;
        officials[officialId].lastActivity = block.timestamp;
        
        emit TransferApproved(transferId, msg.sender);
    }

    function rejectTransfer(uint256 transferId, string memory reason) public onlyRole(TEHSILDAR_ROLE) {
        TransferRequest storage request = transferRequests[transferId];
        require(request.status == TransferStatus.VERIFIED, "Transfer not verified by clerk");
        
        uint256 officialId = addressToOfficialId[msg.sender];
        require(officialId != 0, "Official not registered");
        
        request.status = TransferStatus.REJECTED;
        request.rejectedBy = officialId;
        request.rejectionReason = reason;
        officials[officialId].lastActivity = block.timestamp;
        
        emit TransferRejected(transferId, msg.sender, reason);
    }

    function completeTransfer(uint256 transferId) public {
        TransferRequest storage request = transferRequests[transferId];
        require(request.status == TransferStatus.APPROVED, "Transfer not approved by tehsildar");
        require(ownerOf(request.tokenId) == request.currentOwner, "Current owner mismatch");
        
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

    function getTransferRequest(uint256 transferId) public view returns (TransferRequest memory) {
        return transferRequests[transferId];
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

    function getTokenWitnesses(uint256 tokenId) public view returns (address[] memory) {
        return tokenToWitnesses[tokenId];
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
    
    function getWitness(address witnessAddress) public view returns (Witness memory) {
        return witnesses[witnessAddress];
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
        require(bytes(hash).length == 46, "Invalid IPFS hash length");
        require(bytes(hash)[0] == 'Q' && bytes(hash)[1] == 'm', "Invalid IPFS hash prefix");
    }

    function _getLatestTransferForToken(uint256 tokenId) internal view returns (uint256) {
        uint256 latestTransferId = 0;
        uint256 latestTimestamp = 0;
        
        for (uint256 i = 0; i < _transferIdCounter.current(); i++) {
            if (transferRequests[i].tokenId == tokenId && 
                transferRequests[i].initiatedAt > latestTimestamp) {
                latestTransferId = i;
                latestTimestamp = transferRequests[i].initiatedAt;
            }
        }
        
        return latestTransferId;
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