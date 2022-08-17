source .env && forge script ./script/BENSYC.s.sol --rpc-url $ETH_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvv RUST_BACKTRACE=full