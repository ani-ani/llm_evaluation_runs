import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

# Helper to calculate the expected values
def solve_subset(n, k, coins):
    # DP table: dp[s] is a bitmask of possible sub-sums for total sum s
    dp = [0] * (k + 1)
    dp[0] = 1  # Base case: sum 0, sub-sum 0 is possible
    
    for c in coins:
        if c > k: continue
        new_dp = dp[:] # Copy current state
        for s in range(k, c - 1, -1):
            if dp[s - c] != 0:
                # Include coin c in sum s
                # Possible sub-sums: existing sub-sums of s-c (excluding c) 
                # AND existing sub-sums of s-c including c (shifted by c)
                new_dp[s] |= dp[s - c] | (dp[s - c] << c)
        dp = new_dp
    
    # Extract results for sum k
    results = []
    mask = dp[k]
    for x in range(k + 1):
        if (mask >> x) & 1:
            results.append(x)
    return results

@cocotb.test()
async def test_subset_coins(dut):
    """Test the subset coins DP module"""
    
    # Setup clock (50MHz)
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_coin.value = 0
    dut.coin_in.value = 0
    await Timer(100, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (3, 50, [25, 25, 50]), # Result: 0, 25, 50
        (6, 18, [5, 6, 1, 10, 12, 2]), # Result: 0, 1, 2, 3, 5, 6, 7, 8, 10, 11, 12, 13, 15, 16, 17, 18
        (1, 79, [79]), # Result: 0, 79
        (8, 42, [7, 24, 22, 25, 31, 12, 17, 26]), # Result: 0, 17, 25, 42
    ]
    
    for n, k, coins in test_cases:
        # Scale check: if k > 128, we skip or reduce (here we assume K=128 module parameter)
        if k > 128:
            print(f"Skipping test case k={k} (exceeds module parameter K=128)")
            continue
            
        print(f"Running test: n={n}, k={k}, coins={coins}")
        
        # 1. Load Coins
        dut.load_coin.value = 1
        for c in coins:
            dut.coin_in.value = c
            await RisingEdge(dut.clk)
        dut.load_coin.value = 0
        await RisingEdge(dut.clk)
        
        # 2. Start Processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 3. Wait for Done
        timeout = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 200000:
                raise TestFailure("Timeout waiting for done signal")
        
        # 4. Read Output
        # The module outputs stream of valid indices
        received_values = []
        output_done = False
        
        # Wait for first valid or done
        await RisingEdge(dut.clk)
        
        # Collect outputs while done is low or we see valids
        # Module likely streams out values in subsequent cycles
        for _ in range(150): # Safety limit
            if dut.result_valid.value:
                received_values.append(int(dut.result_index.value))
            if dut.done.value and not dut.result_valid.value:
                break
            await RisingEdge(dut.clk)
            
        # Verify
        expected = solve_subset(n, k, coins)
        
        print(f"Expected: {sorted(expected)}")
        print(f"Received: {sorted(received_values)}")
        
        if sorted(received_values) != sorted(expected):
            raise TestFailure(f"Mismatch! Expected {expected}, got {received_values}")
            
    print("All tests passed!")