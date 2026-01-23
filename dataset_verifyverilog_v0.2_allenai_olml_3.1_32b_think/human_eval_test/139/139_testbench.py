import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import struct

def to_32bit_int(value):
    """Return 32-bit representation"""
    return value & 0xFFFFFFFF

@cocotb.test()
async def test_special_factorial_basic(dut):
    """Test special_factorial for basic cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(30, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (1, 1),      # 1! = 1
        (2, 2),      # 1! * 2! = 1 * 2 = 2  
        (3, 12),     # 1! * 2! * 3! = 1 * 2 * 6 = 12
        (4, 288),    # 1! * 2! * 3! * 4! = 288
        (5, 34560),  # 1! * 2! * 3! * 4! * 5! = 34560
    ]
    
    total = len(test_cases)
    passed = 0
    
    for n_input, expected in test_cases:
        # Start computation
        dut.n.value = n_input
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 50
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
            print(f"Test n={n_input}: PASS (result={actual})")
        else:
            print(f"Test n={n_input}: FAIL (expected={expected}, got={actual})")
            raise TestFailure(f"n={n_input}: expected {expected}, got {actual}")
        
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")

@cocotb.test()
async def test_special_factorial_edge_cases(dut):
    """Test edge cases and verify done signal behavior"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(30, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test done signal goes low after start
    dut.n.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Ensure done is 0 during computation
    if dut.done.value == 1:
        raise TestFailure("Done should be 0 immediately after start")
    
    # Wait for completion
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    # Verify result is 12
    if int(dut.result.value) != 12:
        raise TestFailure(f"Edge case n=3: expected 12, got {int(dut.result.value)}")
    
    print("Edge case tests: PASS")
    print("All tests completed successfully")

@cocotb.test()
async def test_special_factorial_reset(dut):
    """Test that reset properly clears state"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Start a computation
    dut.rst_n.value = 1
    dut.n.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    # Reset in middle
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    
    # Check result is cleared
    if dut.result.value != 0:
        raise TestFailure(f"Reset should clear result, got {int(dut.result.value)}")
    
    if dut.done.value != 0:
        raise TestFailure("Reset should clear done")
    
    # Can we start new computation after reset?
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.n.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
    
    if int(dut.result.value) != 2:
        raise TestFailure(f"After reset, new computation failed: expected 2, got {int(dut.result.value)}")
    
    print("Reset test: PASS")
