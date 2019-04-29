pragma solidity >=0.4.22 <0.6.0;
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

interface tokenRecipient { function receiveApproval(address from, uint256 value, address token, bytes calldata extraData) external; }

string public steam_key = "1234567890";
string public steam_id = "76561197960361544";

contract eStakesToken is usingOraclize {
    // Token's public variables 
    string public token_name;
    string public token_symbol;
    uint256 public net_supply;
    mapping (address => uint256) public balance;
    mapping (address => mapping (address => uint256)) public allowance;
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed _owner, address indexed spender, uint256 value);
    event Burn(address indexed from, uint256 value);
    
    constructor(
        uint256 initialSupply, string memory tokenName, string memory tokenSymbol
    ) public {
        net_supply = initialSupply * (10**20); 
        balance[msg.sender] = net_supply;                    
        token_name = tokenName;                                       
        token_symbol = tokenSymbol;    
    }                               

    function winningProportion(address to, string steam_key, string steam_id) {
        emit LogNewOraclizeQuery("Getting user profile");
        string username = oraclize_query("URL", "json(https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key={steam_key}&steamids={steam_id}).response.players.3");
        if (getUserAccount(username) == to) {
            if (getUserAccount(username).curr_winning_status == "winner") {
                getUserAccount(username).balance += (getUserAccount(username).gameMode.currMatchID.input_tokens / getUserAccount(username).gameMode.currMatchID.total_tokens_winners) 
                *  getUserAccount(username).gameMode.currMatchID.total_tokens;
            } 
        }
    }
    /**
     * Internal transfer, only can be called by this contract
     */
     function gameEnd(address to, uint256 matchValue) public returns (bool success) {
        // Check if the central wallet has enough. If not, generate a buffer of coins. 
        if (balance[msg.sender] <= matchValue) {
             makeCoins(matchValue * 10) 
        }
        // winningProportion calls the STEAM API to compute the proportion of the pot to allocate to the user. Multiplying this by the total value computes the winnings for this match.
        uint256 public winnings = winningProportion(to, string user_steam_id) * matchValue
        balance[msg.sender] -= winnings  // Subtract winnings from the central wallet
        balance[to] += winnings;        // Add winnings to the user
        return true;
    }

   
    function transfer_done(address to, uint256 value) public returns (bool success) {
        if (gameEnd(to, value)) {
            return true;
        }
        return false;
    }
    
    function transferfrom(address from, address to, uint256 value) public returns (bool success) {
        require(value <= allowance[from][msg.sender]);     // Checks for allowance value
        allowance[from][msg.sender] -= value;
        gameEnd(to, value); 
        return true;
    }

    function approve_val(address spender, uint256 value) public returns (bool success) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function approve_and_call(address spender, uint256 value, bytes memory extraData) public returns (bool success) {
        tokenRecipient tokenspender = tokenRecipient(spender);
        if (approve(spender, value)) {
            tokenspender.receiveApproval(msg.sender, value, address(this), extraData);
            return true;
        }
    }

    function destroy_tokens(uint256 value) public returns (bool success) {
        require(balance[msg.sender] >= value);   // Verify if sender has more than proposed value
        balance[msg.sender] -= value;            // Subtract from sender's balance
        net_supply -= value;                      // Update net supply
        emit Burn(msg.sender, value);
        return true;
    }

    function destroy_tokens_from(address from, uint256 value) public returns (bool success) {
        require(balance[from] >= value);                //  Verify if targeted balance has more than proposed value
        require(value <= allowance[from][msg.sender]);    // Checks for allowance value
        balance[from] -= value;                         // Subtract from targeted balance
        allowance[from][msg.sender] -= value;             // Subtract from  sender's allowance
        net_supply -= value;                              // Update net supply
        emit Burn(from, value);
        return true;
    }
}