import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

def compute_min_moves(permutation):
    """Compute minimum moves for a permutation."""
    n = len(permutation)
    if n <= 1:
        return 0
    
    # Map value to position
    pos = [0] * n
    for i, val in enumerate(permutation):
        pos[val - 1] = i
    
    # Find longest contiguous increasing subsequence in values 1,2,3...
    longest = 1
    current = 1
    for i in range(n - 1):
        if pos[i] < pos[i + 1]:
            current += 1
            if current > longest:
                longest = current
        else:
            current = 1
    
    return n - longest

@cocotb.test()
async def test_train_sorter_basic(dut):
    """Test basic functionality with several test cases."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.p_in.value = 0
    dut.idx_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled to N=16 where needed)
    test_cases = [
        # Format: (permutation, expected_moves)
        ([4, 1, 2, 5, 3], 2),           # Original test 1 (pad to 16)
        ([4, 1, 3, 2], 2),              # Original test 2 (pad to 16)
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], 0),  # Already sorted
        ([16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1], 15), # Reverse sorted
        ([1, 3, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], 1),   # Single swap
        ([2, 1, 4, 3, 6, 5, 8, 7, 10, 9, 12, 11, 14, 13, 16, 15], 8),  # Alternating
        ([5, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], 1),   # One out of place
    ]
    
    passed = 0
    total = len(test_cases)
    
    for perm_idx, (perm, expected) in enumerate(test_cases):
        # Pad permutation to 16 elements if needed
        full_perm = list(perm)
        remaining = [x for x in range(1, 17) if x not in full_perm]
        full_perm.extend(remaining[:16 - len(full_perm)])
        
        dut._log.info(f"Test {perm_idx + 1}: {full_perm[:len(perm)]}... (padded)")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed all 16 values
        for i in range(16):
            dut.p_in.value = full_perm[i]
            dut.idx_in.value = i
            await RisingEdge(dut.clk)
        
        # Wait for done
        timeout = 50
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Test {perm_idx + 1}: Timeout waiting for done")
        
        # Check result
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(
                f"Test {perm_idx + 1} FAILED: Expected {expected}, got {actual}"
            )
        
        passed += 1
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

@cocotb.test()
async def test_train_sorter_edge_cases(dut):
    """Test edge cases."""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case 1: Single element
    dut._log.info("Testing single element (1)")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.p_in.value = 1
    dut.idx_in.value = 0
    await RisingEdge(dut.clk)
    # Fill rest with 2-16
    for i in range(1, 16):
        dut.p_in.value = i + 1
        dut.idx_in.value = i
        await RisingEdge(dut.clk)
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert int(dut.result.value) == 0, "Single element should require 0 moves"
    
    # Edge case 2: Max moves (reverse order)
    dut._log.info("Testing reverse order (16,15,...,1)")
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i in range(16):
        dut.p_in.value = 16 - i
        dut.idx_in.value = i
        await RisingEdge(dut.clk)
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert int(dut.result.value) == 15, "Reverse order should require 15 moves"
    
    dut._log.info("Edge cases passed!")

@cocotb.test()
async def test_train_sorter_sequential(dut):
    """Test that module can handle multiple computations sequentially."""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Run three quick tests in sequence
    test_perms = [
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],  # 0 moves
        [2, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],  # 1 move
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 15],  # 1 move
    ]
    expected = [0, 1, 1]
    
    for i, (perm, exp) in enumerate(zip(test_perms, expected)):
        dut._log.info(f"Sequential test {i+1}")
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for j in range(16):
            dut.p_in.value = perm[j]
            dut.idx_in.value = j
            await RisingEdge(dut.clk)
        
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        actual = int(dut.result.value)
        assert actual == exp, f"Sequential test {i+1}: expected {exp}, got {actual}"
        
        # Small gap between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info("Sequential tests passed!")
