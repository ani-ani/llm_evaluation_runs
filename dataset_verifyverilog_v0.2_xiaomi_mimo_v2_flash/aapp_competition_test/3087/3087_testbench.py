import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_dance_arrows_basic(dut):
    """Test basic K-th root permutation"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: N=6, K=2, a=[3,4,5,6,1,2]
    # This is a shift by 2 in 6-cycle: (1 3 5)(2 4 6) -> f maps 1->5, 2->6, 3->1, 4->2, 5->3, 6->4
    dut.N.value = 6
    dut.K.value = 2
    dut.a[0].value = 3
    dut.a[1].value = 4
    dut.a[2].value = 5
    dut.a[3].value = 6
    dut.a[4].value = 1
    dut.a[5].value = 2
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Verify result
    assert not dut.impossible.value, "Should not be impossible"
    assert dut.done.value, "Should be done"
    
    expected = [5, 6, 1, 2, 3, 4]  # 1-indexed, but stored 0-indexed in Verilog
    for i in range(6):
        assert dut.result[i].value == expected[i], f"result[{i}] = {dut.result[i].value}, expected {expected[i]}"
    
    print(f"Test 1: N=6, K=2, a=[3,4,5,6,1,2]")
    print(f"Result: {[int(dut.result[i].value) for i in range(6)]}")
    print(f"Expected: {expected}")

@cocotb.test()
async def test_dance_arrows_simple(dut):
    """Test simple 4-cycle case"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: N=4, K=2, a=[3,4,1,2]
    dut.N.value = 4
    dut.K.value = 2
    dut.a[0].value = 3
    dut.a[1].value = 4
    dut.a[2].value = 1
    dut.a[3].value = 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert not dut.impossible.value
    expected = [2, 3, 4, 1]
    for i in range(4):
        assert dut.result[i].value == expected[i]
    
    print(f"Test 2: N=4, K=2, a=[3,4,1,2]")
    print(f"Result: {[int(dut.result[i].value) for i in range(4)]}")

@cocotb.test()
async def test_dance_arrows_impossible(dut):
    """Test impossible case where a[i] = i"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: N=3, K=2, a=[1,2,3] - impossible
    dut.N.value = 3
    dut.K.value = 2
    dut.a[0].value = 1
    dut.a[1].value = 2
    dut.a[2].value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.impossible.value, "Should be impossible"
    print(f"Test 3: N=3, K=2, a=[1,2,3] - correctly detected as impossible")

@cocotb.test()
async def test_dance_arrows_edge_cases(dut):
    """Test edge case: K=1 (direct mapping)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # K=1: f should equal a
    dut.N.value = 4
    dut.K.value = 1
    dut.a[0].value = 2
    dut.a[1].value = 3
    dut.a[2].value = 4
    dut.a[3].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(150):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert not dut.impossible.value
    expected = [2, 3, 4, 1]
    for i in range(4):
        assert dut.result[i].value == expected[i]
    
    print(f"Test 4: K=1, a=[2,3,4,1]")
    print(f"Result: {[int(dut.result[i].value) for i in range(4)]}")

@cocotb.test()
async def test_summary(dut):
    """Print test summary"""
    print("
=== Test Summary ===")
    print("All tests demonstrate the adapted algorithm for permutation K-th root")
    print("Scaled constraints: N ≤ 16, K ≤ 256")
    print("Implemented: Cycle detection, modular arithmetic, state machine")
    print("4/4 tests expected to pass")