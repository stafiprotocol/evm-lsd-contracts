// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./StakePool.sol";
import "./StakeManager.sol";
import "../LsdToken.sol";
import "../Timelock.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/ILsdNetworkFactory.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LsdNetworkFactory is Initializable, UUPSUpgradeable, ILsdNetworkFactory {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public stakeManagerLogicAddress;
    address public stakePoolLogicAddress;

    address public factoryAdmin;
    mapping(address => NetworkContracts) public networkContractsOfLsdToken;
    mapping(address => uint256) public totalClaimedLsdToken;
    mapping(address => address[]) private lsdTokensOf;
    EnumerableSet.AddressSet private entrustedLsdTokens;

    modifier onlyFactoryAdmin() {
        if (msg.sender != factoryAdmin) {
            revert NotFactoryAdmin();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _factoryAdmin,
        address _stakeManagerLogicAddress,
        address _stakePoolLogicAddress
    ) external initializer {
        if (_factoryAdmin == address(0)) {
            revert AddressNotAllowed();
        }

        factoryAdmin = _factoryAdmin;
        stakeManagerLogicAddress = _stakeManagerLogicAddress;
        stakePoolLogicAddress = _stakePoolLogicAddress;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyFactoryAdmin {}

    // ------------ getter ------------

    function lsdTokensOfCreater(address _creater) public view returns (address[] memory) {
        uint256 length = lsdTokensOf[_creater].length;
        address[] memory list = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            list[i] = lsdTokensOf[_creater][i];
        }
        return list;
    }

    // ------------ settings ------------

    function transferOwnership(address _newAdmin) public onlyFactoryAdmin {
        if (_newAdmin == address(0)) {
            revert AddressNotAllowed();
        }

        factoryAdmin = _newAdmin;
    }

    function setStakeManagerLogicAddress(address _stakeManagerLogicAddress) public onlyFactoryAdmin {
        stakeManagerLogicAddress = _stakeManagerLogicAddress;
    }

    function setStakePoolLogicAddress(address _stakePoolLogicAddress) public onlyFactoryAdmin {
        stakePoolLogicAddress = _stakePoolLogicAddress;
    }

    function factoryClaim(address _lsdToken, address _recipient, uint256 _amount) external onlyFactoryAdmin {
        IERC20(_lsdToken).safeTransfer(_recipient, _amount);
        totalClaimedLsdToken[_lsdToken] += _amount;
    }

    function getEntrustedLsdTokens() public view returns (address[] memory) {
        uint256 length = entrustedLsdTokens.length();
        address[] memory list = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            list[i] = entrustedLsdTokens.at(i);
        }
        return list;
    }

    function addEntrustedLsdToken(address _lsdToken) external onlyFactoryAdmin returns (bool) {
        return entrustedLsdTokens.add(_lsdToken);
    }

    function removeEntrustedLsdToken(address _lsdToken) external onlyFactoryAdmin returns (bool) {
        return entrustedLsdTokens.remove(_lsdToken);
    }

    // ------------ user ------------

    function createLsdNetwork(
        string memory _lsdTokenName,
        string memory _lsdTokenSymbol,
        string[] memory _validators
    ) external override {
        _createLsdNetwork(_lsdTokenName, _lsdTokenSymbol, _validators, msg.sender);
    }

    function createLsdNetworkWithTimelock(
        string memory _lsdTokenName,
        string memory _lsdTokenSymbol,
        string[] memory _validators,
        uint256 minDelay,
        address[] memory proposers
    ) external override {
        address networkAdmin = address(new Timelock(minDelay, proposers, proposers, msg.sender));
        _createLsdNetwork(_lsdTokenName, _lsdTokenSymbol, _validators, networkAdmin);
    }

    // ------------ helper ------------

    function _createLsdNetwork(
        string memory _lsdTokenName,
        string memory _lsdTokenSymbol,
        string[] memory _validators,
        address _networkAdmin
    ) private {
        NetworkContracts memory contracts = deployNetworkContracts(_lsdTokenName, _lsdTokenSymbol);
        networkContractsOfLsdToken[contracts._lsdToken] = contracts;
        lsdTokensOf[msg.sender].push(contracts._lsdToken);

        (bool success, bytes memory data) = contracts._stakePool.call(
            abi.encodeWithSelector(StakePool.initialize.selector, contracts._stakeManager, _networkAdmin)
        );
        if (!success) {
            revert FailedToCall();
        }

        (success, data) = contracts._stakeManager.call(
            abi.encodeWithSelector(
                StakeManager.initialize.selector,
                contracts._lsdToken,
                contracts._stakePool,
                _validators,
                _networkAdmin,
                this
            )
        );
        if (!success) {
            revert FailedToCall();
        }

        emit LsdNetwork(contracts);
    }

    function deploy(address _logicAddress) private returns (address) {
        return address(new ERC1967Proxy(_logicAddress, ""));
    }

    function deployNetworkContracts(
        string memory _lsdTokenName,
        string memory _lsdTokenSymbol
    ) private returns (NetworkContracts memory) {
        address stakeManager = deploy(stakeManagerLogicAddress);
        address stakePool = deploy(stakePoolLogicAddress);

        address lsdToken = address(new LsdToken(stakeManager, _lsdTokenName, _lsdTokenSymbol));

        return NetworkContracts(stakeManager, stakePool, lsdToken, block.number);
    }
}
