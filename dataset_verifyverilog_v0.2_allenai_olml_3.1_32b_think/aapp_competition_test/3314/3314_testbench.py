import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

# Helper to encode wheel strings to 2-bit arrays
def encode_wheel(s):
    mapping = {'A': 0, 'B': 1, 'C': 2}
    # Pad to 8 chars if shorter
    padded = s.ljust(8, 'A')
    return [mapping[c] for c in padded[:8]]

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_wheel_rotations(dut):
    """Test Wheel Rotations Solver"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test Case 1: ABC, ABC, ABC -> Should be 2
    # Wheel 0: A B C A B C A A
    # Wheel 1: A B C A B C A A
    # Wheel 2: A B C A B C A A
    # Offset 1=1, Offset 2=2 (rotations)
    w0 = encode_wheel("ABC")
    w1 = encode_wheel("ABC")
    w2 = encode_wheel("ABC")
    
    dut.wheel0.value = w0
    dut.wheel1.value = w1
    dut.wheel2.value = w2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Expected result: 2 rotations
    if dut.result.value != 2:
        raise TestFailure(f"Test 1 failed: Expected 2, got {int(dut.result.value)}")
    if not dut.valid.value:
        raise TestFailure("Test 1 failed: Expected valid=1")
    
    print(f"Test 1 Passed: Result={int(dut.result.value)}")
    
    await RisingEdge(dut.clk)
    await reset_dut(dut)
    
    # Test Case 2: ABBBAAAA, BBBCCCBB, CCCCCAAC -> Should be 3
    w0 = encode_wheel("ABBBAAAA")
    w1 = encode_wheel("BBBCCCBB")
    w2 = encode_wheel("CCCCAAAC")
    
    dut.wheel0.value = w0
    dut.wheel1.value = w1
    dut.wheel2.value = w2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.result.value != 3:
        raise TestFailure(f"Test 2 failed: Expected 3, got {int(dut.result.value)}")
    if not dut.valid.value:
        raise TestFailure("Test 2 failed: Expected valid=1")
    
    print(f"Test 2 Passed: Result={int(dut.result.value)}")
    
    await RisingEdge(dut.clk)
    await reset_dut(dut)
    
    # Test Case 3: AABB, BBCC, ACAC -> Should be -1
    w0 = encode_wheel("AABB")
    w1 = encode_wheel("BBCC")
    w2 = encode_wheel("ACAC")
    
    dut.wheel0.value = w0
    dut.wheel1.value = w1
    dut.wheel2.value = w2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # We use 15 to represent -1 in the hardware, or check valid bit
    # Spec says result=15 for -1, valid=0 for -1
    if dut.valid.value:
        raise TestFailure(f"Test 3 failed: Expected invalid (valid=0), got valid=1, result={int(dut.result.value)}")
    
    print(f"Test 3 Passed: Result={int(dut.result.value)} (Invalid as expected)")
    
    print("All tests passed!")
