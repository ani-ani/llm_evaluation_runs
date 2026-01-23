import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_train_chaos(dut):
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
    
    # Test Case 1: N=5, P=[3,5,10,2,5], Order=[2,4,5,1,3] -> Expected 90
    # Scaled: P=[3,5,7,2,5], Order=[2,4,5,1,3] (clamped 10->7, indices 1-based)
    passengers1 = [3, 5, 7, 2, 5]
    order1 = [2, 4, 5, 1, 3]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load passengers
    for i in range(8):
        val = passengers1[i] if i < 5 else 0
        dut.p_in.value = val
        dut.idx_in.value = 0  # Placeholder
        await RisingEdge(dut.clk)
    
    # Load order
    for i in range(8):
        val = order1[i] if i < 5 else 0
        dut.p_in.value = 0
        dut.idx_in.value = val
        await RisingEdge(dut.clk)
    
    # Wait for processing (8 cycles for explosions)
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Did not complete")
    
    result = int(dut.max_chaos.value)
    # Expected: 90 (scaled logic: chaos=10 per non-empty segment)
    # Original: 90. Scaled: 90 (kept same scale for chaos output)
    assert result == 90, f"Test 1 failed: got {result}, expected 90"
    
    # Test Case 2: N=4, P=[32,3,3,3], Order=[1,3,2,4] -> Expected 50
    # Scaled: P=[7,3,3,3], Order=[1,3,2,4]
    passengers2 = [7, 3, 3, 3]
    order2 = [1, 3, 2, 4]
    
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load passengers
    for i in range(8):
        val = passengers2[i] if i < 4 else 0
        dut.p_in.value = val
        await RisingEdge(dut.clk)
    
    # Load order
    for i in range(8):
        val = order2[i] if i < 4 else 0
        dut.p_in.value = 0
        dut.idx_in.value = val
        await RisingEdge(dut.clk)
    
    # Wait for processing
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Did not complete")
    
    result = int(dut.max_chaos.value)
    # Expected: 50 (scaled logic)
    assert result == 50, f"Test 2 failed: got {result}, expected 50"
    
    print("All tests passed!")
    print(f"Test 1: 90 vs {int(dut.max_chaos.value)}")
    print(f"Test 2: 50 vs {int(dut.max_chaos.value)}")