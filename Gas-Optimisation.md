# Gas optimisation

---

## StakingRewards Contract

#### Gas Usage

> - testScenario() (gas: 400,351)
> - testScenario2() (gas: 351,486)

#### Improvements

MasterChef-Style Reward Accounting

- Instead of storing the debt in a per token format (userRewardPerTokenPaid), store it as a net value userRewardDebt, so it reduces the number of calculation
- Instead of storing accrued rewaards in a mapping, transfer it at each time of an account interact with a contract

---

## TraderJoe Contract

#### Gas Usage

> - testScenario() (gas: 163,296)
> - testScenario2() (gas: 144,487)
> - testScenario2() (gas: 121,520) --without counting the setTokenInfo function

#### Improvements

- Use last release time instead of released amount to simplify calculations
- Store the totalBalance of tokens to release to avoid calling token.balanceOf(address(this))
- Pack totalBalance and last release time in a struct
- Make all variable defined by the constructor immutable

---

## LooksRare Contract

#### Gas Usage

> - testDeposit1() (gas: 895,230)
> - testDeposit2() (gas: 604,966)
> - testHarvestAndCompound1() (gas: 743,798)
> - testHarvestAndCompound2() (gas: 471,649)
> - testWithdraw1() (gas: 822,920)
> - testWithdraw2() (gas: 638,506)

#### Improvements

- Make all variables in struct take only one storage slot:
   <div>
    <div style="display: flex;">
    <div style="flex: 50%; padding-right: 10px;">
     before
  
  ```solidity
    struct StakingPeriod {
          uint256 rewardPerBlockForStaking;
          uint256 rewardPerBlockForOthers;
          uint256 periodLengthInBlock;
      }
  ```
  
  </div>
  <div style="flex: 50%; padding-left: 10px;">
    after:
  
  ```solidity
   struct StakingPeriod {
          uint96 rewardPerBlockForStaking;
          uint96 rewardPerBlockForOthers;
          uint64 periodLengthInBlock;
      }
  ```
     </div>
  </div>
  
- Reduce the number of storage variable to describe the current state :
     <div>
   <div style="display: flex;">
    <div style="flex: 50%; padding-right: 10px;">
    before :
  
    ```solidity
    uint256 public currentPhase;
    uint256 public endBlock;
       uint256 public lastRewardBlock;
           uint256 public rewardPerBlockForOthers;
            uint256 public rewardPerBlockForStaking;
    ```
   </div>
     <div style="flex: 50%; padding-left: 10px;">
      after:
    
    
  ```solidity
  State public state;
      struct State {
          uint128 currentPhase;
          uint128 lastRewardBlock;
      }
  ```
  </div>
   </div>

- To make those change easier :
  
    * periodLengthInBlock was replaced by endPeriodBlock to simplify calculations.
        <div>
          <div style="display: flex;">
           <div style="flex: 50%; padding-right: 10px;">
          before :
    
         ```solidity
           struct StakingPeriod {
                 uint256 rewardPerBlockForStaking;
                 uint256 rewardPerBlockForOthers;
                 uint256 periodLengthInBlock;
             }
         ```
        </div>
         <div style="flex: 50%; padding-left: 10px;">
           after:

         ```solidity
          struct StakingPeriod {
                 uint96 rewardPerBlockForStaking;
                 uint96 rewardPerBlockForOthers;
                 uint64 endPeriodBlock;
             }
         ```
      </div>
         </div>
    * getter functions were added to easily get the missing variable from currentPhase
     
       ````solidity
           function getEndBlock(
              uint128 currentPhase
          ) public view returns (uint256 endBlock) {
              return stakingPeriod[currentPhase].endPeriodBlock;
          }
          function getRewardPerBlockForStaking(
              uint128 currentPhase
          ) public view returns (uint256 rewardPerBlockForStaking) {
              return stakingPeriod[currentPhase].rewardPerBlockForStaking;
          }
       
          function getRewardPerBlockForOthers(
              uint128 currentPhase
          ) public view returns (uint256 rewardPerBlockForOthers) {
              return stakingPeriod[currentPhase].rewardPerBlockForOthers;
          } 
      ````
- Minting rewards is done only when withdrawing or calling the specific function created for this case. Before it was done at each updatePool() call. Here are the variables keeping track of what need to be minted :
     
    ````solidity
        struct PendingRewards {
        uint128 pendingTokenRewardForOthers;
        uint128 pendingTokenRewardForStaking;
        }
        PendingRewards public pendingRewards;
    ````
    Here are the new functions that mint the pending rewards when   there is a tranfer or when there are directly called
    ````solidity
       function mintRewardsForStaking() public {
            looksRareToken.mint(
                address(this),
                pendingRewards.pendingTokenRewardForStaking
            );
            pendingRewards.pendingTokenRewardForStaking = 0;
        }

        function mintRewardsForOthers() external {
            looksRareToken.mint(
                tokenSplitter,
                pendingRewards.pendingTokenRewardForOthers
            );
            pendingRewards.pendingTokenRewardForOthers = 0;
        }
    ````
    ---

## ERC721 Staking Contract

#### Gas Usage

> - testScenario() (gas: 6,134,345)
> - testScenario2() (gas: 3,957,304)

#### Improvements

MasterChef-Style Reward Accounting

- Instead of storing the staking conditions history, we store the accumulated reward per token and the reward debt
- removed unecessary data structure :
 ````solidity
   uint256[] public indexedTokens;
    mapping(uint256 => bool) public isIndexed;
````

---