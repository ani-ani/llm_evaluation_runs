import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_necklace_splitter(dut):
    """Test necklace splitter with various cases"""
    
    # Initialize clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.beads[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (k, n, beads, expected_result, description)
        (3, 4, [1, 2, 2, 1, 0, 0, 0, 0], 1, "Example 1: YES"),
        (3, 4, [2, 2, 4, 1, 0, 0, 0, 0], 0, "Example 2: NO"),
        (2, 4, [1, 2, 1, 2, 0, 0, 0, 0], 1, "Simple equal split"),
        (2, 4, [1, 1, 1, 1, 0, 0, 0, 0], 1, "All equal"),
        (4, 8, [1, 1, 1, 1, 1, 1, 1, 1], 1, "8 beads, 4 friends"),
        (2, 3, [5, 5, 0, 0, 0, 0, 0, 0], 1, "Two equal beads"),
        (2, 3, [5, 6, 0, 0, 0, 0, 0, 0], 0, "Two unequal beads"),
        (1, 4, [1, 2, 3, 4], 1, "One friend always YES"),
        (3, 6, [1, 2, 3, 1, 2, 3], 1, "Pattern repeated"),
        (3, 6, [1, 2, 3, 2, 2, 2], 0, "No valid partition"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for k, n, beads, expected, desc in test_cases:
        print(f"
Test: {desc}")
        print(f"  k={k}, n={n}, beads={beads[:n]}")
        
        # Set inputs
        dut.k.value = k
        dut.n.value = n
        for i in range(8):
            dut.beads[i].value = beads[i]
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 300:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 300:
            print(f"  ERROR: Timeout - took more than 300 cycles")
            continue
        
        # Check result
        actual = int(dut.result.value)
        expected_val = 1 if expected else 0
        
        if actual == expected_val:
            print(f"  PASS: result={actual} (expected {expected_val})")
            passed += 1
        else:
            print(f"  FAIL: result={actual} (expected {expected_val})")
    
    print(f"
{'='*50}")
    print(f"SUMMARY: {passed}/{total} tests passed")
    print(f"{'='*50}")
    
    assert passed == total, f"Only {passed} out of {total} tests passed"

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(30, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Edge case: All beads same, divisible
    dut.k.value = 4
    dut.n.value = 4
    for i in range(8):
        dut.beads[i].value = 5 if i < 4 else 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 200, "Timeout on edge case"
    assert dut.result.value == 1, "Should be YES for equal beads"
    print("Edge case: Equal beads - PASS")
    
    # Edge case: Single bead
    dut.k.value = 1
    dut.n.value = 1
    dut.beads[0].value = 42
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.result.value == 1, "Single bead with k=1 should be YES"
    print("Edge case: Single bead - PASS")
    
    # Edge case: Total not divisible by k
    dut.k.value = 3
    dut.n.value = 3
    dut.beads[0].value = 5
    dut.beads[1].value = 5
    dut.beads[2].value = 5
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.result.value == 0, "Total 15 not divisible by 3 should be NO"
    print("Edge case: Indivisible total - PASS")
