// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CrowdFundPlatform {
    struct Campaign {
        address creator;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        bool completed;
        bool goalReached;
        mapping(address => uint256) contributions;
        address[] contributors;
    }
    
    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCount;
    
    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 goal, uint256 deadline);
    event ContributionMade(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event FundsWithdrawn(uint256 indexed campaignId, address indexed creator, uint256 amount);
    event RefundIssued(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    
    modifier onlyCreator(uint256 _campaignId) {
        require(campaigns[_campaignId].creator == msg.sender, "Only creator can perform this action");
        _;
    }
    
    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCount, "Campaign does not exist");
        _;
    }
    
    // Core Function 1: Create a new crowdfunding campaign
    function createCampaign(uint256 _goal, uint256 _durationInDays) external returns (uint256) {
        require(_goal > 0, "Goal must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        
        uint256 campaignId = campaignCount;
        Campaign storage campaign = campaigns[campaignId];
        
        campaign.creator = msg.sender;
        campaign.goal = _goal;
        campaign.raised = 0;
        campaign.deadline = block.timestamp + (_durationInDays * 1 days);
        campaign.completed = false;
        campaign.goalReached = false;
        
        campaignCount++;
        
        emit CampaignCreated(campaignId, msg.sender, _goal, campaign.deadline);
        return campaignId;
    }
    
    // Core Function 2: Contribute to a campaign
    function contribute(uint256 _campaignId) external payable campaignExists(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(!campaign.completed, "Campaign is already completed");
        require(msg.value > 0, "Contribution must be greater than 0");
        
        // Track new contributors
        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }
        
        campaign.contributions[msg.sender] += msg.value;
        campaign.raised += msg.value;
        
        // Check if goal is reached
        if (campaign.raised >= campaign.goal) {
            campaign.goalReached = true;
        }
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }
    
    // Core Function 3: Withdraw funds or get refund based on campaign outcome
    function finalizeOrRefund(uint256 _campaignId) external campaignExists(_campaignId) {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(block.timestamp >= campaign.deadline, "Campaign is still active");
        require(!campaign.completed, "Campaign already finalized");
        
        if (campaign.raised >= campaign.goal) {
            // Goal reached - creator can withdraw funds
            require(msg.sender == campaign.creator, "Only creator can withdraw successful funds");
            
            campaign.completed = true;
            campaign.goalReached = true;
            
            uint256 amount = campaign.raised;
            campaign.raised = 0;
            
            payable(campaign.creator).transfer(amount);
            emit FundsWithdrawn(_campaignId, campaign.creator, amount);
            
        } else {
            // Goal not reached - contributors can get refunds
            uint256 contribution = campaign.contributions[msg.sender];
            require(contribution > 0, "No contribution to refund");
            
            campaign.contributions[msg.sender] = 0;
            campaign.raised -= contribution;
            
            payable(msg.sender).transfer(contribution);
            emit RefundIssued(_campaignId, msg.sender, contribution);
            
            // Mark as completed if all funds refunded
            if (campaign.raised == 0) {
                campaign.completed = true;
            }
        }
    }
    
    // View functions
    function getCampaignDetails(uint256 _campaignId) external view campaignExists(_campaignId) 
        returns (address creator, uint256 goal, uint256 raised, uint256 deadline, bool completed, bool goalReached) {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.completed,
            campaign.goalReached
        );
    }
    
    function getContribution(uint256 _campaignId, address _contributor) external view campaignExists(_campaignId) 
        returns (uint256) {
        return campaigns[_campaignId].contributions[_contributor];
    }
    
    function getContributorsCount(uint256 _campaignId) external view campaignExists(_campaignId) 
        returns (uint256) {
        return campaigns[_campaignId].contributors.length;
    }
}
