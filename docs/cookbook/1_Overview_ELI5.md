# Overview ELI5

## What Order is

Trades within the Seaport protocol are called Orders. Some examples of orders are Fixed-price sales, English or Dutch auction sales, Offer-based sale, and Collection offers.

[Seaport Documentation](/docs/SeaportDocumentation.md) contains a detailed description of the Order and what it consists of. Seaport is designed to support plenty of trade mechanics with different levels of complexity, and some of the common ones are described in the Cookbook.

## Order fulfillment

Trade is complete when the Order is fulfilled. Seaport allows several ways of order creation and fulfillment, including:

-   full on-chain solution when both creation and completion happen on-chain;
-   semi-off-chain solution, used by Opensea as well. In semi off-chain solution, the initiator party signs a typed data object describing the Order. This signature is stored off-chain and it is used when an order is fulfilled on-chain. This particular option is described in the cookbook guides.

## Offerer and Fulfiller

The party who initiates the order is called the Offerer. For example, if you list an NFT for sale, you are the Offerer. If you create an offer for NFT, you are the Offerer. You initiate the process, proposing something you own and asking for something in return.

The Fulfiller is the party who confirms the Order fulfillment transaction. In the case of a Fixed-price sale, the fulfiller is the buyer. In the case of an Offer-based sale, the fulfiller is the seller. Fulfilling the order means agreeing to receive the assets in Offer and to provide the assets as described in the Consideration.

## Offer and Consideration

Order contains 2 important parts defining the deal:

-   Offer: this is what the Offerer is willing to give;
-   Consideration: this is how the Offerer wants the distribution to happen when the Order is accepted.

> Example: The Offerer wants to list the SuperNFT #1234 token for fixed-price 1 ETH. He wants to pay the royalty, and since he does it through Opensea, he wants Opensea to receive a service fee. The service fee is 2.5%, and let's say the SuperNFT collection royalty fee is 5%.
>
> Then his order has the following:
>
> -   Offer: SuperNFT #1234
> -   Consideration:
>     -   0.925 ETH to Offerer;
>     -   0.05 ETH to Royalty receiver address;
>     -   0.025 ETH to Opensea.

Distribution of royalties and service fees are not hard-coded to the on-chain protocol. The Consideration included in Order fully depends on how the Offerer wants it to happen.

## Other parts of order

The Order also includes other parameters used for validation if the trade can happen and defining how the items should be transferred. Such parameters include:

-   start date: a date when the Order becomes valid;
-   end date: a date when the Order expires;
-   conduit key: the key of the smart contract which is eligible to transfer the assets in the trade. This is also the contract to which Offerer and Fulfiller approve their assets;
-   additional validation criteria used for more complex orders.

Refer to [Seaport Documentation](/docs/SeaportDocumentation.md) for full Order parameters description.

## Order process

With the semi-off-chain solution, the general Order creation and fulfillment process steps are as follows:

1.  Offerer approves the assets he's offering (NFTs, ERC20) to Conduit – a smart contract responsible for transferring assets when the Order is being fulfilled.
2.  Offerer signs the typed data object that describes his Order.
3.  Signed order object and the order hash are stored off-chain by the Opensea marketplace.
4.  Fulfiller approves his assets (NFTs, ERC20) to Conduit. Fulfiller might also need to approve the ERC20 token which is used to pay marketplace and royalty fees.
5.  Fulfiller confirms the fulfill order transaction on the Seaport contract.
6.  Seaport contract emits the OrderFulfilled event.
7.  Seaport marketplace back-office processes the event and updates the state of the Order on the marketplace.