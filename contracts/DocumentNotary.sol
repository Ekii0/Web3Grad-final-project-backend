// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

error DocumentNotary__DocumentAlreadyExists();
error DocumentNotary__DocumentDoesNotExist();
error DocumentNotary__UserHasNoDocuments();
error DocumentNotary__CaseHasNoDocuments();
error DocumentNotary__DoesNotCoverFees();
error DocumentNotary__NotAuthorized();
error DocumentNotary__RenouncingOwnershipNotAllowed();
error DocumentNotary__Busy();

/// @title  Document Notary - Proof Of Existence
/// @author ekiio
/// @notice A simple contract that stores a file's hash alongside the sender's
///         address, the corresponding case ID and a timestamp in a Document
///         struct. Will proove existence of an untampered file at a specific
///         point in time, which is particularly useful for an evidence
///         management system. A jury will be able to get a collection of facts
///         to a specific case on which they can e.g. vote if the evidence put
///         forth is truthful and will be admitted, e.g. in a court hearing or
///         in an arbitration.
contract DocumentNotary {
    struct Document {
        bytes32 hash;
        address owner;
        uint32 caseId;
        string ipfsHash;
    }

    mapping(uint32 => mapping(bytes32 => Document)) private cabinet;
    mapping(address => bytes32[]) private userDocs;
    mapping(address => bool) private userHasDocs;
    // Note: Some gas can be saved by not using a boolean but a numerical system,
    //       e.g. using 0 for 'false' and 1 for 'true'. I am still using boolean
    //       types here to make the code easier to read. Deploying to a low-cost
    //       L2 network like Polygon, Optimism or Arbitrum, this shouldn't make
    //       too much of a difference.
    mapping(uint32 => bytes32[]) private caseDocs;
    mapping(uint32 => mapping(bytes32 => bool)) private caseHasDocs;

    address private s_owner;
    address private s_caseManagerAddress;
    ERC1155 internal s_caseManager;
    uint256 private s_fee = 0.5 ether; // Set fee to 0.5 MATIC (~ 0.45 USD atm)
    bool private busy;

    event NewDocumentFiled(
        bytes32 indexed _hash,
        uint32 _caseId,
        string _ipfsHash
    );
    event NewCaseManagerAddressSet(address _newCaseManagerAddress);
    event OwnershipTransferred(address _oldOwner, address _newOwner);
    event NewFeeSet(uint256 _newFee);

    modifier onlyOwner() {
        if (msg.sender != s_owner) {
            revert DocumentNotary__NotAuthorized();
        }
        _;
    }

    /// @dev Sets the contract owner's address. Also sets the address to the
    ///      CaseManager contract which is required to check if the user who
    ///      wants to upload files is authorized by the CaseManager contract
    ///      to do so, i.e. that they have the "Party" NFT to the _caseId.
    constructor(address _caseManagerAddress) {
        s_owner = msg.sender;
        s_caseManagerAddress = _caseManagerAddress;
        s_caseManager = ERC1155(s_caseManagerAddress);
    }

    /// @dev Stores a file's hash in the internal file cabinet if it has not
    ///      already been stored. Emits an event that a new Document has been
    ///      registered. Throws an error if the document is already registered.
    ///      Can only be accessed by the parties of the case, so the function
    ///      first checks for ownership of the corresponding NFT.
    ///      Has a simple reentrancy guard that checks if the function has
    ///      already been called and will revert if it is so. The function has
    ///      to do quite a few sanity checks before any operations are done, so
    ///      having a reentrancy guard in place will prevent double storage.
    /// @param _ipfsHash Currently of type string but this is very expensive. A
    ///        better approach for future versions would be to store a bytes32
    ///        type. This would require slicing off the first two bytes of the
    ///        IPFS hash which represent the hash version function, and store
    ///        the remainder in a bytes32 variable.
    ///        See; https://ethereum.stackexchange.com/questions/17094/how-to-store-ipfs-hash-using-bytes32/17112#17112
    function storeDocumentHash(
        bytes32 _hash,
        uint32 _caseId,
        string memory _ipfsHash
    ) external payable {
        if (busy) {
            revert DocumentNotary__Busy();
        }
        busy = true;
        /* if (s_caseManager.balanceOf(msg.sender, (_caseId * 10 + 1)) < 1) {
            revert DocumentNotary__NotAuthorized();
        } */
        if (msg.value < s_fee) {
            revert DocumentNotary__DoesNotCoverFees();
        }
        if (caseHasDocs[_caseId][_hash]) {
            revert DocumentNotary__DocumentAlreadyExists();
        }
        Document memory newDoc = Document(
            _hash,
            msg.sender,
            _caseId,
            _ipfsHash
            //uint64(block.timestamp)
        );

        userHasDocs[msg.sender] = true;
        caseHasDocs[_caseId][_hash] = true;
        cabinet[_caseId][_hash] = newDoc;
        userDocs[msg.sender].push(_hash);
        caseDocs[_caseId].push(_hash);
        busy = false;
        emit NewDocumentFiled(_hash, _caseId, _ipfsHash);
    }

    /// @dev Queries the internal file cabinet for the requested document and
    ///      returns the Document struct with the stored metadata. Throws an
    ///      error if the hash could not be found in internal records.
    function getDocument(
        bytes32 _hash,
        uint32 _caseId
    ) public view returns (Document memory) {
        if (!caseHasDocs[_caseId][_hash]) {
            revert DocumentNotary__DocumentDoesNotExist();
        }
        return cabinet[_caseId][_hash];
    }

    /// @dev Returns all the hashes a user has ever uploaded to the evidence
    ///      management system. This makes it easier to show users of the
    ///      dispute resolution platform all their submitted documents, e.g.
    ///      on their dashboard.
    function getDocumentsByUser(
        address _userAddress
    ) public view returns (bytes32[] memory) {
        if (!userHasDocs[_userAddress]) {
            revert DocumentNotary__UserHasNoDocuments();
        }
        return userDocs[_userAddress];
    }

    /// @dev Returns an array of all document hashes that have been submitted
    ///      for a specific case. This will make presenting all the evidence
    ///      to the jury possible.
    function getDocumentsByCaseId(
        uint32 _caseId
    ) public view returns (bytes32[] memory) {
        if (caseDocs[_caseId].length == 0) {
            revert DocumentNotary__CaseHasNoDocuments();
        }
        return caseDocs[_caseId];
    }

    /// @dev Sets a new CaseManagerAddress to make the contract upgradeable.
    function setCaseManagerAddress(
        address _newCaseManagerAddress
    ) external onlyOwner {
        s_caseManagerAddress = _newCaseManagerAddress;
        s_caseManager = ERC1155(s_caseManagerAddress);
        emit NewCaseManagerAddressSet(_newCaseManagerAddress);
    }

    /// @dev Transfers ownership of contract to new address. Renouncing
    ///      ownership is not allowed and will revert.
    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) {
            revert DocumentNotary__RenouncingOwnershipNotAllowed();
        }
        address _oldOwner = s_owner;
        s_owner = _newOwner;
        emit OwnershipTransferred(_oldOwner, _newOwner);
    }

    /// @dev Sets a new fee to be paid for using the storeDocumentHash function
    function setFee(uint256 _newFee) external onlyOwner {
        s_fee = _newFee;
        emit NewFeeSet(_newFee);
    }

    /// @dev Allows the contract owner to withdraw the contract's entire balance
    function withdrawFunds() external onlyOwner {
        payable(s_owner).transfer(address(this).balance);
    }

    /// @dev Gets the current fee payable for using storeDocumentHash().
    function getFee() public view returns (uint256) {
        return s_fee;
    }

    /* ToDo: - Make storeDocumentHash only be callable by the dispute parties,
               and only within a specified timeframe, otherwise everyone could
               call the function and store documents at any time, even before a
               case has been opened for dispute settlement.
               That is, check if msg.sender has the access NFT.
     */
}
