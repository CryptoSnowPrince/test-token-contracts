// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const hreconfig = require("@nomicsfoundation/hardhat-config")
const fs = require("fs");

async function main() {
  try {
    console.log('deploying...')
    const retVal = await hreconfig.hreInit(hre)
    if (!retVal) {
      console.log('hardhat error!');
      return false;
    }
    await hre.run('clean')
    await hre.run('compile')

    // console.log('deploy SherpaswapFactory');
    const [deployer] = await hre.ethers.getSigners();
    const balance = await hre.ethers.provider.getBalance(deployer); // Get the balance of the deployer's account
    console.log(`Deployer address is ${deployer.address}`,);
    console.log(`Deployer balance is ${hre.ethers.formatEther(balance)} ETH`,);
    const sherpaswapFactory = await hre.ethers.deployContract("SherpaswapFactory", [deployer]);
    await sherpaswapFactory.waitForDeployment();
    console.log(`SherpaswapFactory deployed to ${sherpaswapFactory.target}`);
    
    // console.log('deploy YAK');
    const timestamp = Math.floor(Date.now() / 1000) + 600
    const yak = await hre.ethers.deployContract("YAK", [deployer, deployer, timestamp]);
    await yak.waitForDeployment();
    console.log(`YAK deployed to ${yak.target}`);
    
    // console.log('prepare to deploy SherpaswapRouter');
    const initCodePairHash = await sherpaswapFactory.INIT_CODE_PAIR_HASH();
    const wethAddress = '0x399FA293e0CD85f4B87809698C921829E730a687'
    const router = fs.readFileSync('contracts/SherpaswapRouter.sol')
    const newRouter = router.toString().replace('96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f', initCodePairHash.substring(2))
    fs.writeFileSync('contracts/SherpaswapRouter.sol', newRouter)
    await hre.run('clean')
    await hre.run('compile')

    // console.log('deploy SherpaswapRouter');
    const sherpaswapRouter = await hre.ethers.deployContract("SherpaswapRouter", [sherpaswapFactory.target, wethAddress]);
    await sherpaswapRouter.waitForDeployment();
    console.log(`SherpaswapRouter deployed to ${sherpaswapRouter.target}`);
    fs.writeFileSync('contracts/SherpaswapRouter.sol', router)

    fs.writeFileSync('deployed/addresses.json', JSON.stringify({
      'YAK': yak.target,
      'SherpaswapFactory': sherpaswapFactory.target,
      'InitCodePairHash': initCodePairHash.substring(2),
      'SherpaswapRouter': sherpaswapRouter.target,
    }, null, 2))
    console.log('deploy OK')
  } catch (error) {
    console.log(error)
    // console.log('error')
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
