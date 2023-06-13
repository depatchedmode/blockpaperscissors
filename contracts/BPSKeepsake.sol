// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import "./BlockPaperScissors.sol";

contract BPSKeepsake is ERC721, ERC721Enumerable, Pausable, Ownable, ERC721Burnable {
    using Strings for uint256;
    using Strings for uint16;
    using Strings for uint8;
    using Strings for address;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    BlockPaperScissors public game;
    IERC20 private quarterToken;
    uint256 private _currentTokenId = 0;
    uint8 private constant CANVAS_SIZE = 64;

    // Mapping of tokenId to various attributes
    mapping(uint256 => TokenAttributes) private tokenAttributesById;
    mapping(uint256 => uint256) private realityIdByBlockheight;
    mapping(uint256 => uint256) private planIdByBlockheight;
    mapping(uint256 => uint256) private timelessnessByMoves;

    enum TokenTypes {
        PLAN, 
        REALITY
    }

    struct TokenAttributes {
        TokenTypes tokenType;
        uint256 executionBlock;
        uint256 mintedAtBlock;
        address mintedBy;

        // Plan Only
        address architect;
        uint256 futurity;
        uint256 belief;
        uint256 moves;

        // Reality Only
        uint256 nostalgia;
        uint16 entrainment; // max 4096
    }

    constructor(address _quarterToken, address _gameState) ERC721("BPSKeepsake", "BPS") {
        quarterToken = IERC20(_quarterToken);
        game = BlockPaperScissors(_gameState);
    }

    function mint(address _to, TokenTypes _tokenType, uint256 _executionBlock, uint256 _moves) public {
        // check to make sure there is an address
        // check to make sure 
        uint256 tokenId = _tokenIdCounter.current();
        BlockPaperScissors.User memory user = game.getUserByAddress(_to);

        if (_tokenType == TokenTypes.PLAN) {
            // make sure the executionBlock is greater than block.number
            // error: a PLAN token must target an future block
            // make sure that _moves is defined
            // error: you need to submit the MOVES involved in your plan
        } else if (_tokenType == TokenTypes.REALITY) {
            // make sure execution block is equal or less than block.number 
            // error: a REALITY token must target an already completed block
            // see if this block height has already been minted: reality can only be minted once
        } else {
            // error: you need to specify a token type
        }

        // check if the plan exists
        TokenAttributes storage tokenData = tokenAttributesById[tokenId];
        tokenData.tokenType = _tokenType;
        tokenData.mintedAtBlock = block.number;
        tokenData.mintedBy = _to;
        tokenData.architect = user.accountAddress;

        if (_tokenType == TokenTypes.PLAN) {
            timelessnessByMoves[_moves]++;
            tokenData.moves = _moves;
        } else if (_tokenType == TokenTypes.REALITY) {
            // Get the account state. We need this to calculate beliefScore
            // BlockPaperScissors.AccountState memory accountState = game.singleAccountState();
        }

        // Get the game state. We need this for everything else.
        // VotesWithResultsInBlock[] memory gameState = game.historyForRange(CANVAS_SIZE, block.number);

        // Mint the token
        _tokenIdCounter.increment();
        _safeMint(_to, tokenId);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address _from, address _to, uint256 _tokenId, uint256 _batchSize)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(_from, _to, _tokenId, _batchSize);
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _createTokenName(TokenAttributes memory _attrs) internal pure returns (string memory) {
        // plans are named
        string memory tokenTypeLabel;
        string memory variantLabel;
        string memory editionCount;

        if (_attrs.tokenType == TokenTypes.PLAN) {
            editionCount = string(abi.encodePacked("1", "/","3"));
            variantLabel = "3";
            tokenTypeLabel = string(abi.encodePacked("Plan #", variantLabel, "3"));
        } else {
            editionCount = string(abi.encodePacked("1", "/","3"));
            tokenTypeLabel = string(abi.encodePacked("Reality ", editionCount));
        }

        return string(abi.encodePacked(_attrs.executionBlock.toString(), "(", tokenTypeLabel, ")"));
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        
        TokenAttributes memory attrs = tokenAttributesById[_tokenId];
        
        string memory name = _createTokenName(attrs);
        string memory description = "An NFT collection of potentially immeasurable value.";
        string memory image = _renderCanvas(_tokenId);

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        "{",
                            '"name": "', name, '",',
                            '"description": "', description, '",',
                            '", "image": "', image,'",',
                            '"attributes": [',getAttributesJSON(attrs),']',
                        "}"
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function render(uint256 tokenId) public view returns (string memory) {
        return _renderCanvas(tokenId);
    }

    function _getRealityMoves(uint256 _block) internal view returns (uint256) {
        uint256 moves = 9 * 10 ** 64; // init with a 9 in the starting position
        uint256 currPosition = _block % CANVAS_SIZE;
        uint256 startingBlock = _block - currPosition;
        uint256 endingBlock = startingBlock + CANVAS_SIZE;

        BlockPaperScissors.BlockResult memory blockResult;

        for(uint256 i = 0; i < CANVAS_SIZE; i++) {
            blockResult = game.getBlockResult(startingBlock+i);
            if (blockResult.blockHeight > 0) {
                moves += uint(blockResult.winningMove) * 10 ** i;
            }
        }

        return moves;
    }

    function _renderCanvas(uint256 _tokenId) internal view returns (string memory) {
        require(_exists(_tokenId), "No token");

        TokenAttributes storage currToken = tokenAttributesById[_tokenId];

        uint256 moves = currToken.tokenType == TokenTypes.PLAN ?
            currToken.moves :
            _getRealityMoves(currToken.executionBlock);

        string memory cells = "";
        uint row;
        uint digit;
        uint color;
        for(uint i = 0; i < CANVAS_SIZE; i++) {
            digit = 10 ** i;
            row = i / 8;
            color = (moves / digit) % 10;
            cells = string(abi.encodePacked(cells, _renderCell(i % 8,row,color)));
        }

        string memory encoded = Base64.encode(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">',
                    cells,
                '</svg>'
            )
        );
        return string(abi.encodePacked("data:image/svg+xml;base64,", encoded));
    }

    function _renderCell(uint _x, uint _y, uint _color) internal pure returns (string memory) {
        string[4] memory colors = [ "#E2285F", "#1FB229", "#6363F2", "#F1EDDA"];
        uint xPos = _x * 8;
        uint yPos = _y * 8;
        return string(abi.encodePacked('<rect fill="',colors[_color],'" width="12.5%" height="12.5%" x="',xPos.toString(),'" y="',yPos.toString(),'" />'));
    }

    function getAttributesJSON(TokenAttributes memory _attrs) private pure returns (string memory) {
        string memory tokenType = _attrs.tokenType == TokenTypes.PLAN ? "Plan" : "Reality";
        return string(
            abi.encodePacked(
                '{',
                    '"tokenType": "', tokenType, '",',
                    '"moves": "', _attrs.moves.toString(), '",',
                    '"executionBlock": "', _attrs.executionBlock.toString(), '",',
                    '"mintedAtBlock": "', _attrs.mintedAtBlock.toString(), '",',
                    '"mintedBy": "', _attrs.mintedBy.toHexString(), '",',
                    '"architect": "', _attrs.architect.toHexString(), '",',
                    '"futurity": "', _attrs.futurity.toString(), '",',
                    '"belief": "', _attrs.belief.toString(), '",',
                    '"nostalgia": "', _attrs.nostalgia.toString(), '",',
                    '"entrainment": "', _attrs.entrainment.toString(), '",',
                '}'
            )
        );
    }

}