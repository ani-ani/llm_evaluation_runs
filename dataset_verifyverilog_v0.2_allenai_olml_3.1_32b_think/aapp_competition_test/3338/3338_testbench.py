import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_arcaea_diversity(dut):
    """Test Arcaea diversity calculation with small inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test Case 1: Sample from problem
    # Partners: (78,61)->(88,71), (80,80)->(90,90), (70,90)->(80,100), (90,70)->none, (80,67)->none, (90,63)->none
    # Scaled down: divide by 8 for 8-bit values
    dut.n.value = 6
    dut.k.value = 1
    
    # Partner 0: (9,7)->(11,8) [78/8=9, 61/8=7, 88/8=11, 71/8=8]
    dut.frag[0].value = 9
    dut.step[0].value = 7
    dut.frag_awaken[0].value = 11
    dut.step_awaken[0].value = 8
    
    # Partner 1: (10,10)->(11,11) [80/8=10, 80/8=10, 90/8=11, 90/8=11]
    dut.frag[1].value = 10
    dut.step[1].value = 10
    dut.frag_awaken[1].value = 11
    dut.step_awaken[1].value = 11
    
    # Partner 2: (8,11)->(10,12) [70/8=8, 90/8=11, 80/8=10, 100/8=12]
    dut.frag[2].value = 8
    dut.step[2].value = 11
    dut.frag_awaken[2].value = 10
    dut.step_awaken[2].value = 12
    
    # Partner 3: (11,8)->none [90/8=11, 70/8=8]
    dut.frag[3].value = 11
    dut.step[3].value = 8
    dut.frag_awaken[3].value = 0
    dut.step_awaken[3].value = 0
    
    # Partner 4: (10,8)->none [80/8=10, 67/8=8]
    dut.frag[4].value = 10
    dut.step[4].value = 8
    dut.frag_awaken[4].value = 0
    dut.step_awaken[4].value = 0
    
    # Partner 5: (11,7)->none [90/8=11, 63/8=7]
    dut.frag[5].value = 11
    dut.step[5].value = 7
    dut.frag_awaken[5].value = 0
    dut.step_awaken[5].value = 0
    
    # Others unused
    for i in range(6, 8):
        dut.frag[i].value = 0
        dut.step[i].value = 0
        dut.frag_awaken[i].value = 0
        dut.step_awaken[i].value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (allow many cycles for worst case)
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Computation did not complete in time"
    
    # Expected: diversity of 5 (all partners can be in antichain with optimal awakening)
    print(f"Test 1 Result: {dut.result.value}")
    assert dut.result.value == 5, f"Expected 5, got {dut.result.value}"
    
    # Reset for test 2
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test Case 2: All awaken, k=5
    # 5 partners, all can awaken, k=5
    dut.n.value = 5
    dut.k.value = 5
    
    # Partner 0: (6,8)->(10,10) [50/8=6, 70/8=8, 80/8=10, 80/8=10]
    dut.frag[0].value = 6
    dut.step[0].value = 8
    dut.frag_awaken[0].value = 10
    dut.step_awaken[0].value = 10
    
    # Partner 1: (7,7)->(11,11) [60/8=7, 60/8=7, 90/8=11, 90/8=11]
    dut.frag[1].value = 7
    dut.step[1].value = 7
    dut.frag_awaken[1].value = 11
    dut.step_awaken[1].value = 11
    
    # Partner 2: (8,6)->(12,12) [70/8=8, 50/8=6, 100/8=12, 100/8=12]
    dut.frag[2].value = 8
    dut.step[2].value = 6
    dut.frag_awaken[2].value = 12
    dut.step_awaken[2].value = 12
    
    # Partner 3: (6,6)->(8,8) [50/8=6, 50/8=6, 70/8=8, 70/8=8]
    dut.frag[3].value = 6
    dut.step[3].value = 6
    dut.frag_awaken[3].value = 8
    dut.step_awaken[3].value = 8
    
    # Partner 4: (6,6)->(8,8) [same as partner 3]
    dut.frag[4].value = 6
    dut.step[4].value = 6
    dut.frag_awaken[4].value = 8
    dut.step_awaken[4].value = 8
    
    for i in range(5, 8):
        dut.frag[i].value = 0
        dut.step[i].value = 0
        dut.frag_awaken[i].value = 0
        dut.step_awaken[i].value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1
    
    # Expected: 4 (with optimal awakening, 4 can be non-dominating)
    print(f"Test 2 Result: {dut.result.value}")
    assert dut.result.value == 4, f"Expected 4, got {dut.result.value}"
    
    print(f"
All tests passed!")
    print(f"Summary: 2/2 tests passed")