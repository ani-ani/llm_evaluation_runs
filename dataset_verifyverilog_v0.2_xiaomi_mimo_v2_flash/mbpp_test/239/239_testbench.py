import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def get_total_number_of_sequences(m, n):
    T = [[0 for i in range(n+1)] for i in range(m+1)]
    for i in range(m+1):
        for j in range(n+1):
            if i == 0 or j == 0:
                T[i][j] = 0
            elif i < j:
                T[i][j] = 0
            elif j == 1:
                T[i][j] = i
            else:
                T[i][j] = T[i-1][j] + T[i//2][j-1]
    return T[m][n]

@cocotb.test()
async def test_sequence_counter(dut):
    """Test sequence counter with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.m.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (10, 4, 4),
        (5, 2, 6),
        (16, 3, 84)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for m_val, n_val, expected in test_cases:
        dut._log.info(f"Testing m={m_val}, n={n_val}, expected={expected}")
        
        # Load inputs
        dut.m.value = m_val
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 150 cycles to be safe)
        timeout = 150
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            dut._log.error(f"Timeout for m={m_val}, n={n_val}")
            continue
        
        # Read result
        result = int(dut.result.value)
        dut._log.info(f"Result: {result}, Expected: {expected}")
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: m={m_val}, n={n_val}")
        else:
            raise TestFailure(f"FAIL: m={m_val}, n={n_val} got {result} expected {expected}")
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

@cocotb.test()
async def test_sequence_counter_edge_cases(dut):
    """Test edge cases for sequence counter"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge cases: minimum values
    edge_cases = [
        (1, 1, 1),  # Smallest valid: 1 sequence [1]
        (2, 1, 2),  # [1], [2]
        (3, 1, 3),  # [1], [2], [3]
        (2, 2, 1),  # Only [1,2] valid
    ]
    
    passed = 0
    total = len(edge_cases)
    
    for m_val, n_val, expected in edge_cases:
        dut._log.info(f"Edge case: m={m_val}, n={n_val}, expected={expected}")
        
        dut.m.value = m_val
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 150
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            dut._log.error(f"Timeout for edge case m={m_val}, n={n_val}")
            continue
        
        result = int(dut.result.value)
        
        if result == expected:
            passed += 1
            dut._log.info(f"PASS")
        else:
            raise TestFailure(f"FAIL: got {result} expected {expected}")
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
Edge test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} edge tests passed"
