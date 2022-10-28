source .env && forge script ./script/Goerli.s.sol --rpc-url $GOERLI_RPC_URL  --private-key $GOERLI_PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv RUST_BACKTRACE=full
