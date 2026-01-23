import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

# Helper to calculate GCD for verification
def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

@cocotb.test()
async def test_gcd_sequence_checker(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Sequence [5, 2, 1, 2, 1] found at j=4 for x=10
    # GCD(10, 4)=2 (NO), wait, x=10, j=4: 10,11,12,13,14 -> 2,1,2,1,2
    # Let's try to find a sequence that works.
    # Let's set x=6. GCD(6, 0)=6, GCD(6,1)=1, GCD(6,2)=2, GCD(6,3)=3, GCD(6,4)=2, GCD(6,5)=1
    # Sequence: [1, 2, 1] (k=3). Start j=1: GCD(6,1)=1, GCD(6,2)=2, GCD(6,3)=3 (NO)
    # Sequence: [2, 3, 2] (k=3). Start j=2: GCD(6,2)=2, GCD(6,3)=3, GCD(6,4)=2 (YES)
    
    dut.k_in.value = 3
    dut.a_0.value = 2
    dut.a_1.value = 3
    dut.a_2.value = 2
    dut.x_in.value = 6  # Row 6
    dut.m_limit.value = 20 # Assume m is large enough

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for valid
    while not dut.valid.value:
        await RisingEdge(dut.clk)
    
    assert dut.found.value == 1, f"Test 1 Failed: Expected found=1, got {dut.found.value}"
    assert dut.j_out.value == 2, f"Test 1 Failed: Expected j=2, got {dut.j_out.value}"
    print("Test 1 passed: Found sequence [2,3,2] at j=2 for x=6")

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Sequence that does NOT exist
    # Sequence [5, 2, 1, 2, 1] (k=5)
    # x=6. Sequence of length 5 starting at 0: [6,1,2,3,2]
    # We check if [5,2,1,2,1] exists. It does not for x=6.
    dut.k_in.value = 5
    dut.a_0.value = 5
    dut.a_1.value = 2
    dut.a_2.value = 1
    dut.a_3.value = 2
    dut.a_4.value = 1
    dut.x_in.value = 6
    dut.m_limit.value = 20

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    while not dut.valid.value:
        await RisingEdge(dut.clk)
    
    assert dut.found.value == 0, f"Test 2 Failed: Expected found=0, got {dut.found.value}"
    print("Test 2 passed: Correctly determined sequence [5,2,1,2,1] does not exist")
    
    # Test Case 3: Sequence [1, 1, 1] (k=3)
    # x=1. GCD(1, j) = 1 for all j.
    # This should exist at any j.
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.k_in.value = 3
    dut.a_0.value = 1
    dut.a_1.value = 1
    dut.a_2.value = 1
    dut.x_in.value = 1
    dut.m_limit.value = 10

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    while not dut.valid.value:
        await RisingEdge(dut.clk)
    
    assert dut.found.value == 1, f"Test 3 Failed: Expected found=1, got {dut.found.value}"
    print("Test 3 passed: Found sequence [1,1,1] for x=1")
    
    # Test Case 4: Edge case, sequence length 1
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.k_in.value = 1
    dut.a_0.value = 7
    dut.x_in.value = 14
    dut.m_limit.value = 10

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    while not dut.valid.value:
        await RisingEdge(dut.clk)
    
    # GCD(14, 0)=14, GCD(14, 1)=1, GCD(14, 7)=7
    # Should find at j=7
    assert dut.found.value == 1, f"Test 4 Failed: Expected found=1"
    assert dut.j_out.value == 7, f"Test 4 Failed: Expected j=7, got {dut.j_out.value}"
    print("Test 4 passed: Found single value 7 at j=7")

    # Test Case 5: Max constraints
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.k_in.value = 8
    # Set all to 1
    for i in range(8):
        dut[f"a_{i}"].value = 1
    dut.x_in.value = 1
    dut.m_limit.value = 255

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Should be fast
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    assert dut.valid.value == 1, "Test 5 Failed: Took too long"
    assert dut.found.value == 1, "Test 5 Failed: Should find [1]*8"
    print("Test 5 passed: Max size test")

    print(f"
Tests completed successfully.")