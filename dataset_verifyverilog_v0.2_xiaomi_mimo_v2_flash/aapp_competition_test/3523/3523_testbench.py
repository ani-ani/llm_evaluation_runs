import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def compute_max_coins(price, n1, n5, n10, n25):
    """Python reference implementation for verification"""
    # DP: dp[amount] = max coins used to reach amount, or -1 if impossible
    # But we need to respect coin counts AND maximize coins
    # Since we want MAX coins, use smaller denominations first
    
    dp = [-1] * (price + 1)
    dp[0] = 0
    
    # Process coins in order: 1, 5, 10, 25 (small to large to maximize count)
    coins = [(1, n1), (5, n5), (10, n10), (25, n25)]
    
    for denom, count in coins:
        if count == 0:
            continue
        # Iterate backwards to avoid reuse within same iteration
        for amount in range(price, -1, -1):
            if dp[amount] >= 0:
                # Try using k coins of this denomination
                for k in range(1, count + 1):
                    new_amount = amount + k * denom
                    if new_amount <= price:
                        new_coins = dp[amount] + k
                        if new_coins > dp[new_amount]:
                            dp[new_amount] = new_coins
    
    return dp[price] if dp[price] >= 0 else -1

@cocotb.test()
async def test_coin_change_basic(dut):
    """Test basic functionality"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.price.value = 0
    dut.n1.value = 0
    dut.n5.value = 0
    dut.n10.value = 0
    dut.n25.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 1: Price 13, coins 3,2,1,1 → 5 coins
    # Should use 3×1c + 2×5c = 13 cents, 5 coins
    dut.price.value = 13
    dut.n1.value = 3
    dut.n5.value = 2
    dut.n10.value = 1
    dut.n25.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 1: Timeout - computation didn't finish")
    
    if dut.impossible.value:
        raise TestFailure(f"Test 1: Got Impossible, expected 5")
    
    if dut.max_coins.value != 5:
        raise TestFailure(f"Test 1: Expected 5, got {dut.max_coins.value}")
    
    print("Test 1 passed: Price 13, coins 3,2,1,1 → 5 coins")
    await Timer(20, units='ns')

@cocotb.test()
async def test_coin_change_impossible(dut):
    """Test impossible case"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.price.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 2: Price 13, coins 2,2,1,1 → Impossible
    # Can make: 2×1+2×5 = 12, 2×1+1×10=12, 2×5+1×10=20 (too big)
    # Cannot make 13
    dut.price.value = 13
    dut.n1.value = 2
    dut.n5.value = 2
    dut.n10.value = 1
    dut.n25.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 2: Timeout")
    
    if not dut.impossible.value:
        raise TestFailure(f"Test 2: Expected Impossible, got {dut.max_coins.value}")
    
    print("Test 2 passed: Price 13, coins 2,2,1,1 → Impossible")
    await Timer(20, units='ns')

@cocotb.test()
async def test_coin_change_zero(dut):
    """Test zero price"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.price.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    dut.price.value = 0
    dut.n1.value = 10
    dut.n5.value = 10
    dut.n10.value = 10
    dut.n25.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 3: Timeout")
    
    if dut.impossible.value:
        raise TestFailure("Test 3: Zero price should be achievable with 0 coins")
    
    if dut.max_coins.value != 0:
        raise TestFailure(f"Test 3: Expected 0, got {dut.max_coins.value}")
    
    print("Test 3 passed: Price 0 → 0 coins")
    await Timer(20, units='ns')

@cocotb.test()
async def test_coin_change_max_coins(dut):
    """Test maximizing coins"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.price.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Price 50, many small coins available
    # Should use 50×1c = 50 coins (better than 10×5c = 10 coins)
    dut.price.value = 50
    dut.n1.value = 100
    dut.n5.value = 20
    dut.n10.value = 10
    dut.n25.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 4: Timeout")
    
    if dut.impossible.value:
        raise TestFailure("Test 4: Should be possible")
    
    # With unlimited 1c, should use all 1c = 50 coins
    if dut.max_coins.value != 50:
        raise TestFailure(f"Test 4: Expected 50 coins (all 1c), got {dut.max_coins.value}")
    
    print("Test 4 passed: Price 50 → 50 coins (maximized)")
    await Timer(20, units='ns')

@cocotb.test()
async def test_coin_change_mixed(dut):
    """Test mixed coin usage"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.price.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Price 30: 10×1c + 4×5c = 30, 14 coins
    # Alternative: 3×10c = 30, 3 coins (min), we want MAX = 14
    dut.price.value = 30
    dut.n1.value = 10
    dut.n5.value = 4
    dut.n10.value = 5
    dut.n25.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test 5: Timeout")
    
    if dut.impossible.value:
        raise TestFailure("Test 5: Should be possible")
    
    if dut.max_coins.value != 14:
        raise TestFailure(f"Test 5: Expected 14, got {dut.max_coins.value}")
    
    print("Test 5 passed: Price 30 → 14 coins (mixed usage)")
    await Timer(20, units='ns')

print("Coin Change Max Coins Test Suite - All tests defined")
print("To run: pytest -x --tb=short coin_change_max_tb.py")
