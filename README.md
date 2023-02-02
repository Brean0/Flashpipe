<img src="https://github.com/Brean0/Flashpipe/assets/flashPipeline.svg" alt="FlashPipeline logo" align="right" width="120" />

# FlashPipe (WIP)

Perform an arbitrary series of actions in the EVM in a single transaction: [evmpipeline.org](https://evmpipeline.org)

Code Version: `1.0.0` <br>
Whitepaper Version: `1.0.1`

**Flashpipe** is a wrapper for Depot that enables flash loan capabilities.

**Flash Loans** are uncollateralized loans that allow users to borrow funds, provided that 
the assets are returned within the same transaction.

**Depot** is a wrapper for Pipeline that
supports (1) loading Ether and non-Ether assets into Pipeline, (2) using them and (3) unloading
them from Pipeline, in a single transaction. 

**Pipeline** is a standalone contract that creates a sandbox to execute an arbitrary composition of valid
actions within the EVM in a single transaction using Ether. 

Current implementation uses [balancer Flash Loans](https://dev.balancer.fi/resources/flash-loans) as they charge no fees.
However, flashpipe can be easily forked to use other flash-loan protocols.

## Documentation

* [Pipeline Whitepaper](https://evmpipeline.org/pipeline.pdf) ([Version History](https://github.com/BeanstalkFarms/Pipeline-Whitepaper/tree/main/version-history)).

## Audits

Read Halborn's final audit report [here](https://bean.money/11-15-22-pipeline-halborn-report).

## Bug Bounty Program

Pipeline and Depot are both considered in-scope of the Beanstalk Immunefi Bug Bounty Program.

You can find the program and submit bug reports [here](https://immunefi.com/bounty/beanstalk).

Flashpipe is not audited (yet)

## Contracts

|  Contract  |              Address 
|:-----------|:-----------------------------------------------------------------------------------------------------------------------|
|  Pipeline  | [0xb1bE0000bFdcDDc92A8290202830C4Ef689dCeaa](https://etherscan.io/address/0xb1bE0000bFdcDDc92A8290202830C4Ef689dCeaa)  |
|  Depot     | [0xDEb0f000082fD56C10f449d4f8497682494da84D](https://etherscan.io/address/0xDEb0f000082fD56C10f449d4f8497682494da84D)  |
|  FlashPipe | [TBD](https://etherscan.io/address/0xDEb0f000082fD56C10f449d4f8497682494da84D)  |

## License

[MIT](https://github.com/BeanstalkFarms/Pipeline/blob/master/LICENSE)
