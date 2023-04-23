// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakeNFT is Ownable {
    using SafeMath for uint256;
    //State variabble
    mapping (address => bool) public collections;
    address public rewardToken;
    mapping(address => uint256) public rates;

    //structs
    struct Staking {
        address staker;
        address collection;
        uint256 tokenId;
        uint256 releaseTime;
        uint256 claimedAmount;
        uint256 stakingId;
    }

    /// @dev current max stakingId
    uint256 public stakingIdPointer;

    //mapping
    mapping(address => uint256) public balances;
    mapping(address => mapping(uint256 => uint256)) _ownedStakings;
    mapping(uint256 => uint256) private _ownedStakingsIndex;
    Staking[] _allStakings;
    mapping(uint256 => uint256) _allStakingIndex;

    //event
    event tokenStaked(address staker, address collection, uint token_id, uint stakingId);
    event tokenRewardClaimed(address staker, address collection, uint256 token_id, uint256 claimedAmount, uint256 stakingId);
    event tokenUnStaked(address staker, address collection, uint token_id, uint stakingId);
    event tokenRenounced(address renounce, uint256 _amount);

    //constructor
    constructor(address _rewardToken){
        rewardToken = _rewardToken;
    }

    function stakingOfOwnerByIndex(address owner, uint256 index) public view returns (uint256) {
        require(index < balances[owner], "owner index out of bounds");
        return _ownedStakings[owner][index];
    }

    function stakingByIndex(uint256 index) public view returns (Staking memory) {
        require(index < totalSupply(), "global index out of bounds");
        return _allStakings[index];
    }

    function stakingById(uint256 stakingId) public view returns (Staking memory) {
        require(stakingId <= stakingIdPointer, "staking id is not valid");
        return _allStakings[_allStakingIndex[stakingId]];
    }

    function _addStakingToOwnerEnumeration(address to, uint256 stakingId) private {
        uint256 length = balances[to];
        _ownedStakings[to][length] = stakingId;
        _ownedStakingsIndex[stakingId] = length;
    }

    function _addStakingToAllStakingsEnumeration(Staking memory staking) private {
        _allStakingIndex[staking.stakingId] = _allStakings.length;
        _allStakings.push(staking);
    }

    function _removeStakingFromOwnerEnumeration(address from, uint256 stakingId) private {
        uint256 lastStakingIndex = balances[from] - 1;
        uint256 stakingIndex = _ownedStakingsIndex[stakingId];

        if (stakingIndex != lastStakingIndex) {
            uint256 lastStakingId = _ownedStakings[from][lastStakingIndex];

            _ownedStakings[from][stakingIndex] = lastStakingId;
            _ownedStakingsIndex[lastStakingId] = stakingIndex;
        }

        delete _ownedStakingsIndex[stakingId];
        delete _ownedStakings[from][lastStakingIndex];
    }

    function _removeStakingFromAllStakingsEnumeration(uint256 stakingId) private {
        uint256 lastStakingIndex = _allStakings.length - 1;
        uint256 stakingIndex = _allStakingIndex[stakingId];

        Staking memory lastStakingInfo = _allStakings[lastStakingIndex];


        _allStakings[stakingIndex] = lastStakingInfo;
        _allStakingIndex[lastStakingInfo.stakingId] = stakingIndex;

        delete _allStakingIndex[stakingId];
        _allStakings.pop();
    }

    function totalSupply() public view returns (uint256) {
        return _allStakings.length;
    }

    function stake(address[] memory _collections, uint256[] memory _tokenIds) public {
        require(_collections.length == _tokenIds.length, 'Invalid Input');
        for (uint i = 0; i < _collections.length; i++){
            _stake(_collections[i], _tokenIds[i]);
        }
    }

    //function to transfer NFT from user to contract
    function _stake(address _collection, uint256 tokenId) private {
        require(collections[_collection], 'This collection is not allowed to be staked');
        require(IERC721(_collection).isApprovedForAll(msg.sender, address(this)), 'Not approved');

        IERC721(_collection).transferFrom(msg.sender,address(this),tokenId); // User must approve() this contract address via the NFT ERC721 contract before NFT can be transfered

        uint releaseTime = block.timestamp;

        stakingIdPointer = stakingIdPointer.add(1);
        uint256 stakingId = stakingIdPointer;

        Staking memory staking = Staking(msg.sender, _collection, tokenId, releaseTime, 0, stakingId);

        _addStakingToOwnerEnumeration(msg.sender, stakingId);
        _addStakingToAllStakingsEnumeration(staking);
        balances[msg.sender]++;

        emit tokenStaked(msg.sender, staking.collection, staking.tokenId, stakingId);
    }

    function claimReward(uint256[] memory _stakingIds) public {
        for (uint256 i = 0; i < _stakingIds.length; i++) {
            _claimReward(_stakingIds[i]);
        }
    }

    function _claimReward(uint256 stakingId) private {
        require(stakingId <= stakingIdPointer, 'staking id is not valid');
        Staking memory staking = _allStakings[_allStakingIndex[stakingId]];
        require(staking.staker == msg.sender, 'You are not owner of this staking');

        uint256 availableAmount = rates[staking.collection] * (block.timestamp - staking.releaseTime) / 5 minutes;
        require(availableAmount > staking.claimedAmount, 'Not allowed to get reward');

        _allStakings[_allStakingIndex[stakingId]].claimedAmount = availableAmount;
        IERC20(rewardToken).transfer(msg.sender, availableAmount - staking.claimedAmount);

        emit tokenRewardClaimed(staking.staker, staking.collection, staking.tokenId, availableAmount - staking.claimedAmount, stakingId);
    }

    function getReward(uint256 stakingId) public view returns (uint256) {
        require(stakingId <= stakingIdPointer, "staking id is not valid");
        Staking memory staking = _allStakings[_allStakingIndex[stakingId]];
        uint256 availableAmount = rates[staking.collection] * (block.timestamp - staking.releaseTime) / 5 minutes;
        uint256 reward = availableAmount - staking.claimedAmount;
        return reward;
    }

    function renounceReward(address _renounce, uint256 _amount) public onlyOwner {
        require(IERC20(rewardToken).balanceOf(address(this)) >= _amount, 'Not enough balance');
        IERC20(rewardToken).transfer(_renounce, _amount);
        emit tokenRenounced(_renounce, _amount);
    }

    function unStake(uint256[] memory _stakingIds) public {
        for (uint256 i = 0; i < _stakingIds.length; i++) {
            _unStake(_stakingIds[i]);
        }
    }

    //function to claim reward token if NFT stake duration is completed
    function _unStake(uint256 stakingId) private{
        require(stakingId <= stakingIdPointer, "staking id is not valid");
        Staking memory staking = _allStakings[_allStakingIndex[stakingId]];

        require(staking.staker == msg.sender,"You are not owner of this staking");

        uint256 availableAmount = rates[staking.collection] * (block.timestamp - staking.releaseTime) / 5 minutes;

        _removeStakingFromOwnerEnumeration(msg.sender, stakingId);
        _removeStakingFromAllStakingsEnumeration(stakingId);
        balances[msg.sender]--;

        if (availableAmount > staking.claimedAmount) {
            IERC20(rewardToken).transfer(msg.sender, availableAmount - staking.claimedAmount);
        }
        IERC721(staking.collection).transferFrom(address(this), msg.sender, staking.tokenId);

        emit tokenUnStaked(staking.staker, staking.collection, staking.tokenId, staking.stakingId);
    }

    //function to set reward rate per day
    function setRewardRate(address _collection, uint256 newRate) external onlyOwner {
        rates[_collection] = newRate;
    }

    function setCollection(address _collection, bool _value, uint256 _rate) public onlyOwner {
        collections[_collection] = _value;
        rates[_collection] = _rate;
    }

    function setRewardToken(address _token) public onlyOwner {
        rewardToken = _token;
    }

    function getTotalStakings() public view returns (uint256) {
        return _allStakings.length;
    }

}
