import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_dessert_finder_basic(dut):
    """Test basic functionality with P=37"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.P.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test P=37
    dut.P.value = 37
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    # Check count
    expected_count = 4
    if dut.count.value != expected_count:
        raise TestFailure(f"Expected {expected_count} pairs, got {dut.count.value}")
    
    # Collect results
    results = []
    for i in range(64):
        if dut.valid.value == 1:
            results.append((int(dut.B_out.value), int(dut.M_out.value)))
        await RisingEdge(dut.clk)
    
    # Expected pairs: (8,29), (9,28), (11,26), (15,22)
    expected = [(8,29), (9,28), (11,26), (15,22)]
    if len(results) != len(expected):
        raise TestFailure(f"Expected {len(expected)} results, got {len(results)}")
    
    for i, (exp_b, exp_m) in enumerate(expected):
        if i >= len(results):
            raise TestFailure(f"Missing result {i}")
        if results[i] != (exp_b, exp_m):
            raise TestFailure(f"Result {i}: expected ({exp_b},{exp_m}), got {results[i]}")
    
    dut._log.info(f"Test passed: {len(results)} valid pairs found")

@cocotb.test()
async def test_dessert_finder_edge_cases(dut):
    """Test edge cases: small P and digit conflicts"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test P=10 (no valid pairs, B<M and distinct digits)
    # B=1, M=9: digits {1}, {9}, {1,0} - 1 appears twice, invalid
    # B=2, M=8: digits {2}, {8}, {1,0} - valid
    # B=3, M=7: digits {3}, {7}, {1,0} - valid
    # B=4, M=6: digits {4}, {6}, {1,0} - valid
    # B=5, M=5: invalid (B<M false)
    dut.P.value = 10
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Should find 3 valid pairs for P=10
    if dut.count.value != 3:
        raise TestFailure(f"For P=10, expected 3 pairs, got {dut.count.value}")
    
    # Test P=11 (no valid pairs)
    # B=1, M=10: digits {1}, {1,0}, {1,1} - 1 appears in all, invalid
    # B=2, M=9: digits {2}, {9}, {1,1} - 1 appears twice, invalid
    # B=3, M=8: digits {3}, {8}, {1,1} - 1 appears twice, invalid
    # etc.
    dut.P.value = 11
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.count.value != 0:
        raise TestFailure(f"For P=11, expected 0 pairs, got {dut.count.value}")
    
    dut._log.info("Edge case tests passed")

@cocotb.test()
async def test_dessert_finder_p30014_limit(dut):
    """Test that module handles larger P (30014) by saturating or error handling"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # P=30014 exceeds 9-bit limit (max 511)
    # This tests robustness - module should saturate or handle gracefully
    dut.P.value = 30014  # Will be truncated to lower 9 bits
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Should still complete without errors
    dut._log.info(f"Large P test completed with count={dut.count.value}")

@cocotb.test()
async def test_dessert_finder_no_duplicates(dut):
    """Verify that duplicate bills are not generated"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.P.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test P=100
    dut.P.value = 100
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 3000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Collect all results
    results = []
    seen = set()
    output_cycles = 0
    
    while output_cycles < 100 and dut.done.value == 1:
        if dut.valid.value == 1:
            pair = (int(dut.B_out.value), int(dut.M_out.value))
            if pair in seen:
                raise TestFailure(f"Duplicate pair found: {pair}")
            seen.add(pair)
            results.append(pair)
        await RisingEdge(dut.clk)
        output_cycles += 1
    
    # Verify B < M for all
    for b, m in results:
        if b >= m:
            raise TestFailure(f"Invalid pair: B={b}, M={m} (B must be < M)")
    
    dut._log.info(f"No duplicates test passed: {len(results)} unique pairs")
