// SPDX-License-Identifier: GPL-3.0
    
pragma solidity >=0.4.22 <0.9.0;

// This import is automatically injected by Remix
import "remix_tests.sol"; 

// This import is required to use custom transaction context
// Although it may fail compilation in 'Solidity Compiler' plugin
// But it will work fine in 'Solidity Unit Testing' plugin
import "remix_accounts.sol";
import "../contracts/4_Hype.sol";

// File name has to end with '_test.sol', this file can contain more than one testSuite contracts
contract testSuite {
    Hype threeStock;
    
    // Once a second.
    uint onceSecondly = 365 * 24 * 60 * 60;
    
    // Once every hundredth second.
    uint onceHundredthSecondly = 365 * 24 * 60 * 600; 
    
    // Once every five seconds.
    uint onceFiveSecondly = 365 * 24 * 60 * 12;
    
    /// 'beforeAll' runs before all other tests
    /// More special functions are: 'beforeEach', 'beforeAll', 'afterEach' & 'afterAll'
    function beforeEach() public {
        threeStock = new Hype();
    }
    
    function checkInitial() public {
        Assert.equal(threeStock.dev(), address(this), "Contract creator should be dev");
        Assert.notEqual(threeStock.dev(), address(threeStock), "Contract creator should be dev");
    }
    
    // Assuming no members ever added, check values in dev and reserve assuming all are distributed at once.
    function firstDistribution() public {
        // Amount to send out per duration. In this case, we are setting it to MAX.
        threeStock.changeDistributionAdjustment(threeStock.amtOfDistributions());
        
        // How often this will be send out, in equal divison.
        threeStock.changeDistributionFrequency(onceHundredthSecondly);
        
        // After complete iteration with no members
        uint devBalance = 297 * 10**5 * 10**18;
        uint reserve = 3 * 10**5 * 10**18;
        
        threeStock.distribute();
        Assert.equal(threeStock.balanceOf(address(threeStock)), 0, "Should be empty");
        Assert.equal(threeStock.balanceOf(threeStock.dev()), devBalance, "29.7million * 10**18 should be here");
        Assert.equal(threeStock.balanceOf(threeStock.reserve()), reserve, "0.03 million * 10**18 should be here");
    }
    
    // Start, distribute to self, add member, check after one distribution, check after all.
    function startAloneGetMember() public {
        // Amount to send out per duration. In this case, we are setting it to 2x speed. 
        threeStock.changeDistributionAdjustment(2);
        
        // How often.
        threeStock.changeDistributionFrequency(onceHundredthSecondly);
        
        threeStock.distribute();
        Assert.equal(threeStock.balanceOf(address(threeStock)), threeStock.totalSupply() / 300 * 299, "Should be 299/300");
        
        //TODO: Create proposal to add member, vote on proposal, tally votes
        
        //TODO: Run through a distribution cycle, check balances are where they should be.
        
        //TODO: run through all distributions, check balances are wheree they should be.
    }
    
    function giftHalfToMember() public {
        threeStock.changeDistributionFrequency(onceHundredthSecondly);
        
        // distribute
        threeStock.distribute();
        
        //TODO: Create random address.
        address newMember = address(90000);
        
        // send half to member.
        threeStock.transfer(newMember, threeStock.balanceOf(threeStock.dev()) / 2);
        
        Assert.equal(threeStock.balanceOf(threeStock.dev()), threeStock.balanceOf(newMember), "Should be equal");
    }
    
    // FAILS BECAUSE OF REMAINDER ISSUES 
    // function distributeEveryBlock() public {
    //     while (threeStock.balanceOf(address(threeStock)) != 0) {
    //         try threeStock.distribute() {
    //             continue;
    //         } catch (bytes memory) {
    //             continue;
    //         }
    //     }
        
    //     Assert.notEqual(threeStock.balanceOf(threeStock.dev()), 0, "Dev should have funds");
    //     Assert.notEqual(threeStock.balanceOf(threeStock.reserve()), 0, "Reserve should have funds");
    // }
    
    // To throw a local tournament!!::
    // x. distribute... 
    
    // y. vote to add a member... 
    
    // z. gift HALF of what I have to that member... 
    
    // 1. do math, 20 loc, 2 region, 1 natl... region = 5 local... natl = 6 region... 20 + 10 + 30 = 60.
    //.... 1/60th for the local, 60% first, 30% second, 10% third
    //... setup wallets for three people
    //... transfer accordingly
    
    // ...
    
    // 2. wait until distribution. 
    
    function checkSuccess() public {
        // Use 'Assert' methods: https://remix-ide.readthedocs.io/en/latest/assert_library.html
        Assert.ok(2 == 2, 'should be true');
        Assert.greaterThan(uint(2), uint(1), "2 should be greater than to 1");
        Assert.lesserThan(uint(2), uint(3), "2 should be lesser than to 3");
    }
    
    // move from Reserves to Spender

    function checkSuccess2() public pure returns (bool) {
        // Use the return value (true or false) to test the contract
        return true;
    }

    /// Custom Transaction Context: https://remix-ide.readthedocs.io/en/latest/unittesting.html#customization
    /// #sender: account-1
    /// #value: 100
    function checkSenderAndValue() public payable {
        // account index varies 0-9, value is in wei
        Assert.equal(msg.sender, TestsAccounts.getAccount(1), "Invalid sender");
        Assert.equal(msg.value, 100, "Invalid value");
    }
}
