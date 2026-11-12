module sooma_escrow::escrow {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};

    /// Error codes
    const EInvalidAmount: u64 = 1;
    const ENotAuthorized: u64 = 2;
    const EAlreadyCompleted: u64 = 3;

    /// An escrow object holding funds between a buyer and a seller.
    public struct Escrow<phantom T> has key, store {
        id: UID,
        sender: address,
        recipient: address,
        amount: u64,
        escrowed_balance: Balance<T>,
        is_completed: bool,
    }

    /// Create and fund a new escrow object.
    public fun create_escrow<T>(
        recipient: address,
        payment: Coin<T>,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&payment);
        assert!(amount > 0, EInvalidAmount);

        let sender = tx_context::sender(ctx);
        let escrow_obj = Escrow {
            id: object::new(ctx),
            sender,
            recipient,
            amount,
            escrowed_balance: coin::into_balance(payment),
            is_completed: false,
        };

        transfer::share_object(escrow_obj);
    }

    /// Complete the escrow and release funds to the recipient.
    public fun complete_escrow<T>(
        escrow: &mut Escrow<T>,
        ctx: &TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(sender == escrow.sender || sender == escrow.recipient, ENotAuthorized);
        assert!(!escrow.is_completed, EAlreadyCompleted);

        escrow.is_completed = true;

        let total_value = balance::value(&escrow.escrowed_balance);
        let payment_coin = coin::take(&mut escrow.escrowed_balance, total_value, ctx);
        
        transfer::public_transfer(payment_coin, escrow.recipient);
    }

    /// Cancel the escrow and return funds to the sender.
    public fun cancel_escrow<T>(
        escrow: &mut Escrow<T>,
        ctx: &TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(sender == escrow.sender, ENotAuthorized);
        assert!(!escrow.is_completed, EAlreadyCompleted);

        escrow.is_completed = true;

        let total_value = balance::value(&escrow.escrowed_balance);
        let payment_coin = coin::take(&mut escrow.escrowed_balance, total_value, ctx);
        
        transfer::public_transfer(payment_coin, escrow.sender);
    }
}
