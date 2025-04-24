#[starknet::interface]
pub trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
    fn decrease_counter(ref self: TContractState);
    fn reset_counter(ref self: TContractState);
}

#[starknet::contract]
pub mod Counter {
    use OwnableComponent::InternalTrait;
    use openzeppelin_access::ownable::OwnableComponent;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use super::ICounter;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableTwoStepImpl = OwnableComponent::OwnableTwoStepImpl<ContractState>;

    #[storage]
    pub struct Storage {
        counter: u32,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, init_value: u32, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.counter.write(init_value);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Increase: Increased,
        Decrease: Decreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Increased {
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Decreased {
        pub account: ContractAddress,
    }

    pub mod Error {
        pub const EMPTY_COUNTER: felt252 = 'Decreasing empty counter';
    }

    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            let new_value = self.counter.read() + 1;
            self.counter.write(new_value);
            self
                .emit(
                    Increased { account: get_caller_address() },
                ); //get_caller_address by default gives the address of the UDC : universal deployment contract, if you want to set this to deployer address pass it as an argument
        }

        fn decrease_counter(ref self: ContractState) {
            let old_value = self.counter.read();
            assert(old_value > 0, Error::EMPTY_COUNTER);
            self.counter.write(old_value - 1);
            self.emit(Decreased { account: get_caller_address() })
        }

        fn reset_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.counter.write(0);
        }
    }
}
