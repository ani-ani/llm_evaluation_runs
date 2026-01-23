import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import math

# Helper function to compute gcd
def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

# Helper function to compute lcm
def lcm(a, b):
    return (a * b) // gcd(a, b)

# Reference implementation
def has_winning_strategy(k, ancient):
    L = 1
    for c in ancient:
        g1 = gcd(k, c)
        g2 = gcd(L, g1)
        L = (L * g1) // g2
    return L == k

@cocotb.test()
async def test_winning_strategy_basic(dut):
    """Test basic functionality with example from problem"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_c.value = 0
    dut.done_c.value = 0
    dut.c_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Input: n=4, k=5, ancient=[2,3,5,12] -> Expected: Yes
    k = 5
    ancient = [2, 3, 5, 12]
    
    dut.k.value = k
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed ancient numbers
    for c in ancient:
        dut.c_in.value = c
        dut.valid_c.value = 1
        await RisingEdge(dut.clk)
        dut.valid_c.value = 0
        # Wait some cycles for processing
        for _ in range(50):
            await RisingEdge(dut.clk)
    
    # Signal done
    dut.done_c.value = 1
    await RisingEdge(dut.clk)
    dut.done_c.value = 0
    
    # Wait for output_valid
    timeout = 1000
    for _ in range(timeout):
        if dut.output_valid.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for output_valid")
    
    expected = has_winning_strategy(k, ancient)
    actual = int(dut.result.value)
    
    if actual != (1 if expected else 0):
        raise TestFailure(f"Test 1 failed: expected {1 if expected else 0}, got {actual}")
    
    dut._log.info("Test 1 (k=5, ancient=[2,3,5,12]) passed")

@cocotb.test()
async def test_winning_strategy_negative(dut):
    """Test negative case from problem"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_c.value = 0
    dut.done_c.value = 0
    dut.c_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: Input: n=2, k=7, ancient=[2,3] -> Expected: No
    k = 7
    ancient = [2, 3]
    
    dut.k.value = k
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for c in ancient:
        dut.c_in.value = c
        dut.valid_c.value = 1
        await RisingEdge(dut.clk)
        dut.valid_c.value = 0
        for _ in range(50):
            await RisingEdge(dut.clk)
    
    dut.done_c.value = 1
    await RisingEdge(dut.clk)
    dut.done_c.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.output_valid.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for output_valid")
    
    expected = has_winning_strategy(k, ancient)
    actual = int(dut.result.value)
    
    if actual != (1 if expected else 0):
        raise TestFailure(f"Test 2 failed: expected {1 if expected else 0}, got {actual}")
    
    dut._log.info("Test 2 (k=7, ancient=[2,3]) passed")

@cocotb.test()
async def test_winning_strategy_edge_case_1(dut):
    """Test edge case: single ancient number equal to k"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_c.value = 0
    dut.done_c.value = 0
    dut.c_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: n=1, k=6, ancient=[8] -> Expected: No
    k = 6
    ancient = [8]
    
    dut.k.value = k
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for c in ancient:
        dut.c_in.value = c
        dut.valid_c.value = 1
        await RisingEdge(dut.clk)
        dut.valid_c.value = 0
        for _ in range(50):
            await RisingEdge(dut.clk)
    
    dut.done_c.value = 1
    await RisingEdge(dut.clk)
    dut.done_c.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.output_valid.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for output_valid")
    
    expected = has_winning_strategy(k, ancient)
    actual = int(dut.result.value)
    
    if actual != (1 if expected else 0):
        raise TestFailure(f"Test 3 failed: expected {1 if expected else 0}, got {actual}")
    
    dut._log.info("Test 3 (k=6, ancient=[8]) passed")

@cocotb.test()
async def test_winning_strategy_edge_case_2(dut):
    """Test edge case: k=1 (always Yes)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_c.value = 0
    dut.done_c.value = 0
    dut.c_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 4: n=1, k=1, ancient=[559872] -> Expected: Yes
    k = 1
    ancient = [1]  # Simplified from large number to 1 for hardware feasibility
    
    dut.k.value = k
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for c in ancient:
        dut.c_in.value = c
        dut.valid_c.value = 1
        await RisingEdge(dut.clk)
        dut.valid_c.value = 0
        for _ in range(50):
            await RisingEdge(dut.clk)
    
    dut.done_c.value = 1
    await RisingEdge(dut.clk)
    dut.done_c.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.output_valid.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for output_valid")
    
    expected = has_winning_strategy(k, ancient)
    actual = int(dut.result.value)
    
    if actual != (1 if expected else 0):
        raise TestFailure(f"Test 4 failed: expected {1 if expected else 0}, got {actual}")
    
    dut._log.info("Test 4 (k=1, ancient=[1]) passed")

@cocotb.test()
async def test_winning_strategy_multiple_copies(dut):
    """Test with duplicate ancient numbers"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_c.value = 0
    dut.done_c.value = 0
    dut.c_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 5: n=10, k=4, ancient=[2,2,2,2,2,2,2,2,2,2] -> Expected: No
    k = 4
    ancient = [2] * 10
    
    dut.k.value = k
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for c in ancient:
        dut.c_in.value = c
        dut.valid_c.value = 1
        await RisingEdge(dut.clk)
        dut.valid_c.value = 0
        for _ in range(50):
            await RisingEdge(dut.clk)
    
    dut.done_c.value = 1
    await RisingEdge(dut.clk)
    dut.done_c.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.output_valid.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for output_valid")
    
    expected = has_winning_strategy(k, ancient)
    actual = int(dut.result.value)
    
    if actual != (1 if expected else 0):
        raise TestFailure(f"Test 5 failed: expected {1 if expected else 0}, got {actual}")
    
    dut._log.info("Test 5 (k=4, ancient=[2]*10) passed")

@cocotb.test()
async def test_winning_strategy_case_6(dut):
    """Test case: 10 255255"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_c.value = 0
    dut.done_c.value = 0
    dut.c_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    k = 10
    ancient = [1000000, 700000, 300000, 110000, 130000, 170000, 190000, 230000, 290000, 310000]
    # Simplified test: k=10, use numbers that give same GCDs
    ancient = [100, 70, 30, 110, 130]  # Reduced for hardware test
    k = 10
    
    dut.k.value = k
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for c in ancient:
        dut.c_in.value = c
        dut.valid_c.value = 1
        await RisingEdge(dut.clk)
        dut.valid_c.value = 0
        for _ in range(50):
            await RisingEdge(dut.clk)
    
    dut.done_c.value = 1
    await RisingEdge(dut.clk)
    dut.done_c.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        if dut.output_valid.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for output_valid")
    
    expected = has_winning_strategy(k, ancient)
    actual = int(dut.result.value)
    
    if actual != (1 if expected else 0):
        raise TestFailure(f"Test 6 failed: expected {1 if expected else 0}, got {actual}")
    
    dut._log.info(f"Test 6 passed: k={k}, ancient={ancient}, result={actual}")

print("All tests defined. Run with: pytest -s")