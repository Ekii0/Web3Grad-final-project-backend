//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "base64-sol/base64.sol";

error CaseManager__CaseAlreadyExists();
error CaseManager__TransferNotAllowed();
error CaseManager__RecipientHasNoRole();

/// @title  Case Manager of the Evidence Management System
/// @author ekiio
/// @notice This contract is the central piece of the evidence management
///         systems. Users will be able to open a new case, given the
///         addresses of the dispute party and a case name (which can be
///         an official tracking number to make it a unique identifier).
///         Once a case has been created, the dispute parties will be issued
///         an access NFT with a unique token ID hat allows for access control,
///         differentiating of roles (party or juror) in the case, and -
///         ultimately - the encryption and decryption of files uploaded on the
///         frontend to IPFS, using the functionality provided by Lit Protocol.
contract CaseManager is ERC1155, ERC1155URIStorage, Ownable {
    // Types

    enum Role {
        // used to create different access tokens accoring to role
        UNASSIGNED,
        PARTY,
        JUROR
    }

    // State variables

    address private immutable i_owner;

    uint256 private s_tokenId;
    string private s_baseURI;

    mapping(uint32 => bool) private caseExists;
    mapping(address => uint256) private hasRole;

    // Events

    event NewCaseOpened(address _partyA, address _partyB, uint32 _caseId);

    // Functions

    constructor(string memory _baseURI) ERC1155(_baseURI) {
        i_owner = msg.sender;
        s_baseURI = _baseURI;
    }

    /// @dev    Called by frontend to open a new case. Creates a unique case ID
    ///         from the address of the parties as well as a short string which
    ///         is given to the case, e.g. an official case tracking number or
    ///         other unique identifier. The last 9 digits of this hash will
    ///         become the unique caseId. Throws an error when case already
    ///         exists. Creates internal records and finally calls the method
    ///         that will mint the unique access token for the evidence
    ///         submission data room.
    /// @notice Following convention of naming cases. "A v B" and "B v A" are
    ///         to be treated as two separate cases, so parties A and B are
    ///         not interchangable.
    function openCase(
        address _partyA,
        address _partyB,
        string memory _caseName
    ) external returns (uint32 caseId) {
        uint256 hashValue = uint256(
            keccak256(abi.encodePacked(_partyA, _partyB, _caseName))
        ) % 10 ** 9;
        caseId = uint32(hashValue);
        /*  if (caseExists[caseId]) {
            revert CaseManager__CaseAlreadyExists();
        } */
        require(!caseExists[caseId], "Case already exists!");
        caseExists[caseId] = true;
        hasRole[_partyA] = uint256(Role.PARTY);
        hasRole[_partyB] = uint256(Role.PARTY);
        _sendAccessToken(_partyA, caseId);
        _sendAccessToken(_partyB, caseId);
        emit NewCaseOpened(_partyA, _partyB, caseId);
        return caseId;
    }

    /// @dev Simple getter function for the frontend to check if a user tries
    ///      to open a case with the same parameters twice.
    function doesCaseExist(uint32 _hash) external view returns (bool) {
        return caseExists[_hash];
    }

    /// @dev Gets the unique tokenId for the corresponding caseId and
    ///      respective role of the receiver, and then mints the access token.
    function _sendAccessToken(address _to, uint32 _caseId) internal {
        uint256 _tokenId = _createTokenId(_caseId, _to);
        _mint(_to, _tokenId, 1, "");
    }

    /// @dev To make the code clearer and support code reuse, this function
    ///      creates a unique token ID from the case ID and the receiver's
    ///      role. Token IDs ending in "1" are the evidence submitting parties,
    ///      those ending in "2" are the NFTs for jurors assigned to this case.
    function _createTokenId(
        uint32 _caseId,
        address _recipient
    ) internal view returns (uint256 tokenId) {
        if (hasRole[_recipient] == uint256(Role.PARTY)) {
            return uint256(_caseId) * 10 + uint256(Role.PARTY);
        } else if (hasRole[_recipient] == uint256(Role.JUROR)) {
            return uint256(_caseId) * 10 + uint256(Role.JUROR);
        } else {
            revert CaseManager__RecipientHasNoRole();
        }
    }

    /// @dev If a new storage address needs to be set, this function will
    ///      update the address at which the token images will be stored.
    function setURI(string memory _newURI) public onlyOwner {
        s_baseURI = _newURI;
    }

    /// @dev    Sets token metadata. All relevant access data can already be
    ///         deducted from the tokenId but for extra clarity and security,
    ///         having the metadata on chain might help.
    /// @notice Image URL will have a simple icon depicting the role, i.e. have
    ///         a document icon for the parties, and a judge's gavel for jurors
    function uri(
        uint256 _tokenid
    ) public view override(ERC1155, ERC1155URIStorage) returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"Evidence Management Access Token"',
                                '"description":"Grants access to the Evidence Management System", ',
                                '"properties": {"case_id":"',
                                abi.encodePacked(
                                    Strings.toString(_tokenid / 10)
                                ),
                                '", "role":"',
                                abi.encodePacked(
                                    Strings.toString(_tokenid % 10)
                                ),
                                '"}, "image":"',
                                abi.encodePacked(
                                    string.concat(
                                        s_baseURI,
                                        Strings.toString(_tokenid % 10)
                                    )
                                ),
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    // functions required to make the NFT soulbound, i.e. non-transferrable

    function setApprovalForAll(address, bool) public pure override {
        revert CaseManager__TransferNotAllowed();
    }

    function safeTransferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure override {
        revert CaseManager__TransferNotAllowed();
    }

    /*ToDo: - Function to randomly select jury members from a panel (using
              Chainlink VRF).
            - maybe functionality to get a case report, i.e. have a data struct
              "Case" that contains the address of the dispute parties, the name
              of the case, addresses of selected jurors and timestamp. Mapping 
              of caseIds to the Case structs.
            - making the openNewCase function payable. Using either an update
              function or price oracles to be able to set adequate fees.
     */
}
