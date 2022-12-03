// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.15;

import {Clones} from "openzeppelin-contracts/proxy/Clones.sol";
import {IcfaV1Forwarder, ISuperToken, ISuperfluid, IConstantFlowAgreementV1} from "./interfaces/IcfaV1Forwarder.sol";
import {IInstantDistributionAgreementV1} from "protocol-monorepo/packages/ethereum-contracts/contracts/interfaces/agreements/IInstantDistributionAgreementV1.sol";
import {IConstantFlowAgreementV1} from "protocol-monorepo/packages/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {StreamManager} from "./StreamManager.sol";
import {SocialToken} from "./SocialToken.sol";
import {StakingContract} from "./StakingContract.sol";
import "forge-std/console.sol";

contract SuperLensFactory {
    struct CreatorSet {
        address streamManager;
        address socialToken;
        address stakingContract;
    }

    error ZeroAddress();
    error InvalidStrings();
    error InvalidPaymentFlowrate(int96 paymentFlowrate);
    error CreatorSetExists(address creator);

    event NewCreatorSet(
        address indexed creator,
        address streamManager,
        address socialToken,
        address stakingContract
    );

    address public immutable CFA;
    address public immutable IDA;
    address public immutable FORWARDER;
    address public immutable HOST;
    address public immutable SUPERTOKEN_FACTORY;

    address public streamManagerImplementation;
    address public socialTokenImplementation;
    address public stakingContractImplementation;

    // Creator => { StreamManager, SocialToken, StakingContract }
    mapping(address => CreatorSet) public creatorSet;

    constructor(
        address _host,
        address _cfa,
        address _ida,
        address _cfaV1Forwarder,
        address _superTokenFactory,
        address _streamManagerImplementation,
        address _socialTokenImplementation,
        address _stakingContractImplementation
    ) {
        if (
            _cfaV1Forwarder == address(0) ||
            _host == address(0) ||
            _cfa == address(0) ||
            _streamManagerImplementation == address(0) ||
            _socialTokenImplementation == address(0) ||
            _stakingContractImplementation == address(0)
        ) revert ZeroAddress();

        FORWARDER = _cfaV1Forwarder;
        HOST = _host;
        CFA = _cfa;
        IDA = _ida;
        SUPERTOKEN_FACTORY = _superTokenFactory;
        streamManagerImplementation = _streamManagerImplementation;
        socialTokenImplementation = _socialTokenImplementation;
        stakingContractImplementation = _stakingContractImplementation;
    }

    function initCreatorSet(
        address _paymentToken,
        int96 _paymentFlowrate,
        string memory _stName,
        string memory _stSymbol,
        uint256 _initSupply
    )
        external
    {
        if (_paymentToken == address(0)) revert ZeroAddress();
        if (_paymentFlowrate < 0)
            revert InvalidPaymentFlowrate(_paymentFlowrate);
        if (bytes(_stName).length == 0 || bytes(_stSymbol).length == 0)
            revert InvalidStrings();
        if (creatorSet[msg.sender].streamManager != address(0))
            revert CreatorSetExists(msg.sender);

        address newStreamManager = Clones.clone(streamManagerImplementation);
        address payable newSocialToken = payable(
            Clones.clone(socialTokenImplementation)
        );
        address newStakingContract = Clones.clone(
            stakingContractImplementation
        );

        creatorSet[msg.sender] = CreatorSet({
            streamManager: newStreamManager,
            socialToken: newSocialToken,
            stakingContract: newStakingContract
        });
        
        StreamManager(newStreamManager).initialize(
            msg.sender,
            _paymentToken,
            newSocialToken,
            newStakingContract,
            FORWARDER,
            HOST,
            CFA,
            _paymentFlowrate
        );

        SocialToken(newSocialToken).initialize(
            SUPERTOKEN_FACTORY,
            _stName,
            _stSymbol,
            newSocialToken,
            _initSupply,
            newStreamManager,
            FORWARDER
        );

        StakingContract(newStakingContract).initialize(
            ISuperfluid(HOST),
            IInstantDistributionAgreementV1(IDA),
            ISuperToken(_paymentToken),
            ISuperToken(newSocialToken)
        );

        emit NewCreatorSet(
            msg.sender,
            newStreamManager,
            newSocialToken,
            newStakingContract
        );
    }
}
