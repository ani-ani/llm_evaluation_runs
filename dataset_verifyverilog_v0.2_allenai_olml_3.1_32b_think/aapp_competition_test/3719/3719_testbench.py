import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def to_fixed_point(val):
    # Convert float to 8-bit Q4.4 representation
    return int(val * 16) & 0xFF

def from_fixed_point(val):
    return val / 16.0

@cocotb.test()
async def test_laser_maximizer(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_left.value = 0
    dut.n_right.value = 0
    for i in range(16):
        dut.y_left[i].value = 0
        dut.y_right[i].value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Simple symmetric case (Example 2 from prompt scaled down)
    # Original: L=[1,2,3,4,5], R=[1,2,3,4,5] -> 10 destroyed
    # Scaled: L=[16,32,48,64,80], R=[16,32,48,64,80]
    # Sums: 32, 48, 64, 80, 96, 112, 128, 144, 160
    # Sum=64 covers pairs: (3,3), (2,4), (4,2), (1,5), (5,1) -> 5 pairs
    # Sum=96 covers pairs: (5,5), (4,6) -> 5 pairs
    # Union of sums 64 and 96 should cover all 10 pairs.
    
    dut.n_left.value = 5
    dut.n_right.value = 5
    for i in range(5):
        dut.y_left[i].value = (i+1) * 16
        dut.y_right[i].value = (i+1) * 16
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (estimating cycles based on loops)
    # 16x16 pairs = 256 cycles. 16x16 sums check = 256 cycles. Total ~600 cycles.
    for _ in range(700):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.result.value == 10, f"Expected 10, got {dut.result.value}"
    print(f"Test 1 Passed: Result {dut.result.value}")

    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 2: Overlapping rays (Example 1 scaled)
    # Original: L=[1,2,3], R=[1,2,3,7,8,9,11,12,13] -> 9 destroyed
    # We need two sums. L sums: 1+1=2, ..., 3+13=16.
    # Let's use a simpler case: 
    # L = [2, 4] (scaled to 32, 64)
    # R = [2, 6, 8] (scaled to 32, 96, 128)
    # Pairs: (0,0):32, (0,1):96, (0,2):128, (1,0):64, (1,1):160, (1,2):192
    # Let's try to destroy 4 enemies.
    # If we pick sum=32, we kill pair (0,0).
    # If we pick sum=160, we kill pair (1,1).
    # Total 2.
    # We want to maximize.
    # Let's use: L=[1,2] (16,32), R=[1,3] (16,48).
    # Pairs: (0,0):32, (0,1):64, (1,0):48, (1,1):80.
    # All sums distinct. Max 1 per sum. Max 2 total.
    # Let's try to get 4.
    # L=[1,2,3] (16,32,48), R=[2] (32).
    # Pairs: 48, 64, 80. Sums distinct. Max 1 per sum.
    # Let's manually construct a case for 4:
    # L=[1, 2] (16, 32). R=[1, 2] (16, 32).
    # Pairs: 32, 48, 48, 64. Sum 48 covers (0,1) and (1,0). Total 2.
    # To get 4, we need sum 48 to cover all 4 pairs? Impossible with distinct values.
    # We need duplicates.
    # L=[1,1] (16,16). R=[1,1] (16,16).
    # Sums: 32. Covers all 4 pairs. Total 4.
    
    dut.n_left.value = 2
    dut.n_right.value = 2
    dut.y_left[0].value = 16
    dut.y_left[1].value = 16
    dut.y_right[0].value = 16
    dut.y_right[1].value = 16
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(700):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.done.value == 1
    assert dut.result.value == 4, f"Expected 4, got {dut.result.value}"
    print(f"Test 2 Passed: Result {dut.result.value}")

    # Test Case 3: Mixed
    # L=[1] (16), R=[1, 2] (16, 32)
    # Pairs: 32, 48. Distinct sums.
    # Max 1 per sum. Total 2.
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.n_left.value = 1
    dut.n_right.value = 2
    dut.y_left[0].value = 16
    dut.y_right[0].value = 16
    dut.y_right[1].value = 32
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(700):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.done.value == 1
    assert dut.result.value == 2, f"Expected 2, got {dut.result.value}"
    print(f"Test 3 Passed: Result {dut.result.value}")

    print(f"3/3 tests passed")
