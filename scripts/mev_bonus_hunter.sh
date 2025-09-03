#!/bin/bash

# Configuration
RPC_URL="${ETH_RPC_URL:-http://localhost:8545}"
PRIVATE_KEY="${PRIVKEY}"
CONTRACT_ADDRESS="" # Will be set by user or auto-detected

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_usage() {
    echo "Usage: $0 [CONTRACT_ADDRESS]"
    echo "  CONTRACT_ADDRESS: MEV-Coin contract address (optional if only one deployment exists)"
    echo ""
    echo "Environment variables:"
    echo "  RPC_URL: RPC endpoint (default: http://localhost:8545)"
    echo "  PRIVKEY: Private key for transactions (required)"
    echo ""
    echo "This script monitors the blockchain and automatically sends MEV-Coin transfers"
    echo "to capture the 100 token bonus when block numbers are divisible by 100."
    exit 1
}

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1"
}

check_dependencies() {
    log "Checking dependencies..."
    
    if [ -z "$PRIVATE_KEY" ]; then
        error "PRIVKEY environment variable not set. Please export your private key:"
        error "export PRIVKEY=0x..."
        exit 1
    fi
    
    if ! command -v cast &> /dev/null; then
        error "cast not found. Please install Foundry: https://getfoundry.sh"
        exit 1
    fi
    
    # Test RPC connection
    if ! cast block-number --rpc-url "$RPC_URL" &> /dev/null; then
        error "Cannot connect to RPC at $RPC_URL. Is anvil running?"
        exit 1
    fi
    
    log "Dependencies OK"
}

get_wallet_address() {
    cast wallet address "$PRIVATE_KEY"
}

get_contract_address() {
    if [ -n "$1" ]; then
        echo "$1"
        return
    fi
    
    # Try to find contract address from recent deployments
    log "Auto-detecting contract address from recent transactions..."
    
    WALLET_ADDR=$(get_wallet_address)
    
    # Look for recent contract creation transactions
    LATEST_BLOCK=$(cast block-number --rpc-url "$RPC_URL")
    
    for (( i=0; i<100; i++ )); do
        BLOCK_NUM=$((LATEST_BLOCK - i))
        if [ $BLOCK_NUM -lt 0 ]; then
            break
        fi
        
        # Get transactions from this block
        BLOCK_DATA=$(cast block $BLOCK_NUM --rpc-url "$RPC_URL" 2>/dev/null)
        if [ $? -eq 0 ]; then
            # Extract transaction hashes and check if any are contract creations from our wallet
            TX_HASHES=$(echo "$BLOCK_DATA" | grep -o "0x[a-fA-F0-9]\{64\}" | head -20)
            
            for tx_hash in $TX_HASHES; do
                TX_RECEIPT=$(cast receipt "$tx_hash" --rpc-url "$RPC_URL" 2>/dev/null)
                if [ $? -eq 0 ]; then
                    # Check if it's a contract creation from our address
                    FROM_ADDR=$(echo "$TX_RECEIPT" | grep "from" | head -1 | awk '{print $2}')
                    CONTRACT_ADDR=$(echo "$TX_RECEIPT" | grep "contractAddress" | awk '{print $2}')
                    
                    if [ "$FROM_ADDR" = "$WALLET_ADDR" ] && [ "$CONTRACT_ADDR" != "null" ] && [ -n "$CONTRACT_ADDR" ]; then
                        # Verify it's a MEV-Coin contract by checking the name
                        NAME=$(cast call "$CONTRACT_ADDR" "name()(string)" --rpc-url "$RPC_URL" 2>/dev/null)
                        if [ "$NAME" = "\"MEV-Coin\"" ]; then
                            echo "$CONTRACT_ADDR"
                            return
                        fi
                    fi
                fi
            done
        fi
    done
    
    error "Could not auto-detect contract address. Please provide it as an argument."
    exit 1
}

wait_for_target_block() {
    local current_block=$1
    local target_block=$2
    local lead_time=$3
    local blocks_to_wait=$((target_block - lead_time - current_block))
    
    if [ $blocks_to_wait -le 0 ]; then
        return
    fi
    
    local wait_seconds=$((blocks_to_wait - 1))  # Wait for all but the last block
    local eta_timestamp=$(($(date +%s) + wait_seconds))
    local eta_time=$(date -r $eta_timestamp '+%H:%M:%S')
    
    log "⏰ Waiting $blocks_to_wait blocks ($wait_seconds seconds) until submission block $((target_block - lead_time))"
    log "📅 MEV attempt ETA: $eta_time (target block $target_block)"
    
    # Show countdown for long waits
    if [ $wait_seconds -gt 30 ]; then
        local countdown=$wait_seconds
        while [ $countdown -gt 30 ]; do
            local minutes=$((countdown / 60))
            local seconds=$((countdown % 60))
            printf "\r⏳ Waiting ${minutes}m ${seconds}s until MEV opportunity..."
            sleep 10
            countdown=$((countdown - 10))
        done
        echo ""
        log "🔥 Final 30 seconds until precision timing mode"
        wait_seconds=30
    fi
    
    # Sleep until final 5 seconds
    local sleep_time=$((wait_seconds - 5))
    if [ $sleep_time -gt 0 ]; then
        sleep $sleep_time
        log "⚡ Final 5 seconds - entering active monitoring phase..."
    elif [ $wait_seconds -gt 0 ]; then
        log "🎯 Entering active monitoring phase..."
    fi
    current_block=$(cast block-number --rpc-url "$RPC_URL")
    
    while [ $current_block -lt $((target_block - lead_time)) ]; do
        sleep 0.1
        local prev_block=$current_block
        current_block=$(cast block-number --rpc-url "$RPC_URL")
        if [ $current_block -ne $prev_block ]; then
            log "📊 Block $current_block mined (target: $((target_block - lead_time)))"
        fi
    done
    
    log "🚀 TRIGGER! Submitting MEV capture transaction for block $target_block..."
}

send_mev_transfer() {
    local contract_addr=$1
    local recipient=$2
    
    log "Sending MEV bonus transfer to $recipient..."
    
    # Send transfer with 0 amount to trigger MEV bonus
    TX_HASH=$(cast send "$contract_addr" \
        "transfer(address,uint256)(bool)" \
        "$recipient" \
        "0" \
        --private-key "$PRIVATE_KEY" \
        --rpc-url "$RPC_URL" \
        --gas-limit 200000 \
        --gas-price 2000000000 \
        2>/dev/null)
    
    if [ $? -eq 0 ]; then
        log "Transaction sent: $TX_HASH"
        
        # Check immediately if we got the bonus
        BALANCE=$(cast call "$contract_addr" "balanceOf(address)(uint256)" "$recipient" --rpc-url "$RPC_URL")
        BALANCE_ETH=$(cast to-unit "$BALANCE" ether 2>/dev/null || echo "0")
        
        if [ "$BALANCE" != "0" ]; then
            log "🎉 SUCCESS! MEV bonus captured! New balance: $BALANCE_ETH MEV"
            return 0
        else
            warn "Transaction sent but no bonus received. May have been front-run."
            return 1
        fi
    else
        error "Failed to send transaction"
        return 1
    fi
}

main() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        print_usage
    fi
    
    check_dependencies
    
    CONTRACT_ADDRESS=$(get_contract_address "$1")
    WALLET_ADDRESS=$(get_wallet_address)
    
    log "MEV Bonus Hunter starting..."
    log "Contract: $CONTRACT_ADDRESS"
    log "Wallet: $WALLET_ADDRESS"
    log "RPC: $RPC_URL"
    
    # Verify contract
    NAME=$(cast call "$CONTRACT_ADDRESS" "name()(string)" --rpc-url "$RPC_URL" 2>/dev/null)
    if [ "$NAME" != "\"MEV-Coin\"" ]; then
        error "Invalid contract address or contract not found. Got name: $NAME"
        exit 1
    fi
    
    log "Contract verified: $NAME"
    
    # Statistics tracking
    ATTEMPTS=0
    SUCCESSES=0
    TOTAL_MEV_EARNED=0
    
    log "🎮 Starting MEV hunting session..."
    
    # Main loop
    while true; do
        CURRENT_BLOCK=$(cast block-number --rpc-url "$RPC_URL")
        
        # Calculate next MEV block (next block divisible by 100)
        NEXT_MEV_BLOCK=$(( (CURRENT_BLOCK / 100 + 1) * 100 ))
        BLOCKS_TO_WAIT=$((NEXT_MEV_BLOCK - CURRENT_BLOCK))
        
        # Get current balance before attempt
        CURRENT_BALANCE=$(cast call "$CONTRACT_ADDRESS" "balanceOf(address)(uint256)" "$WALLET_ADDRESS" --rpc-url "$RPC_URL")
        CURRENT_BALANCE_ETH=$(cast to-unit "$CURRENT_BALANCE" ether 2>/dev/null || echo "0")
        
        log "📈 Current MEV balance: $CURRENT_BALANCE_ETH MEV (Success rate: $SUCCESSES/$ATTEMPTS)"
        log "🎯 Next MEV opportunity: block $NEXT_MEV_BLOCK (in $BLOCKS_TO_WAIT blocks)"
        
        # Check if block has already been minted
        ALREADY_MINTED=$(cast call "$CONTRACT_ADDRESS" "hasBlockBeenMinted(uint256)(bool)" "$NEXT_MEV_BLOCK" --rpc-url "$RPC_URL")
        
        if [ "$ALREADY_MINTED" = "true" ]; then
            warn "Block $NEXT_MEV_BLOCK already minted by someone else! 😤"
            log "⏭️  Skipping to next opportunity..."
            sleep 1
            continue
        fi
        
        # Wait until we're close to the target block (with lead time for transaction processing)
        LEAD_TIME=8  # Submit transaction 8 blocks early to account for latency
        
        if [ $BLOCKS_TO_WAIT -gt $LEAD_TIME ]; then
            wait_for_target_block "$CURRENT_BLOCK" "$NEXT_MEV_BLOCK" "$LEAD_TIME"
        fi
        
        # Increment attempt counter
        ATTEMPTS=$((ATTEMPTS + 1))
        
        # Send the MEV capture transaction
        if send_mev_transfer "$CONTRACT_ADDRESS" "$WALLET_ADDRESS"; then
            SUCCESSES=$((SUCCESSES + 1))
            TOTAL_MEV_EARNED=$((TOTAL_MEV_EARNED + 100))
            log "💎 Total MEV earned this session: $TOTAL_MEV_EARNED MEV"
            log "⏳ Waiting for next MEV opportunity..."
            sleep 10
        else
            warn "❌ MEV capture attempt $ATTEMPTS failed - may have been front-run"
            log "⚡ Retrying soon..."
            sleep 5
        fi
    done
}

# Handle signals gracefully
trap 'log "MEV Bonus Hunter stopped."; exit 0' INT TERM

main "$@"
