pragma solidity >=0.4.16 <0.9.0;

contract Hype {
    // Public makes variables accessible from OTHER CONTRACTS
    address public minter;
    mapping (address => uint) public balances;

    // Events make it possible for clients to react to contract changes you declare.
    event Sent(address from, address to, uint amount);

    // msg.sender is the address which CALLED the function it is found in.
    // msg, tx, and block are global contexts which provide access to the blockchain.
    constructor() {
        minter = msg.sender;
    }

    // States that the person who called this function, must be the person 
    // who created the contract. Only the creator, in this case, can mint new assets.
    function mint(address receiver, uint amount) public {
        require(msg.sender == minter);
        balances[receiver] += amount; // 2**256 is the max amount of uint allowed.
    }

    error InsufficientBalance(uint requested, uint available);
           
    function send(address receiver, uint amount) public {
        if (amount > balances[msg.sender])
            revert InsufficientBalance({
                requested: amount,
                available: balances[msg.sender]
            });

        balances[msg.sender] -= amount;
        balances[receiver] += amount;
        emit Send(msg.sender, receiver, amount);
    }
}
