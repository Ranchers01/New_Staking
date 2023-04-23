const hre = require("hardhat");

async function main() {
    const NFT = await hre.ethers.getContractFactory("NFT");
    const Token = await hre.ethers.getContractFactory("MyToken");
    const Staking = await hre.ethers.getContractFactory("StakeNFT");
    const nft1 = await NFT.deploy('0x4696F32B4F26476e0d6071d99f196929Df56575b', 'NFT1', 'NFT1')
    await nft1.deployed();
    const nft2 = await NFT.deploy('0x4696F32B4F26476e0d6071d99f196929Df56575b', 'NFT2', 'NFT2')
    await nft2.deployed();
    const token = await Token.deploy();
    await token.deployed();
    const staking = await Staking.deploy([nft1.address, nft2.address], token.address);
    await staking.deployed();

    console.log("Token deployed to:", token.address);
    console.log("NFT deployed to:", nft1.address, nft2.address);
    console.log("Staking deployed to:", staking.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
