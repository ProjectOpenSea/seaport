# This is just a placeholder from the structs that would be imported from ConsiderationStruct
struct BasicOrderParameters:
    placeholder: uint256

struct OrderComponents:
    placeholder: uint256

struct Fulfillment:
    placeholder: uint256

struct FulfillmentComponent:
    placeholder: uint256

struct Execution:
    placeholder: uint256

struct Order:
    placeholder: uint256

struct AdvancedOrder:
    placeholder: uint256

struct OrderStatus:
    placeholder: uint256

struct CriteriaResolver:
    placeholder: uint256

# Since we don't know the length for most the arrays in this inferface, dynamic arrays
# with a max length of N_ are used. There are better ways to think about this though
N_ : constant(int128) = MAX_INT128

interface SeaportInterface:
    def fulfillBasicOrder(parameters: BasicOrderParameters) -> bool: payable

    def fulfillOrder(order: Order, fulfillerConduitKey: bytes32) -> bool: payable

    def fulfillAdvancedOrder(
        advancedOrder: AdvancedOrder, 
        criteriaResolvers: DynArray[CriteriaResolver, N_],
        fulfillerConduitKey: bytes32) -> bool: payable

    def fulfillAvailableOrders(
        orders: DynArray[Order, N_],
        offerFulfillments: DynArray[DynArray[FulfillmentComponent, N_], N_],
        considerationFulfillments: DynArray[DynArray[FulfillmentComponent, N_], N_],
        fulfillerConduitKey: bytes32, 
        maximumFulfilled: uint256) -> (DynArray[bool, N_], DynArray[Execution, N_]) : payable

    def fulfillAvailableAdvancedOrders(
        advancedOrders: DynArray[AdvancedOrder, N_], 
        criteriaResolvers: DynArray[CriteriaResolver, N_], 
        offerFulfillments: DynArray[DynArray[FulfillmentComponent, N_], N_],
        considerationFulfillments: DynArray[DynArray[FulfillmentComponent, N_], N_],
        fulfillerConduitKey: bytes32, 
        maximumFulfilled: uint256) -> (DynArray[bool, N_], DynArray[Execution, N_]) : payable
    
    def matchOrders(
        orders: DynArray[Order, N_],
        fulfillments: DynArray[Fulfillment, N_]) -> DynArray[Execution, N_] : payable
    
    def matchAdvancedOrders(
        orders: DynArray[AdvancedOrder, N_], 
        criteriaResolvers: DynArray[CriteriaResolver, N_], 
        fulfillments: DynArray[Fulfillment, N_]) -> DynArray[Execution, N_] : payable
    
    def cancel(orders: DynArray[OrderComponents, N_]) -> bool : nonpayable
    
    def validate(orders: DynArray[Order, N_]) -> bool : nonpayable
    
    def incrementNonce() -> uint256 : nonpayable
    
    def getOrderHash(order: OrderComponents) -> bytes32 : view
    
    def getOrderStatus(orderHash: bytes32) -> (bool, bool, uint256, uint256) : view
    
    def getNonce(offerer: address) -> uint256 : view
    
    def information() -> (String[N_], bytes32, address) : view
    
    def name() -> String[N_] : view
