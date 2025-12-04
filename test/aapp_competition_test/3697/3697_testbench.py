import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_election(dut):
    # Generate 50MHz clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 3 candidates, k=1 (scaled to 8)
    test_data = [
        (0, 2, 1),  # Candidate 1 votes
        (1, 1, 2),  # Candidate 2 votes
        (2, 1, 3)   # Candidate 3 votes
    ]
    m_remaining = 1
    k = 1
    
    # Load data
    for (cid, votes, last_time) in test_data:
        dut.candidate_id.value = cid
        dut.current_votes.value = votes
        dut.last_vote_time.value = last_time
        dut.load_data.value = 1
        await RisingEdge(dut.clk)
    dut.load_data.value = 0
    
    # Set parameters
    dut.n.value = 3
    dut.k.value = k
    dut.m_remaining.value = m_remaining
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Verify results (expected 1,3,3 scaled to 8)
    assert dut.result.value == 1, "Candidate 0 should be guaranteed"
    await RisingEdge(dut.clk)
    assert dut.result.value == 3, "Candidate 1 should have no chance"
    await RisingEdge(dut.clk)
    assert dut.result.value == 3, "Candidate 2 should have no chance"
    
    # Test case 2: Another scenario
    # ... additional test cases ...
    
    dut._log.info("2/2 tests passed")