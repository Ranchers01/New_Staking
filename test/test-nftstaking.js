const chai = require("chai");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { solidity } = require("ethereum-waffle");

chai.use(solidity);

const SHA3 = require("keccak256");

let signers,
  deployer, tester1, tester2;

let nft1, nft2, nft3, token, staking;

describe("Zoo NFT staking test suite", async function () {
  before(async function() {
    signers = await ethers.getSigners();
    deployer = signers[0];
    tester1 = signers[1];
    tester2 = signers[2];
    const NFT = await ethers.getContractFactory("NFT");
    const Token = await ethers.getContractFactory("MyToken");
    const Staking = await ethers.getContractFactory("StakeNFT");

    nft1 = await NFT.deploy(tester1.address, 'NFT1', 'NFT1');
    await nft1.deployed()
    nft2 = await NFT.deploy(tester1.address, 'NFT2', 'NFT2');
    await nft2.deployed();
    nft3 = await NFT.deploy(tester1.address, 'NFT3', 'NFT3');
    await nft3.deployed();
    token = await Token.deploy();
    await token.deployed();
    staking = await Staking.deploy(token.address);
    await staking.deployed();
    await staking.setCollection(nft1.address, true, 1000000);
    await staking.setCollection(nft2.address, true, 1000000);
    await token.transfer(staking.address, ethers.utils.parseUnits('10000', 10))

  })

  it("should stake nft", async function () {
    await nft1.connect(tester1).setApprovalForAll(staking.address, true);
    await staking.connect(tester1).stake([nft1.address, nft1.address], [1, 2]);
    // await staking.connect(tester1).stake(nft1.address, 2)
    await nft2.connect(tester1).setApprovalForAll(staking.address, true);
    await staking.connect(tester1).stake([nft2.address], [1])

    expect(await nft1.balanceOf(staking.address)).to.equal(2);
    expect(await nft2.balanceOf(staking.address)).to.equal(1);

    expect(await staking.balances(tester1.address)).to.equal(3);
  });

  it('should get reward for the staked nft', async function () {
    await time.increase(600);
    const stakingId = await staking.connect(tester1).stakingOfOwnerByIndex(tester1.address, 0);
    const stakingInfo1 = await staking.connect(tester1).stakingById(stakingId);
    console.log(stakingInfo1.claimedAmount);
    await staking.connect(tester1).claimReward([stakingId]);
    const stakingInfo2 = await staking.connect(tester1).stakingById(stakingId);
    console.log(stakingInfo2.claimedAmount);
    await time.increase(600);
    const stakingId2 = await staking.connect(tester1).stakingOfOwnerByIndex(tester1.address, 2);
    await staking.connect(tester1).claimReward([stakingId2]);
    const stakingInfo3 = await staking.connect(tester1).stakingById(stakingId2);
    console.log(stakingInfo3.claimedAmount);
  });

  it('should unstake a nft', async function () {
    const stakingId = await staking.connect(tester1).stakingOfOwnerByIndex(tester1.address, 0);
    await staking.connect(tester1).unStake([stakingId]);
    expect(await staking.balances(tester1.address)).to.equal(2);
  });

  it('should not stake unlisted nft', async function () {
    await expect(staking.connect(tester1).stake([nft3.address], [0])).to.be.revertedWith('This collection is not allowed to be staked')
  });

  it('should renounce reward token', async function () {
    const balance = await token.balanceOf(staking.address);
    await staking.renounceReward(tester2.address, balance);
    expect(await token.balanceOf(tester2.address)).to.equal(balance)
  });
});

