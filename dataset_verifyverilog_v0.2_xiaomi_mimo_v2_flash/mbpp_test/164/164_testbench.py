import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_equivalent_divisors(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num1.value = 0
    dut.num2.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: 36 and 57 (should be False)
    # 36 divisors sum: 1 + 2 + 3 + 4 + 6 + 9 + 12 + 18 = 55 (excluding 36)
    # 57 divisors sum: 1 + 3 + 19 = 23 (excluding 57)
    dut.num1.value = 36
    dut.num2.value = 57
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 0, f"Test 1 Failed: 36 and 57 should be False, got {dut.result.value}"
    print("Test 1 passed: 36, 57 -> False")
    await RisingEdge(dut.clk)
    
    # Test 2: 2 and 4 (should be False)
    # 2 divisors sum: 1
    # 4 divisors sum: 1 + 2 = 3
    dut.num1.value = 2
    dut.num2.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 0, f"Test 2 Failed: 2 and 4 should be False, got {dut.result.value}"
    print("Test 2 passed: 2, 4 -> False")
    await RisingEdge(dut.clk)
    
    # Test 3: 23 and 47 (should be True)
    # 23 divisors sum: 1 (prime)
    # 47 divisors sum: 1 (prime)
    dut.num1.value = 23
    dut.num2.value = 47
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 1, f"Test 3 Failed: 23 and 47 should be True, got {dut.result.value}"
    print("Test 3 passed: 23, 47 -> True")
    await RisingEdge(dut.clk)
    
    # Test 4: 6 and 25 (should be True)
    # 6 divisors sum: 1 + 2 + 3 = 6
    # 25 divisors sum: 1 + 5 = 6
    dut.num1.value = 6
    dut.num2.value = 25
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 1, f"Test 4 Failed: 6 and 25 should be True, got {dut.result.value}"
    print("Test 4 passed: 6, 25 -> True")
    await RisingEdge(dut.clk)
    
    # Test 5: 1 and 1 (should be True)
    # 1 divisors sum: 1
    dut.num1.value = 1
    dut.num2.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 1, f"Test 5 Failed: 1 and 1 should be True, got {dut.result.value}"
    print("Test 5 passed: 1, 1 -> True")
    print("All tests passed!")