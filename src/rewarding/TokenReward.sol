// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AccessRestriction } from "../accessRistriction/AccessRestriction.sol";

contract MTXReward is ReentrancyGuard {
    using ECDSA for bytes32;

    IERC20 public mtxToken;
    AccessRestriction public accessRestriction;

    address public rewardSigner;

    bytes32 public immutable DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    bytes32 private constant REWARD_TYPEHASH =
        keccak256(
            "Reward(address user,uint256 amount,uint256 nonce)"
        );

    struct Reward {
        address user;
        uint256 amount;
        uint256 nonce;
    }

    event RewardClaimed(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed nonce
    );

    event RewardSignerUpdated(
        address indexed oldSigner,
        address indexed newSigner
    );

    modifier onlyAdmin() {
        require(
            accessRestriction.hasRole(
                accessRestriction.ADMIN_ROLE(),
                msg.sender
            ),
            "Caller not admin"
        );
        _;
    }

    constructor(
        address _token,
        address _accessRestriction,
        address _rewardSigner,
        string memory name,
        string memory version
    ) {
        require(
            _token != address(0) &&
            _accessRestriction != address(0) &&
            _rewardSigner != address(0),
            "InvalidAddress"
        );

        mtxToken = IERC20(_token);
        accessRestriction = AccessRestriction(_accessRestriction);
        rewardSigner = _rewardSigner;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(this)
            )
        );
    }

    function setRewardSigner(address newSigner) external onlyAdmin {
        require(newSigner != address(0), "InvalidAddress");

        address oldSigner = rewardSigner;
        rewardSigner = newSigner;

        emit RewardSignerUpdated(oldSigner, newSigner);
    }

    function withdrawRemainingTokens(address to) external onlyAdmin {
        uint256 balance = mtxToken.balanceOf(address(this));
        require(balance != 0, "NothingToWithdraw");

        bool success = mtxToken.transfer(to, balance);
        require(success, "TransferFailed");
    }

    function claimReward(
        Reward calldata reward,
        bytes calldata signature
    ) external nonReentrant {
        require(reward.user == msg.sender, "InvalidUser");
        require(reward.nonce == nonces[msg.sender], "InvalidNonce");
        require(reward.amount != 0, "InvalidAmount");

        bytes32 structHash = keccak256(
            abi.encode(
                REWARD_TYPEHASH,
                reward.user,
                reward.amount,
                reward.nonce
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        address signer = digest.recover(signature);

        require(signer == rewardSigner, "InvalidSignature");

        nonces[msg.sender] += 1;

        bool success = mtxToken.transfer(msg.sender, reward.amount);

        require(success, "TransferFailed");

        emit RewardClaimed(
            msg.sender,
            reward.amount,
            reward.nonce
        );
    }
}
