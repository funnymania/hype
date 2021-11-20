// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Hype {
    struct Proposal {
        bytes32 name;   // short name (up to 32 bytes)
        uint voteCount; // number of accumulated votes
        address memberToChange;
        address memberToSpend;
        uint reserveAmtToSpend;
        uint proposalType; // 0: nothing happens, 1: add member, 2: remove member, 3: spend reserver, 4: change distribution interval, 5: change weight
    }
    
    string private _name = "Hype";
    string private _symbol = "HYP";
    
    // This decides supply.
    uint8 private _decimals = 18;
    
    // Whole number amount of supply. Will not change.
    uint private _totalSupply = 30 * 10**6 * 10 ** _decimals;
    
    // Multiplier on the amount sent per distribution
    uint private distributionAmountAdjustment = 1;
    
    // Overrage
    uint private totalDivisionLeftovers = 0;
    
    struct MemberList {
        mapping(address => MemberBalance) memberBalances;
        Member[] members;
        uint size;
    }
    
    struct Member {
        bool isActive;
        address balanceKey;
    }
    
    //TODO: Add weight, make this votable
    struct MemberBalance {
        uint memberIndex;
        uint balance;
    }
    
    MemberList public memberList;
    
    Proposal[] public currentProposals;
    
    Proposal[] public winningProposals;
    
    // Default is seconds in a year.
    uint private timeSpan = 60 * 60 * 24 * 365;
    
    uint private timeFactor = 1; 
    
    // frequency of token distribution. Default is 6 times a year.
    uint public timeNext = timeSpan / 6;
    
    // Number of distributions total.
    uint public amtOfDistributions = 600;
    
    uint lastBlockDistributed = block.timestamp;
    
    // Account which rewards dev team for their work
    address public dev;
    
    // Account for special purposes, such as helping people in need.
    address public reserve;
    
    // Required per ERC-20
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // All user balances, and the treasury, excludes only members
    mapping (address => uint) public balances;
    
    constructor() {
        dev = msg.sender;
        balances[address(this)] += _totalSupply;
        // distribute();
    }
    
    // CONSIDER: Consider instead PRODUCING a certain amount of tokens every 60 days, and allocating them. There can in one contract only be so much
    // of a coin in any one account. So, at some point there will be need to be tapering, or something more orchestrated emerge. 
    // If we make  it possible for new coins to be produced at a variable interval, we can control production and adapt to  fluctuations in the market.
    // If we haave a static supply, every single token is a complete distribution of control and voting rights to the winner of some tournament.
    // This is... interesting. We can also make it possible for a holder of some dynamic supply to burn its supply. For instance, instead of transferring
    // power by delegating, you can destroy your position, and this will have the affect of normalizing voting powers that exist somewhat. People with less votes 
    // comparatively have more. People with more have less. This is complicated however,you need to convince people to  burn their supply. OR force it via vote but then
    // that needs to be in the contract. 
    // Is there anyway to force members to spend a certain amount of their allotment?
    // Distribution every 60 days (perhaps using block number). 1% of total a year, so ~.167% of total every two months. Of this, 5% goes to dev,
    // 1% to a reserve account for emergencies involving holders ( health complications ), 94% goes to members.
    // If members is empty, 99% goes to dev. 
    function distribute() public {
        if (block.timestamp < timeNext + lastBlockDistributed)
            revert DistributionDurationHasNotPassed({
                timeRemaining: timeNext - block.timestamp
            });
        
        lastBlockDistributed = block.timestamp;
        
        address treasury = address(this);
        
        // we are asuming even distribution patterns
        // Default is distributions = 100 * 6 = 600.
        // distribution amt is supply / distributions.
        // Default freq (timeNext is 60*60*24*60 which is every 60 days.
        // Default timeline approx 100 years
        uint divyAmt = (_totalSupply / amtOfDistributions) * distributionAmountAdjustment;
        if (memberList.size == 0) {
            // Remove bi_monthly from treasury
            uint dev_share = divyAmt / 100 * 99;
            
            balances[dev] += dev_share;
            
            uint reserve_share = divyAmt - dev_share;
            balances[reserve] += reserve_share;
            
            balances[treasury] -= dev_share;
            if (balances[treasury] < 0) {
                balances[dev] += balances[treasury];
                balances[treasury] = 0;
            }
            
            balances[treasury] -= reserve_share;
            if (balances[treasury] < 0) {
                balances[reserve] += balances[treasury];
                balances[treasury] = 0;
            }
        } else {
            // Remove bi_monthly from treasury
            uint dev_share = divyAmt / 20;
            balances[dev] += dev_share;
            
            uint remainder_share = divyAmt - dev_share;
            uint member_share = remainder_share / 100 * 94;
            uint reserve_share = remainder_share - member_share;

            //Remainder needs to be dealt with properly, overage/underage is in leftover,
            //which we 
            uint individual_member_share = member_share / memberList.size;
            uint leftover = member_share;
            for (uint i = 0; i < memberList.size; i++) {
                if (memberList.members[i].isActive) {
                    memberList.memberBalances[memberList.members[i].balanceKey].balance += individual_member_share;
                    leftover -= individual_member_share;
                }
            }

            // At year 99, there will be some small amount to be either paid back, or paid out. 
            // If we have surplus, that gets shifted to reserve. Else, take it from reserve, then dev. 
            totalDivisionLeftovers += leftover;

            balances[reserve] += reserve_share;
            balances[treasury] -= member_share;
            balances[treasury] -= dev_share;
            balances[treasury] -= reserve_share;
        }
    }
    
    // Decide how many times per allotment. EXAMPLE: passing 3, distribution is now 3 times per year)
    function changeDistributionFrequency(uint newDuration) external {
        if (msg.sender != dev)
            revert InvalidChairPerson();
        require(newDuration != 0, "Cannot divide by 0");
        
        timeNext = timeSpan / newDuration;
    }
    
    // Decide how much is distributed per distribution. Default value (1) being unchanged would lead to supply gone in 100 years.
    // adjustment being 2 would make twice the amount of HYP dropped per distribution, and 2x speed until supply depleted from that point. 
    function changeDistributionAdjustment(uint adjustment) external {
        if (msg.sender != dev)
            revert InvalidChairPerson();
        require(adjustment >= 0, "Cannot distribute funds back to treasury by this method");
        
        distributionAmountAdjustment = adjustment;
    }
    
    // Cast a vote. No delegation.
    //TODO: could have a timer AND could end automatically when all members vote
    function vote(uint proposalIndex) external {
        if (balances[msg.sender] > 0) {
            currentProposals[proposalIndex].voteCount += balances[msg.sender];
        } else if (memberList.memberBalances[msg.sender].balance > 0) {
            currentProposals[proposalIndex].voteCount += memberList.memberBalances[msg.sender].balance;
        } else {
            require(false, "You have no tokens to vote with.");
        }
    }
    
    // Counts proposal votes.
    // FIXME: Probably need a limitation on winningProposals size. 
    function countBallots() external {
        if (msg.sender != dev) 
            revert InvalidChairPerson();
            
        uint winningIndex = 0;
        uint winningCount = 0;
        for (uint i = 0; i < currentProposals.length; i++) {
            if (currentProposals[i].voteCount > winningCount) {
                winningCount = currentProposals[i].voteCount;
                winningIndex = i;
            }
        }
        
        // 1: add member, 2: remove member, 3: spend reserver, 4: change distribution interval, 5: change weight
        if (currentProposals[winningIndex].proposalType == 1) {
            addMember(currentProposals[winningIndex].memberToChange);
            winningProposals.push(currentProposals[winningIndex]);
        } else if (currentProposals[winningIndex].proposalType == 2) {
            removeMember(currentProposals[winningIndex].memberToChange);
            winningProposals.push(currentProposals[winningIndex]);
        } else if (currentProposals[winningIndex].proposalType == 3) {
            spendReserver(currentProposals[winningIndex].memberToSpend, currentProposals[winningIndex].reserveAmtToSpend);
            winningProposals.push(currentProposals[winningIndex]);
        }
        
        winningProposals.push(currentProposals[winningIndex]);
        
        // BROKEN: "memory to storage not yet supported"
        // Need a way to zero this out (maybe just set all elements to 0 or empty string)
        // currentProposals = new Proposal[](0);
    }
    
    // Get winning proposals
    //function getWinners(uint index) external returns (Proposal[] calldata) {
    //    return winningProposals;
    // }
    
    // Submits a proposal to current vote. 
    function submitProposal(Proposal memory newProposal) external {
        /**
         * bool isMember = false;
        for (uint i = 0; i < members.length; i++) {
            if (msg.sender == members[i]) {
                isMember = true;
                break;
            }
        }*/
    
        require(balances[msg.sender] != 0, "Must be staking to submit a proposal!");
        currentProposals.push(newProposal);
    }
    
    function isChair(address caller) internal view returns (bool) {
        if (caller != dev) return false;
        else return true;
    }
    
    function isMember(address caller) internal view returns (bool) {
        if (memberList.members[memberList.memberBalances[caller].memberIndex].isActive 
        && memberList.members[memberList.memberBalances[caller].memberIndex].balanceKey == caller) 
            return true;
        else return false;
    }
    
    // Add a new member. 
    function addMember(address newMember) public {
        require(isChair(msg.sender) || isMember(msg.sender), "You are not the chairperson or a member!");
        memberList.size += 1;
        memberList.memberBalances[newMember] = MemberBalance({ memberIndex: memberList.size - 1, balance: 0 });
        memberList.members.push(Member({ isActive: true, balanceKey: newMember}));
        memberList.size += 1;
    }
    
    // Remove a new member, move their record to normal balances.
    function removeMember(address removeMe) public {
        require(isChair(msg.sender), "You are not the chairperson!");
        require(memberList.memberBalances[removeMe].balance != 0, "This is not a member");
        
        // Move balance.
        balances[removeMe] = memberList.memberBalances[removeMe].balance;
        
        // Remove member 
        memberList.members[memberList.memberBalances[removeMe].memberIndex].isActive = false;
        memberList.memberBalances[removeMe].balance = 0; //TODO: Init struct how.
        memberList.size -= 1;
    }
    
    // Allocate funds for spending. 
    function spendReserver(address memberToSpend, uint256 amt) public {
        require(isChair(msg.sender), "You are not the chairperson!");
         _transfer(reserve, memberToSpend, amt);
    }
    
    error InsufficientBalance(uint requested, uint available);
    error InsufficientAllowance(uint requested, uint allowance);
    error InvalidChairPerson();
    error DistributionDurationHasNotPassed(uint timeRemaining);
    
    function name() public view returns (string memory) {
        return _name;
    }
    
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    
    function decimals() public view returns (uint8) {
        return _decimals;
    }
    
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address owner) public view returns (uint256 balance) {
        return balances[owner];
    }
    
    // any holder can send to anyone else, as long as they have enough.
    function transfer(address receiver, uint256 value) public returns (bool success) {
        _transfer(msg.sender, receiver, value);
        return true;
    }
    
    // Utilized by contracts, I think. 
    function transferFrom(address from, address to, uint value) public returns (bool success) {
        _transfer(from, to, value);
        uint currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance >= value)
            revert InsufficientAllowance({
                requested: value,
                allowance: currentAllowance
            });
        
        unchecked {
            _approve(from, msg.sender, currentAllowance - value);
        }

        return true;
    }
    
    function approve(address spender, uint256 value) public returns (bool success) {
        _approve(msg.sender,  spender, value);
        return true;
    }
    
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return _allowances[_owner][_spender];
    }
    
    function _transfer(address from, address to, uint value) internal {
        _beforeTokenTransfer(from, to, value);
        if (balances[from] < value) 
            revert InsufficientBalance(
                {
                    requested: value,
                    available: balances[from]
                });
        
        
        balances[from] -= value;
        balances[to] += value;
        emit Transfer(from, to, value);
        _afterTokenTransfer(from, to, value);
    }
    
    function _approve(
        address owner,
        address spender,
        uint value
    ) internal {
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint amount
    ) internal virtual {}
    
    function _afterTokenTransfer(
        address from,
        address to,
        uint amount
    ) internal virtual {}
}
