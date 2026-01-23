import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_star_wars_movies(dut):
    """Test the star_wars_movies module with sample queries"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.query_type.value = 0
    dut.query_value.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper task to process one query
    async def process_query(qtype, qvalue):
        dut.start.value = 1
        dut.query_type.value = qtype
        dut.query_value.value = qvalue
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 1000
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Timeout waiting for done for query {qtype} {qvalue}")
        
        return int(dut.result.value)
    
    # Test Case 1: Original Star Wars scenario
    dut._log.info("Test Case 1: 12 queries from sample 1")
    
    # First three: create movies 1, 2, 3 at plot positions 1, 2, 3
    await process_query(1, 1)  # n=1, movies=[1]
    await process_query(1, 2)  # n=2, movies=[1,2]
    await process_query(1, 3)  # n=3, movies=[1,2,3]
    
    # Next three: create movies 4, 5, 6 at plot positions 1, 2, 3
    await process_query(1, 1)  # n=4, movies=[4,1,2,3]
    await process_query(1, 2)  # n=5, movies=[4,5,1,2,3]
    await process_query(1, 3)  # n=6, movies=[4,5,6,1,2,3]
    
    # Query creation indices for plot positions 1-6
    r1 = await process_query(2, 1)  # Should be 4
    r2 = await process_query(2, 2)  # Should be 5
    r3 = await process_query(2, 3)  # Should be 6
    r4 = await process_query(2, 4)  # Should be 1
    r5 = await process_query(2, 5)  # Should be 2
    r6 = await process_query(2, 6)  # Should be 3
    
    assert r1 == 4, f"Expected 4, got {r1}"
    assert r2 == 5, f"Expected 5, got {r2}"
    assert r3 == 6, f"Expected 6, got {r3}"
    assert r4 == 1, f"Expected 1, got {r4}"
    assert r5 == 2, f"Expected 2, got {r5}"
    assert r6 == 3, f"Expected 3, got {r6}"
    
    dut._log.info("Test Case 1: All 6 queries passed!")
    
    # Reset for Test Case 2
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: Simple insertion order
    dut._log.info("Test Case 2: 6 queries from sample 2")
    
    await process_query(1, 1)  # n=1, movies=[1]
    await process_query(1, 2)  # n=2, movies=[1,2]
    await process_query(1, 3)  # n=3, movies=[1,2,3]
    
    r1 = await process_query(2, 1)  # Should be 1
    r2 = await process_query(2, 2)  # Should be 2
    r3 = await process_query(2, 3)  # Should be 3
    
    assert r1 == 1, f"Expected 1, got {r1}"
    assert r2 == 2, f"Expected 2, got {r2}"
    assert r3 == 3, f"Expected 3, got {r3}"
    
    dut._log.info("Test Case 2: All 3 queries passed!")
    
    # Reset for Test Case 3
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: Complex interleaving
    dut._log.info("Test Case 3: 8 queries from sample 3")
    
    await process_query(1, 1)  # n=1, movies=[1]
    await process_query(1, 1)  # n=2, movies=[2,1]
    await process_query(1, 3)  # n=3, movies=[2,1,3]
    await process_query(1, 2)  # n=4, movies=[2,4,1,3]
    
    r1 = await process_query(2, 1)  # Should be 2
    r2 = await process_query(2, 2)  # Should be 4
    r3 = await process_query(2, 3)  # Should be 1
    r4 = await process_query(2, 4)  # Should be 3
    
    assert r1 == 2, f"Expected 2, got {r1}"
    assert r2 == 4, f"Expected 4, got {r2}"
    assert r3 == 1, f"Expected 1, got {r3}"
    assert r4 == 3, f"Expected 3, got {r4}"
    
    dut._log.info("Test Case 3: All 4 queries passed!")
    
    # Summary
    total_tests = 6 + 3 + 4  # 13 queries tested
    dut._log.info(f"
{'='*50}")
    dut._log.info(f"SUMMARY: {total_tests}/{total_tests} tests passed")
    dut._log.info(f"{'='*50}")

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases and boundary conditions"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def process_query(qtype, qvalue):
        dut.start.value = 1
        dut.query_type.value = qtype
        dut.query_value.value = qvalue
        await RisingEdge(dut.clk)
        dut.start.value = 0
        timeout = 1000
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        return int(dut.result.value)
    
    # Edge case: Insert at position 1 repeatedly
    dut._log.info("Edge Case: Multiple inserts at position 1")
    await process_query(1, 1)  # movies=[1]
    await process_query(1, 1)  # movies=[2,1]
    await process_query(1, 1)  # movies=[3,2,1]
    await process_query(1, 1)  # movies=[4,3,2,1]
    
    r1 = await process_query(2, 1)  # Should be 4
    r2 = await process_query(2, 2)  # Should be 3
    r3 = await process_query(2, 3)  # Should be 2
    r4 = await process_query(2, 4)  # Should be 1
    
    assert r1 == 4 and r2 == 3 and r3 == 2 and r4 == 1
    dut._log.info("Edge Case 1: Passed!")
    
    # Reset
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case: Insert at end repeatedly
    dut._log.info("Edge Case: Multiple inserts at end")
    await process_query(1, 1)  # movies=[1]
    await process_query(1, 2)  # movies=[1,2]
    await process_query(1, 3)  # movies=[1,2,3]
    await process_query(1, 4)  # movies=[1,2,3,4]
    
    r1 = await process_query(2, 1)  # Should be 1
    r2 = await process_query(2, 4)  # Should be 4
    
    assert r1 == 1 and r2 == 4
    dut._log.info("Edge Case 2: Passed!")
    
    dut._log.info(f"
{'='*50}")
    dut._log.info(f"EDGE CASES: All tests passed")
    dut._log.info(f"{'='*50}")
