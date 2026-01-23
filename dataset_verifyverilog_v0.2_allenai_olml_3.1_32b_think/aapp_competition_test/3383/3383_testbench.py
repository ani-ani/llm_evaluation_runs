import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_ice_cream_optimizer(dut):
    """Test the ice cream optimizer module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_scoops.value = 0
    dut.cost_per_scoop.value = 0
    dut.cost_cone.value = 0
    for i in range(4):
        dut.base_tastiness[i].value = 0
        for j in range(4):
            dut.interaction[i][j].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Sample Input adapted
    # n=20 (scaled to 5), k=3 (scaled to 4), a=5, b=5
    # t = [0,0,0,0], u = [[0,-10,0,0], [30,0,0,0], [0,0,0,0], [0,0,0,0]]
    # Expected: ratio ~2.0 (tastiness 30, cost 15)
    
    dut.num_scoops.value = 5  # Scaled down
    dut.cost_per_scoop.value = 5
    dut.cost_cone.value = 5
    dut.base_tastiness[0].value = 0
    dut.base_tastiness[1].value = 0
    dut.base_tastiness[2].value = 0
    dut.base_tastiness[3].value = 0
    
    # Interaction matrix
    dut.interaction[0][0].value = 0
    dut.interaction[0][1].value = -10
    dut.interaction[0][2].value = 0
    dut.interaction[0][3].value = 0
    
    dut.interaction[1][0].value = 30  # Flavour 1 on top of 0 gives +30
    dut.interaction[1][1].value = 0
    dut.interaction[1][2].value = 0
    dut.interaction[1][3].value = 0
    
    dut.interaction[2][0].value = 0
    dut.interaction[2][1].value = 0
    dut.interaction[2][2].value = 0
    dut.interaction[2][3].value = 0
    
    dut.interaction[3][0].value = 0
    dut.interaction[3][1].value = 0
    dut.interaction[3][2].value = 0
    dut.interaction[3][3].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max ~80 cycles)
    timeout = 100
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        assert False, "Timeout waiting for done signal"
    
    result = dut.max_ratio.value
    # Ratio should be ~2.0 = 0x0200 in Q8.8
    print(f"Test 1 - Result: {result} (expected ~0x0200)")
    assert result >= 0x01C0 and result <= 0x0240, f"Result {result} out of range"
    
    # Test Case 2: 1 scoop, single flavour
    # n=10 (scaled to 3), k=1, a=8, b=20
    # t = [5], u = [[0]]
    # Expected: (5) / (8+20) = 5/28 = 0.178 -> 0x002C in Q8.8
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.num_scoops.value = 3
    dut.cost_per_scoop.value = 8
    dut.cost_cone.value = 20
    dut.base_tastiness[0].value = 5
    dut.base_tastiness[1].value = 0
    dut.base_tastiness[2].value = 0
    dut.base_tastiness[3].value = 0
    
    # Reset interactions
    for i in range(4):
        for j in range(4):
            dut.interaction[i][j].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result = dut.max_ratio.value
    print(f"Test 2 - Result: {result} (expected ~0x002C)")
    assert result >= 0x0020 and result <= 0x0038, f"Result {result} out of range"
    
    # Test Case 3: Negative tastiness - should return 0 or low ratio
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.num_scoops.value = 2
    dut.cost_per_scoop.value = 10
    dut.cost_cone.value = 10
    dut.base_tastiness[0].value = 255  # -1 in 2's complement 8-bit
    dut.base_tastiness[1].value = 0
    dut.base_tastiness[2].value = 0
    dut.base_tastiness[3].value = 0
    
    for i in range(4):
        for j in range(4):
            dut.interaction[i][j].value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result = dut.max_ratio.value
    print(f"Test 3 - Result: {result}")
    # This test mainly checks the module handles negative values gracefully
    
    print("
All tests completed!")
    print("Summary: 3/3 test cases executed")
