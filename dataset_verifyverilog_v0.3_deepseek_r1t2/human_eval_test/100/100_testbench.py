import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def compute_expected(n):
    """Compute the expected stone pile sequence."""
    if n == 0:
        return []
    result = []
    current = n
    for i in range(n):
        result.append(current)
        current += 2
    return result

@cocotb.test(timeout_time=2, timeout_unit='ms')
async def test_make_a_pile_basic(dut):
    """Test basic functionality of make_a_pile module."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected_sequence)
    test_cases = [
        (3, [3, 5, 7]),
        (4, [4, 6, 8, 10]),
        (5, [5, 7, 9, 11, 13]),
        (6, [6, 8, 10, 12, 14, 16]),
        (8, [8, 10, 12, 14, 16, 18, 20, 22]),
        (1, [1]),
        (2, [2, 4]),
    ]
    
    for n, expected in test_cases:
        dut._log.info(f"Testing n={n}, expected={expected}")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect results
        collected = []
        done_seen = False
        timeout_count = 0
        max_cycles = n + 5  # Allow some extra cycles
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            await Timer(1, units='ns')  # Small settle time
            
            # Check if output is defined
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Undefined result at cycle {cycle}")
            
            if not is_value_defined(dut.done.value):
                raise TestFailure(f"Undefined done at cycle {cycle}")
            
            # Read result
            result_val = int(dut.result.value)
            index_val = int(dut.index.value)
            done_val = int(dut.done.value)
            
            # Store result during computation
            if not done_val and index_val < n:
                collected.append(result_val)
            
            # Check done signal
            if done_val == 1:
                done_seen = True
                dut._log.info(f"Done at cycle {cycle}, index={index_val}, result={result_val}")
                # Append final result if not already added
                if len(collected) < n:
                    collected.append(result_val)
                break
        
        if not done_seen:
            raise TestFailure(f"Done signal not seen for n={n} within {max_cycles} cycles")
        
        # Verify collected sequence
        if collected != expected:
            raise TestFailure(f"n={n}: expected {expected}, got {collected}")
        
        dut._log.info(f"Test n={n} passed: {collected}")
        
        # Wait a few cycles before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_make_a_pile_edge_cases(dut):
    """Test edge cases including n=0."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test n=0 (edge case)
    dut._log.info("Testing n=0")
    dut.start.value = 1
    dut.n.value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Should complete quickly
    await RisingEdge(dut.clk)
    if not is_value_defined(dut.done.value):
        raise TestFailure("Done undefined for n=0")
    
    if int(dut.done.value) != 1:
        raise TestFailure(f"n=0: expected done=1, got {int(dut.done.value)}")
    
    dut._log.info("Edge case n=0 passed")
    
    # Test n=7 (odd number, sequence length 7)
    dut._log.info("Testing n=7")
    expected_7 = [7, 9, 11, 13, 15, 17, 19]
    
    dut.n.value = 7
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    collected = []
    for cycle in range(15):
        await RisingEdge(dut.clk)
        await Timer(1, units='ns')
        
        if not is_value_defined(dut.done.value):
            continue
        
        if int(dut.done.value) == 1:
            if is_value_defined(dut.result.value):
                collected.append(int(dut.result.value))
            break
        
        if is_value_defined(dut.result.value):
            collected.append(int(dut.result.value))
    
    if collected != expected_7:
        raise TestFailure(f"n=7: expected {expected_7}, got {collected}")
    
    dut._log.info("Test n=7 passed")
    dut._log.info("All edge case tests passed!")

@cocotb.test(timeout_time=2, timeout_unit='ms')
async def test_make_a_pile_concurrent(dut):
    """Test running multiple computations back-to-back."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Run 3 computations in sequence
    for test_num, n in enumerate([3, 5, 4]):
        expected = compute_expected(n)
        dut._log.info(f"Concurrent test {test_num+1}: n={n}, expected={expected}")
        
        # Start
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect
        collected = []
        for cycle in range(n + 5):
            await RisingEdge(dut.clk)
            await Timer(1, units='ns')
            
            if not is_value_defined(dut.result.value) or not is_value_defined(dut.done.value):
                continue
            
            if int(dut.done.value) == 1:
                collected.append(int(dut.result.value))
                break
            
            if int(dut.index.value) < n:
                collected.append(int(dut.result.value))
        
        if collected != expected:
            raise TestFailure(f"Concurrent test {test_num+1}: expected {expected}, got {collected}")
        
        dut._log.info(f"Concurrent test {test_num+1} passed")
    
    dut._log.info("All concurrent tests passed!")
