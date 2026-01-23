import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure, TestSuccess
import random

@cocotb.test()
async def test_replant_solver(dut):
    """Test the replant solver module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_species.value = 0
    dut.species_in.value = 0
    dut.N.value = 0
    dut.M.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (N, species_list, expected_result)
    test_cases = [
        (3, [2, 1, 1], 1),
        (3, [1, 2, 3], 0),
        (6, [1, 2, 1, 3, 1, 1], 2),
        (1, [1], 0),
        (5, [5, 4, 3, 2, 1], 4),
        (4, [1, 2, 1, 2], 1)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for N, species, expected in test_cases:
        dut._log.info(f"Running test case: N={N}, species={species}, expected={expected}")
        
        # Load species into buffer
        dut.N.value = N
        dut.M.value = 16
        await RisingEdge(dut.clk)
        
        for i in range(N):
            dut.species_in.value = species[i]
            dut.load_species.value = 1
            await RisingEdge(dut.clk)
        
        dut.load_species.value = 0
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (timeout after 500 cycles)
        timeout = 500
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done signal")
        
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            dut._log.info(f"PASSED: Result={actual}")
            passed += 1
        else:
            raise TestFailure(f"FAILED: Expected {expected}, got {actual}")
    
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    if passed == total:
        raise TestSuccess("All tests passed!")
