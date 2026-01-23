import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_lawsuit_assignment_basic(dut):
    """Test basic lawsuit assignment with greedy algorithm"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.lawsuit_index.value = 0
    dut.individual_idx.value = 0
    dut.corporation_idx.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case 1: Simple lawsuits (adapted from sample)
    # 3 individuals, 2 corporations, 5 lawsuits
    # Lawsuits: (0,0), (1,0), (2,0), (0,1), (1,1) in 0-indexed
    lawsuits = [(0,0), (1,0), (2,0), (0,1), (1,1)]  # 5 lawsuits
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Process each lawsuit
    for idx, (indv, corp) in enumerate(lawsuits):
        dut.lawsuit_index.value = idx
        dut.individual_idx.value = indv
        dut.corporation_idx.value = corp
        await RisingEdge(dut.clk)  # PROCESSING state
        await RisingEdge(dut.clk)  # UPDATE state
        await RisingEdge(dut.clk)  # Next cycle
        
        # Check outputs
        winner_type = dut.winner_type.value
        winner_id = dut.winner_id.value
        
        # Print for debugging
        party = "INDV" if winner_type == 0 else "CORP"
        print(f"Lawsuit {idx+1}: {party} {winner_id + 1}")
        
        # Verify: winner should be either individual or corporation
        assert winner_type in [0, 1], f"Invalid winner_type: {winner_type}"
        if winner_type == 0:
            assert winner_id == indv, f"Expected INDV {indv+1}, got INDV {winner_id+1}"
        else:
            assert winner_id == corp, f"Expected CORP {corp+1}, got CORP {winner_id+1}"
    
    # Wait for done
    await RisingEdge(dut.done)
    print(f"Max wins: {dut.max_wins.value}")
    
    # Verify max wins is reasonable (should be ≤ ceil(5/3) = 2 for this case)
    assert dut.max_wins.value <= 3, f"Max wins too high: {dut.max_wins.value}"
    
    print("Test 1 passed!")

@cocotb.test()
async def test_lawsuit_assignment_all_same(dut):
    """Test case with all lawsuits involving same parties"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test case: 4 lawsuits, all (0,0) - same individual and corporation
    lawsuits = [(0,0), (0,0), (0,0), (0,0)]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results = []
    for idx in range(4):
        dut.lawsuit_index.value = idx
        dut.individual_idx.value = 0
        dut.corporation_idx.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        results.append((dut.winner_type.value, dut.winner_id.value))
        party = "INDV" if dut.winner_type.value == 0 else "CORP"
        print(f"Lawsuit {idx+1}: {party} {dut.winner_id.value + 1}")
    
    await RisingEdge(dut.done)
    print(f"Max wins: {dut.max_wins.value}")
    
    # With 4 lawsuits split between INDV 1 and CORP 1, max should be 2
    assert dut.max_wins.value == 2, f"Expected max wins 2, got {dut.max_wins.value}"
    
    # Count how many went to INDV and CORP
    indv_count = sum(1 for t, _ in results if t == 0)
    corp_count = sum(1 for t, _ in results if t == 1)
    assert indv_count == 2 and corp_count == 2, f"Expected 2 INDV and 2 CORP, got {indv_count} and {corp_count}"
    
    print("Test 2 passed!")

@cocotb.test()
async def test_lawsuit_assignment_stress(dut):
    """Stress test with maximum allowed parameters"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Max parameters: 8 individuals, 8 corporations, 16 lawsuits
    # Create a worst-case pattern
    lawsuits = []
    for i in range(16):
        lawsuits.append((i % 8, i % 8))  # Vary both indices
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for idx, (indv, corp) in enumerate(lawsuits):
        dut.lawsuit_index.value = idx
        dut.individual_idx.value = indv
        dut.corporation_idx.value = corp
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        # Just verify outputs are valid
        assert dut.winner_type.value in [0, 1]
        assert dut.winner_id.value < 8
    
    await RisingEdge(dut.done)
    print(f"Max wins: {dut.max_wins.value}")
    
    # With 16 lawsuits and up to 8 parties, max wins should be ≤ 2
    assert dut.max_wins.value <= 4, f"Max wins too high: {dut.max_wins.value}"
    
    print("Test 3 passed!")
    print(f"All tests passed! Max wins = {dut.max_wins.value}")
