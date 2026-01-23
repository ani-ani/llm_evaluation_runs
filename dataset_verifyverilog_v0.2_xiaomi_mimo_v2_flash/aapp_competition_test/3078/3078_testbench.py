import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_longest_interesting_subsequence(dut):
    """Test longest interesting subsequence with multiple cases"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # Case 1: All 1s, S=10000 -> many valid subsequences
        {
            'A': [1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            'S': 10000,
            'N': 5,
            'expected': [4, 4, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        },
        # Case 2: Mixed values, S=9
        {
            'A': [1, 1, 10, 1, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            'S': 9,
            'N': 5,
            'expected': [2, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        },
        # Case 3: All 1s, S=3
        {
            'A': [1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0],
            'S': 3,
            'N': 8,
            'expected': [6, 6, 6, 4, 4, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        },
        # Case 4: Single element (edge case)
        {
            'A': [5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            'S': 10,
            'N': 1,
            'expected': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        },
        # Case 5: All 0s (trivial)
        {
            'A': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            'S': 5,
            'N': 8,
            'expected': [8, 8, 8, 8, 8, 8, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        },
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, tc in enumerate(test_cases):
        dut._log.info(f"Running test case {idx+1}: N={tc['N']}, S={tc['S']}")
        
        # Load array and S
        for i in range(16):
            dut.A[i].value = tc['A'][i]
        dut.S.value = tc['S']
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        timeout = 300  # cycles
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        else:
            raise TestFailure(f"Test case {idx+1}: Timeout waiting for done")
        
        # Verify results
        for i in range(tc['N']):
            actual = int(dut.result[i].value)
            expected = tc['expected'][i]
            if actual != expected:
                raise TestFailure(
                    f"Test case {idx+1}, position {i}: expected {expected}, got {actual}"
                )
        
        # Check remaining positions are 0
        for i in range(tc['N'], 16):
            actual = int(dut.result[i].value)
            if actual != 0:
                raise TestFailure(
                    f"Test case {idx+1}, position {i}: expected 0, got {actual}"
                )
        
        passed += 1
        dut._log.info(f"Test case {idx+1} passed")
    
    dut._log.info(f"
Summary: {passed}/{total} tests passed")