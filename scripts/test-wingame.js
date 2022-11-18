const { ethers } = require("hardhat")
const diamond = require('diamond-util')
const { deploy, getAt, deployDiamond } = require('./utils')

let owner, addrs, WinGame, Competition, VRFCoordinator

const toTimestamp = (date) => parseInt(date==undefined?new Date():new Date(date)/1000)
const setBlockTime = async (date)=>{
  await network.provider.send("evm_setNextBlockTimestamp", [toTimestamp(date)] )
  await network.provider.send("evm_mine") 
}

describe("WinGame", () => {
  it("Deploy", async () => {
    [owner, ...addrs] = await ethers.getSigners()
    WinGame = await deployDiamond('WinGame',['CompetitionFacet'])    
  })
})

describe("CompetitionFacet", () => {
  it("Init", async () => {
    Competition = await getAt("CompetitionFacet", WinGame.address)
    VRFCoordinator = await deploy("VRFCoordinator")
    await (await VRFCoordinator.createSubscription(Competition.address)).wait()
    const [,hash] = await VRFCoordinator.getSubscription(0)
    await(await Competition.updateVRF(VRFCoordinator.address, 0, hash)).wait()
  })
  it("Create", async () => {
      await (await Competition.create(10, ethers.utils.parseEther("0.1"), ethers.constants.AddressZero)).wait()
  })
  it("Update", async () => {
      await (await Competition.update(0, 32, ethers.utils.parseEther("0.1"), ethers.constants.AddressZero)).wait()
  })
  it("Start", async () => {
      await (await Competition.start(0)).wait()
  })
  it("Buy", async () => {
      for(const addr of addrs) {
          await (await Competition.connect(addr).buy(0, {value:ethers.utils.parseEther("0.1")})).wait()
      }
      console.log(await Competition.remains(0))
  })
  it("Draw", async () => {
      await (await Competition.draw(0)).wait()
      await (await VRFCoordinator.fulfillRandomWords(0, 0)).wait()
  })
  it("Finish", async () => {
    await setBlockTime("2022-11-20 00:00:00")
    await (await Competition.finish(0)).wait()
    // console.log(ethers.utils.formatEther(await waffle.provider.getBalance(owner.address)))
  })
  it("Result", async () => {
    for(let i = 1;i<=addrs.length;i++) {
        const tm = `2022-11-20 00:${i>9?'':0}${i}:02`
        await setBlockTime(tm)
        console.log(tm, await Competition.result(0))
    }
  })
  it("Claim", async () => {
    let total = ethers.utils.parseEther("0")
    const claims = []
    for(const addr of addrs) {
        let amount = await waffle.provider.getBalance(addr.address)
        await (await Competition.connect(addr).claim(0)).wait()
        amount = (await waffle.provider.getBalance(addr.address)).sub(amount) 
        const info = await Competition.connect(addr).mine(0)
        claims.push([
            addr.address,
            Number(ethers.utils.formatEther(amount)),
            ...info
        ])
        total = total.add(info[2])
    }
    console.log(claims.sort((a, b) => a[1]>b[1]?-1:1))
    console.log(ethers.utils.formatEther(total))
  })
})
