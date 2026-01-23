import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def get_position(bet, camel):
    """Get position of camel in bet (0-indexed)"""
    for pos, c in enumerate(bet):
        if c == camel:
            return pos
    return -1

def count_consistent_pairs(n, jaap, jan, thijs):
    """Count pairs that are in same order in all 3 bets"""
    count = 0
    for i in range(1, n+1):
        for j in range(i+1, n+1):
            pos_a_i = get_position(jaap, i)
            pos_a_j = get_position(jaap, j)
            pos_b_i = get_position(jan, i)
            pos_b_j = get_position(jan, j)
            pos_c_i = get_position(thijs, i)
            pos_c_j = get_position(thijs, j)
            
            if (pos_a_i < pos_a_j) and (pos_b_i < pos_b_j) and (pos_c_i < pos_c_j):
                count += 1
    return count

@cocotb.test()
async def test_camel_race_bets(dut):
    """Test camel race bets module"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(32):
        dut.a[i].value = 0
        dut.b[i].value = 0
        dut.c[i].value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=3, all reverse orders
    dut._log.info("Test 1: Sample Input 1")
    n1 = 3
    jaap1 = [3, 2, 1]
    jan1 = [1, 2, 3]
    thijs1 = [1, 2, 3]
    
    dut.n.value = n1
    for i in range(n1):
        dut.a[i].value = jaap1[i]
        dut.b[i].value = jan1[i]
        dut.c[i].value = thijs1[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    expected1 = count_consistent_pairs(n1, jaap1, jan1, thijs1)
    assert dut.result.value == expected1, f"Test 1 failed: expected {expected1}, got {dut.result.value}"
    dut._log.info(f"Test 1 passed: result={dut.result.value}")
    await RisingEdge(dut.clk)
    
    # Test case 2: n=4, mixed orders
    dut._log.info("Test 2: Sample Input 2")
    n2 = 4
    jaap2 = [2, 3, 1, 4]
    jan2 = [2, 1, 4, 3]
    thijs2 = [2, 4, 3, 1]
    
    dut.n.value = n2
    for i in range(n2):
        dut.a[i].value = jaap2[i]
        dut.b[i].value = jan2[i]
        dut.c[i].value = thijs2[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    expected2 = count_consistent_pairs(n2, jaap2, jan2, thijs2)
    assert dut.result.value == expected2, f"Test 2 failed: expected {expected2}, got {dut.result.value}"
    dut._log.info(f"Test 2 passed: result={dut.result.value}")
    await RisingEdge(dut.clk)
    
    # Test case 3: n=5, all same order
    dut._log.info("Test 3: All same order")
    n3 = 5
    jaap3 = [1, 2, 3, 4, 5]
    jan3 = [1, 2, 3, 4, 5]
    thijs3 = [1, 2, 3, 4, 5]
    
    dut.n.value = n3
    for i in range(n3):
        dut.a[i].value = jaap3[i]
        dut.b[i].value = jan3[i]
        dut.c[i].value = thijs3[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    expected3 = count_consistent_pairs(n3, jaap3, jan3, thijs3)
    assert dut.result.value == expected3, f"Test 3 failed: expected {expected3}, got {dut.result.value}"
    dut._log.info(f"Test 3 passed: result={dut.result.value}")
    await RisingEdge(dut.clk)
    
    # Test case 4: n=2, simple case
    dut._log.info("Test 4: n=2 minimal")
    n4 = 2
    jaap4 = [1, 2]
    jan4 = [1, 2]
    thijs4 = [1, 2]
    
    dut.n.value = n4
    for i in range(n4):
        dut.a[i].value = jaap4[i]
        dut.b[i].value = jan4[i]
        dut.c[i].value = thijs4[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    expected4 = count_consistent_pairs(n4, jaap4, jan4, thijs4)
    assert dut.result.value == expected4, f"Test 4 failed: expected {expected4}, got {dut.result.value}"
    dut._log.info(f"Test 4 passed: result={dut.result.value}")
    await RisingEdge(dut.clk)
    
    # Test case 5: n=6, random order
    dut._log.info("Test 5: n=6 random")
    n5 = 6
    jaap5 = [6, 5, 4, 3, 2, 1]
    jan5 = [2, 4, 6, 1, 3, 5]
    thijs5 = [1, 3, 5, 2, 4, 6]
    
    dut.n.value = n5
    for i in range(n5):
        dut.a[i].value = jaap5[i]
        dut.b[i].value = jan5[i]
        dut.c[i].value = thijs5[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    expected5 = count_consistent_pairs(n5, jaap5, jan5, thijs5)
    assert dut.result.value == expected5, f"Test 5 failed: expected {expected5}, got {dut.result.value}"
    dut._log.info(f"Test 5 passed: result={dut.result.value}")
    
    # Summary
    total_tests = 5
    passed_tests = 5
    dut._log.info(f"
Summary: {passed_tests}/{total_tests} tests passed")