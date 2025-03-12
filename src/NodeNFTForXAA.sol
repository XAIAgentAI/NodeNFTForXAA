// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/console.sol";

/// @custom:oz-upgrades-from OldNodeNFTForXAA
contract NodeNFTForXAA is Initializable, ERC1155Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public constant MAX_LEVEL = 3;

    string private _name;
    string private _symbol;

    struct LevelConfig {
        uint256 maxSupply; // Maximum supply for this level
        uint256 minted; // Number of tokens minted for this level
    }

    mapping(uint256 => LevelConfig) public levels; // Level configurations (1-3)
    mapping(address => mapping(uint256 => bool)) public minter2MintLevel; // Authorization for minters

    mapping(address => uint256[]) public address2TokenIds;

    address public canUpgradeAddress;

    event Minted(address indexed to, uint256 level, uint256 amount);

    function initialize(address initialOwner) public initializer {
        __ERC1155_init(
            "https://raw.githubusercontent.com/XAIAgentAI/NodeNFTForXAA/main/resource/metadata/{id}.json"
        );
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        _name = "Node NFT For XAA";
        _symbol = "NFFX";
        canUpgradeAddress = msg.sender;
        setLevelConfigs();

        minter2MintLevel[msg.sender][1] = true;
        minter2MintLevel[msg.sender][2] = true;
        minter2MintLevel[msg.sender][3] = true;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        require(newImplementation != address(0), "Invalid implementation address");
        require(msg.sender == canUpgradeAddress || msg.sender == owner(), "Only canUpgradeAddress can upgrade");
    }

    function setCanUpgradeAddress(address addr) internal onlyOwner {
        canUpgradeAddress = addr;
    }

    modifier onlyMinterForLevel(uint256[] memory _levels) {
        for (uint256 i = 0; i < _levels.length; i++) {
            uint256 level = _levels[i];
            require(level >= 1 && level <= MAX_LEVEL, "Invalid level");
            require(hasMintAuthorization(msg.sender, level), "Not authorized to mint this level");
        }
        _;
    }

    function hasMintAuthorization(address addr, uint256 level) internal view returns (bool) {
        return minter2MintLevel[addr][level];
    }

    function setLevelConfigs() internal onlyOwner {
        levels[1] = LevelConfig(4000, 0);
        levels[2] = LevelConfig(6000, 0);
        levels[3] = LevelConfig(10000, 0);
    }

    function batchMint(address to, uint256[] memory _levels, uint256[] memory amounts)
    public
    onlyMinterForLevel(_levels)
    {
        require(_levels.length == amounts.length, "Invalid input");
        for (uint256 i = 0; i < _levels.length; i++) {
            uint256 level = _levels[i];
            uint256 amount = amounts[i];
            require(level >= 1 && level <= MAX_LEVEL, "Invalid level");
            LevelConfig storage config = levels[level];
            require(config.minted + amount <= config.maxSupply, "Exceeds max supply for level");

            config.minted += amount;
            _mint(to, level, amount, "");
            emit Minted(to, level, amount);
        }
    }

    function mint(address to, uint256 level, uint256 amount) public {
        require(hasMintAuthorization(msg.sender, level), "Not authorized to mint this level");
        require(level >= 1 && level <= MAX_LEVEL, "Invalid level");
        LevelConfig storage config = levels[level];
        require(config.minted + amount <= config.maxSupply, "Exceeds max supply for level");

        config.minted += amount;
        _mint(to, level, amount, "");
        emit Minted(to, level, amount);
    }

    function setMinterForLevels(address minter, uint256[] calldata levelsToSet) external onlyOwner {
        for (uint256 i = 0; i < levelsToSet.length; i++) {
            uint256 level = levelsToSet[i];
            require(level >= 1 && level <= MAX_LEVEL, "Invalid level");
            minter2MintLevel[minter][level] = true;
        }
    }

    function removeMinterForLevels(address minter, uint256[] calldata levelsToRemove) external onlyOwner {
        for (uint256 i = 0; i < levelsToRemove.length; i++) {
            uint256 level = levelsToRemove[i];
            require(level >= 1 && level <= MAX_LEVEL, "Invalid level");
            minter2MintLevel[minter][level] = false;
        }
    }

    function _baseURI() internal pure returns (string memory) {
        return
            "https://raw.githubusercontent.com/XAIAgentAI/NodeNFTForXAA/main/resource/metadata/";
    }

    function uri(uint256 id) public pure override returns (string memory) {
        require(id >= 1 && id <= MAX_LEVEL, "Invalid token ID");
        return string(abi.encodePacked(_baseURI(), Strings.toString(id), ".json"));
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Upgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getBalance(address owner, uint256 amount)
    public
    view
    returns (uint256[] memory tokenIds, uint256[] memory amounts)
    {
        require(owner != address(0), "Invalid address");
        require(amount > 0, "Amount must be greater than zero");

        uint256[] storage ownedTokenIds = address2TokenIds[owner];
        uint256 ownedCount = ownedTokenIds.length;

        tokenIds = new uint256[](ownedCount);
        amounts = new uint256[](ownedCount);

        uint256 remainingAmount = amount;
        uint256 index = 0;

        for (uint256 i = 0; i < ownedCount; i++) {
            uint256 tokenId = ownedTokenIds[i];
            uint256 balance = balanceOf(owner, tokenId);

            if (balance > 0) {
                if (balance >= remainingAmount) {
                    tokenIds[index] = tokenId;
                    amounts[index] = remainingAmount;
                    index++;
                    break;
                } else {
                    tokenIds[index] = tokenId;
                    amounts[index] = balance;
                    remainingAmount -= balance;
                    index++;
                }
            }

            // Stop if we've fulfilled the required amount
            if (remainingAmount == 0) {
                break;
            }
        }

        // Resize arrays to actual size
        assembly {
            mstore(tokenIds, index)
            mstore(amounts, index)
        }
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory amounts) internal override {
        super._update(from, to, ids, amounts);

        if (from != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];
                if (balanceOf(from, id) == 0) {
                    _removeTokenId(from, id);
                }
            }
        }

        if (to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 id = ids[i];
                if (balanceOf(to, id) > 0) {
                    if (!exits(address2TokenIds[to], id)){
                        address2TokenIds[to].push(id);
                    }
                }
            }
        }
    }

    function _removeTokenId(address account, uint256 id) internal {
        uint256[] storage tokenIds = address2TokenIds[account];
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == id) {
                tokenIds[i] = tokenIds[tokenIds.length - 1];
                tokenIds.pop();
                break;
            }
        }
    }

    function exits(uint256[] memory list, uint256 target) internal pure returns (bool) {
        for (uint256 i = 0; i < list.length; i++) {
            if (list[i] == target) {
                return true;
            }
        }
        return false;
    }

    function version() public pure returns (uint256) {
        return 1;
    }
}
