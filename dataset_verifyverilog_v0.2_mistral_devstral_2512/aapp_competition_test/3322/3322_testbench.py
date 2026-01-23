import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_antique_shopping(dut):
    """Test the antique shopping module with various scenarios"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    for i in range(4):
        dut.antique_orig_shop[i].value = 0
        dut.antique_orig_price[i].value = 0
        dut.antique_knock_shop[i].value = 0
        dut.antique_knock_price[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Test 1: Original example (scaled to 3 antiques, 3 shops, k=2) ===")
    # Original: 1 30 2 50 -> Shop0:30, Shop1:50
    # Original: 2 70 3 10 -> Shop1:70, Shop2:10  
    # Original: 3 20 1 80 -> Shop2:20, Shop0:80
    # Expected: visit shops 0,2 -> buy: ant0@shop0=30, ant1@shop2=10, ant2@shop2=20 = 60
    
    dut.k.value = 2
    dut.antique_orig_shop[0].value = 0  # shop 1 -> index 0
    dut.antique_orig_price[0].value = 30
    dut.antique_knock_shop[0].value = 1  # shop 2 -> index 1  
    dut.antique_knock_price[0].value = 50
    
    dut.antique_orig_shop[1].value = 1  # shop 2 -> index 1
    dut.antique_orig_price[1].value = 70
    dut.antique_knock_shop[1].value = 2  # shop 3 -> index 2
    dut.antique_knock_price[1].value = 10
    
    dut.antique_orig_shop[2].value = 2  # shop 3 -> index 2
    dut.antique_orig_price[2].value = 20
    dut.antique_knock_shop[2].value = 0  # shop 1 -> index 0
    dut.antique_knock_price[2].value = 80
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 6000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.valid.value == 1, "Result should be valid"
    assert dut.min_cost.value == 60, f"Expected 60, got {dut.min_cost.value}"
    print(f"Test 1 passed: min_cost = {dut.min_cost.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Test 2: Impossible case (k=1) ===")
    # Same antiques but k=1 - should be impossible
    dut.k.value = 1
    dut.antique_orig_shop[0].value = 0
    dut.antique_orig_price[0].value = 30
    dut.antique_knock_shop[0].value = 1
    dut.antique_knock_price[0].value = 50
    
    dut.antique_orig_shop[1].value = 1
    dut.antique_orig_price[1].value = 70
    dut.antique_knock_shop[1].value = 2
    dut.antique_knock_price[1].value = 10
    
    dut.antique_orig_shop[2].value = 2
    dut.antique_orig_price[2].value = 20
    dut.antique_knock_shop[2].value = 0
    dut.antique_knock_price[2].value = 80
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 6000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.valid.value == 1, "Result should be valid"
    assert dut.min_cost.value == 0xFFFFFF, f"Expected -1 (0xFFFFFF), got {dut.min_cost.value}"
    print(f"Test 2 passed: correctly returned -1")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Test 3: Single shop works ===")
    # All antiques available at shop 0
    dut.k.value = 1
    dut.antique_orig_shop[0].value = 0
    dut.antique_orig_price[0].value = 10
    dut.antique_knock_shop[0].value = 0
    dut.antique_knock_price[0].value = 20
    
    dut.antique_orig_shop[1].value = 0
    dut.antique_orig_price[1].value = 30
    dut.antique_knock_shop[1].value = 1  # Not in shop 0
    dut.antique_knock_price[1].value = 5
    
    dut.antique_orig_shop[2].value = 1  # Not in shop 0
    dut.antique_orig_price[2].value = 40
    dut.antique_knock_shop[2].value = 0
    dut.antique_knock_price[2].value = 15
    
    # Wait, this is invalid - antique 1 needs shop 0 (original) = 30, antique 2 needs shop 0 (knockoff) = 15, antique 0 needs shop 0 (original) = 10
    # Total = 55
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 6000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.valid.value == 1, "Result should be valid"
    assert dut.min_cost.value == 55, f"Expected 55, got {dut.min_cost.value}"
    print(f"Test 3 passed: min_cost = {dut.min_cost.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
=== Test 4: Multiple valid combinations, choose cheapest ===")
    # 2 antiques, can use shop 0 OR shop 1 OR both
    # Ant0: shop0=100, shop1=10
    # Ant1: shop0=20, shop1=15
    # k=2
    # Options: shop0 only -> cost 100+20=120, shop1 only -> 10+15=25, both shops -> min(100,10)+min(20,15)=10+15=25
    # Answer: 25
    
    dut.k.value = 2
    dut.antique_orig_shop[0].value = 0
    dut.antique_orig_price[0].value = 100
    dut.antique_knock_shop[0].value = 1
    dut.antique_knock_price[0].value = 10
    
    dut.antique_orig_shop[1].value = 0
    dut.antique_orig_price[1].value = 20
    dut.antique_knock_shop[1].value = 1
    dut.antique_knock_price[1].value = 15
    
    # Set remaining antiques to be satisfied by both shops to make valid
    dut.antique_orig_shop[2].value = 0
    dut.antique_orig_price[2].value = 5
    dut.antique_knock_shop[2].value = 1
    dut.antique_knock_price[2].value = 5
    
    dut.antique_orig_shop[3].value = 0
    dut.antique_orig_price[3].value = 5
    dut.antique_knock_shop[3].value = 1
    dut.antique_knock_price[3].value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 6000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.valid.value == 1, "Result should be valid"
    # Expected: ant0 min=10, ant1 min=15, ant2 min=5, ant3 min=5 = 35
    expected = 10 + 15 + 5 + 5
    assert dut.min_cost.value == expected, f"Expected {expected}, got {dut.min_cost.value}"
    print(f"Test 4 passed: min_cost = {dut.min_cost.value}")
    
    print("
=== All tests completed ===")
    print(f"Summary: 4/4 tests passed")