// SPDX-License-Identifier: MIT

interface IERC20 {

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract CrowdFund {

    event Launch(uint indexed id, address indexed creator,uint goal,  uint startAt, uint endAt);
    event Pledge(uint indexed id, address indexed backer, uint amount);
    event Unpledge(uint indexed id, address indexed backer, uint amount);
    event Claimed(uint id);
    event Refund(uint indexed id, address indexed backer, uint amount);

    struct Campaign {
        address creator;
        uint goal;
        uint pledge;
        uint32 startAt;
        uint endAt;
        bool claimed;
    }

    IERC20 public immutable token;
    uint public count;
    mapping(uint => Campaign) public campaigns;
    mapping(uint => mapping(address => uint)) public pledgeAmount;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function launch(uint _goal, uint32 _startAt, uint _endAt) external {
        require(_startAt >=block.timestamp, "startAt < now");
        require(_endAt >= _startAt, "end at < start at");
        require(_endAt <= block.timestamp, "end at > now");

        count += 1;
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledge: 0,
            startAt: _startAt,
            endAt: _endAt,
            claimed: false
        });

        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }


    function cancel(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(msg.sender == campaign.creator, "not creator");
        require(block.timestamp < campaign.startAt, "started");
        delete campaigns[_id];
    }

    function pledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAt, "has not started");
        require(block.timestamp <= campaign.endAt, "has ended");

        campaign.pledge += _amount;
        pledgeAmount[_id][msg.sender] += _amount;

        token.transferFrom(msg.sender, address(this), _amount);
        emit Pledge(_id, msg.sender, _amount);
    }
    function unPledge(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endAt, "has ended");

        campaign.pledge -= _amount;
        pledgeAmount[_id][msg.sender] -= _amount;

        token.transfer(msg.sender, _amount);
        emit Unpledge(_id, msg.sender, _amount);
    }
    function claim(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(msg.sender == campaign.creator,"not creator");
        require(block.timestamp > campaign.endAt, "not ended");
        require(campaign.pledge >= campaign.goal, "goal not reached");
        require(!campaign.claimed, "claimed");

        campaign.claimed = true;
        token.transfer(msg.sender, campaign.pledge);

    }
    function refund(uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(campaign.pledge < campaign.goal, "goal met");
        require(block.timestamp > campaign.endAt,"not ended");

        uint bal = pledgeAmount[_id][msg.sender];
        pledgeAmount[_id][msg.sender] = 0;

        token.transfer(msg.sender, bal);

        emit Refund(_id, msg.sender, bal);
    }
}
