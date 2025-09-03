#!/bin/bash

# MEV-Coin Dashboard Generator
# This script queries MEV-Coin data from the blockchain and generates a static HTML dashboard

set -e
set -x

# Configuration
CONTRACT_ADDRESS="0x3c257c32Ac296d20D86D9F8bD6225915F830aa0E"
RPC_URL="${ETH_RPC_URL:-http://localhost:8545}"
OUTPUT_FILE="../docs/index.html"

echo "🚀 Generating MEV-Coin Dashboard..."

# Function to get recent MEV bonus events
get_mev_bonuses() {
    echo "📊 Fetching recent MEV bonuses..."
    
    # Get MEVBonus event signature: keccak256("MEVBonus(address,uint256,uint256)")
    EVENT_SIG="0x826b1be11be0f32436b1ada51990b85f7ce3cc224a513b6a3fb726005d818726"
    
    # Get recent blocks to search for events (last 1000 blocks)
    current_block=$(cast block-number --rpc-url "$RPC_URL")
    from_block=$((current_block - 1000))
    if [ $from_block -lt 0 ]; then
        from_block=0
    fi
    
    # Query MEVBonus events
    cast logs --rpc-url "$RPC_URL" \
        --from-block "$from_block" \
        --address "$CONTRACT_ADDRESS" \
        "$EVENT_SIG" | head -20 || echo "No recent MEV events found"
}

# Function to get top MEV-Coin holders
get_top_holders() {
    echo "💰 Fetching top MEV-Coin balances..."
    
    # For demonstration, we'll check some common addresses
    # In a real implementation, you'd need to track Transfer events to find all holders
    
    addresses=(
        "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"  # Default anvil account 0
        "0x70997970c51812dc3a010c7d01b50e0d17dc79c8"  # Default anvil account 1
        "0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc"  # Default anvil account 2
        "0x90f79bf6eb2c4f870365e785982e1f101e93b906"  # Default anvil account 3
    )
    
    holder_data=""
    for addr in "${addresses[@]}"; do
        balance=$(cast call --rpc-url "$RPC_URL" "$CONTRACT_ADDRESS" "balanceOf(address)" "$addr" 2>/dev/null || echo "0x0")
        # Handle empty or invalid responses
        if [ -z "$balance" ] || [ "$balance" = "0x" ]; then
            balance="0x0"
        fi
        if [ "$balance" != "0x0" ] && [ "$balance" != "0" ]; then
            # Convert from wei to tokens (18 decimals)
            balance_eth=$(cast to-unit "$balance" ether 2>/dev/null || echo "0.0")
            if [ "$balance_eth" != "0.0" ]; then
                holder_data="$holder_data<tr><td>$addr</td><td>$balance_eth MEV</td></tr>"
            fi
        fi
    done
    
    echo "$holder_data"
}

# Function to get contract stats
get_contract_stats() {
    echo "📈 Fetching contract statistics..."
    
    # Get total supply
    total_supply=$(cast call --rpc-url "$RPC_URL" "$CONTRACT_ADDRESS" "totalSupply()" 2>/dev/null || echo "0x0")
    # Handle empty or invalid responses
    if [ -z "$total_supply" ] || [ "$total_supply" = "0x" ]; then
        total_supply="0x0"
    fi
    total_supply_eth=$(cast to-unit "$total_supply" ether 2>/dev/null || echo "0.0")
    
    # Get current block
    current_block=$(cast block-number --rpc-url "$RPC_URL")
    
    echo "$total_supply_eth|$current_block"
}

# Generate HTML dashboard
generate_html() {
    local mev_events="$1"
    local holder_data="$2" 
    local stats="$3"
    
    total_supply=$(echo "$stats" | cut -d'|' -f1)
    current_block=$(echo "$stats" | cut -d'|' -f2)
    
    cat > "$OUTPUT_FILE" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MEV-Coin Dashboard</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            padding: 30px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
            border-bottom: 3px solid #667eea;
            padding-bottom: 20px;
        }
        .header h1 {
            color: #667eea;
            margin: 0;
            font-size: 2.5em;
            font-weight: 700;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        .stat-card {
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
            color: white;
            padding: 25px;
            border-radius: 12px;
            text-align: center;
            box-shadow: 0 10px 20px rgba(0,0,0,0.1);
        }
        .stat-card h3 {
            margin: 0 0 10px 0;
            font-size: 1.1em;
            opacity: 0.9;
        }
        .stat-card .value {
            font-size: 2em;
            font-weight: bold;
            margin: 0;
        }
        .section {
            margin-bottom: 40px;
            background: white;
            border-radius: 12px;
            padding: 25px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.08);
        }
        .section h2 {
            color: #667eea;
            margin-top: 0;
            margin-bottom: 20px;
            font-size: 1.8em;
            border-bottom: 2px solid #eee;
            padding-bottom: 10px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            padding: 15px;
            text-align: left;
            border-bottom: 1px solid #eee;
        }
        th {
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: white;
            font-weight: 600;
        }
        tr:hover {
            background-color: #f8f9ff;
        }
        .address {
            font-family: 'Courier New', monospace;
            background: #f0f0f0;
            padding: 5px 8px;
            border-radius: 4px;
            font-size: 0.9em;
        }
        .timestamp {
            color: #666;
            font-size: 0.9em;
        }
        .no-data {
            text-align: center;
            color: #666;
            font-style: italic;
            padding: 40px;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #eee;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🪙 MEV-Coin Dashboard</h1>
            <p>Real-time MEV-Coin statistics and analytics</p>
        </div>

        <div class="stats-grid">
            <div class="stat-card">
                <h3>Total Supply</h3>
                <p class="value">$total_supply MEV</p>
            </div>
            <div class="stat-card">
                <h3>Current Block</h3>
                <p class="value">$current_block</p>
            </div>
            <div class="stat-card">
                <h3>Contract Address</h3>
                <p class="value" style="font-size: 0.8em;">$CONTRACT_ADDRESS</p>
            </div>
        </div>

        <div class="section">
            <h2>🎉 Recent MEV Bonuses</h2>
            <p>Latest MEV bonus events (100 MEV tokens awarded at every 100th block)</p>
            <div id="mev-events">
                <div class="no-data">
                    <p>No recent MEV bonus events found. MEV bonuses are awarded when transfers occur at blocks that are multiples of 100.</p>
                    <p>Try making some transfers to trigger MEV bonuses!</p>
                </div>
            </div>
        </div>

        <div class="section">
            <h2>🏆 Top MEV-Coin Holders</h2>
            <table>
                <thead>
                    <tr>
                        <th>Address</th>
                        <th>Balance</th>
                    </tr>
                </thead>
                <tbody>
                    $holder_data
                    $(if [ -z "$holder_data" ]; then echo '<tr><td colspan="2" class="no-data">No holders with significant balances found</td></tr>'; fi)
                </tbody>
            </table>
        </div>

        <div class="footer">
            <p>Generated on $(date) | Data from blockchain at $RPC_URL</p>
            <p>MEV-Coin Contract: <span class="address">$CONTRACT_ADDRESS</span></p>
        </div>
    </div>
</body>
</html>
EOF
}

# Main execution
main() {
    echo "🔍 Connecting to blockchain at $RPC_URL..."
    
    # Ensure docs directory exists for GitHub Pages
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    
    # Check if we can connect to the RPC
    if ! cast block-number --rpc-url "$RPC_URL" &>/dev/null; then
        echo "❌ Error: Cannot connect to blockchain at $RPC_URL"
        echo "Make sure your local blockchain (anvil) is running on port 8545"
        exit 1
    fi
    
    echo "✅ Connected to blockchain successfully"
    
    # Get data
    mev_events=$(get_mev_bonuses)
    holder_data=$(get_top_holders)
    stats=$(get_contract_stats)
    
    # Generate HTML
    generate_html "$mev_events" "$holder_data" "$stats"
    
    echo "✅ Dashboard generated successfully: $OUTPUT_FILE"
    echo "🌐 Open $OUTPUT_FILE in your browser to view the dashboard"
    
    # Optional: Auto-open in browser (uncomment if desired)
    # open "$OUTPUT_FILE"  # macOS
    # xdg-open "$OUTPUT_FILE"  # Linux
}

# Run main function
main "$@"
