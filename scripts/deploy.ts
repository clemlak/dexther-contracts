import hre from 'hardhat';
import '@nomiclabs/hardhat-ethers';

const { ethers } = hre;

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log('Deploying contract(s) with account:', deployer.address);

  const Dexther = await ethers.getContractFactory('Dexther');
  const dexther = await Dexther.deploy(0);

  console.log('Dexther deployed:', dexther.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
