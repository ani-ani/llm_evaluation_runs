import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

@cocotb.test()
async def test_max_points_game(dut):
    """Test the max_points_game module with various sequences"""
    
    # Create a clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_valid.value = 0
    dut.sequence_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: [1, 2] -> 2
    # Expected: 1*1 + 1*2 = 3? No, rule is max score.
    # DP: dp[1] = 1, dp[2] = max(dp[1], 2 + dp[0]) = max(1, 2) = 2.
    # Sequence: [1, 2]
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load sequence
    sequence = [1, 2]
    dut._log.info(f"Loading sequence: {sequence}")
    
    for i in range(16):
        dut.load_valid.value = 1
        if i < len(sequence):
            dut.sequence_in.value = sequence[i]
        else:
            dut.sequence_in.value = 0 # Pad with 0s
        await RisingEdge(dut.clk)
    
    dut.load_valid.value = 0
    
    # Wait for processing (256 cycles + small buffer)
    for _ in range(260):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.max_score.value == 2, f"Expected 2, got {dut.max_score.value}"
    
    # Test Case 2: [1, 2, 3] -> 4
    # dp[1]=1, dp[2]=max(1,2)=2, dp[3]=max(2, 3+1)=4
    # Sequence: [1, 2, 3]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    sequence = [1, 2, 3]
    dut._log.info(f"Loading sequence: {sequence}")
    
    for i in range(16):
        dut.load_valid.value = 1
        if i < len(sequence):
            dut.sequence_in.value = sequence[i]
        else:
            dut.sequence_in.value = 0
        await RisingEdge(dut.clk)
    
    dut.load_valid.value = 0
    
    for _ in range(260):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.done.value == 1
    assert dut.max_score.value == 4, f"Expected 4, got {dut.max_score.value}"
    
    # Test Case 3: [1, 2, 1, 3, 2, 2, 2, 2, 3] -> 10
    # Counts: 1->2, 2->5, 3->2
    # dp[1]=2, dp[2]=max(2, 2+10)=12? No wait.
    # Let's re-verify logic: count[i]*i = points.
    # dp[1]=2. dp[2]=max(2, 2+10)=12? 
    # Wait, dp[0]=0. dp[1]=1*2=2. dp[2]=max(2, 2*5 + 0)=max(2,10)=10.
    # dp[3]=max(10, 3*2 + 2)=max(10, 8)=10.
    # Result should be 10.
    # Sequence: [1, 1, 2, 2, 2, 2, 2, 3, 3]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    sequence = [1, 1, 2, 2, 2, 2, 2, 3, 3]
    dut._log.info(f"Loading sequence: {sequence}")
    
    for i in range(16):
        dut.load_valid.value = 1
        if i < len(sequence):
            dut.sequence_in.value = sequence[i]
        else:
            dut.sequence_in.value = 0
        await RisingEdge(dut.clk)
    
    dut.load_valid.value = 0
    
    for _ in range(260):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.done.value == 1
    # Note: The original problem example output is 10. My calculation gave 10. 
    # Let's double check the python logic provided in prompt: dp[i] = max(dp[i-1], dp[i-2] + a[i]*i)
    # 1: dp[1] = a[1]*1 = 2
    # 2: dp[2] = max(dp[1], dp[0] + 5*2) = max(2, 10) = 10
    # 3: dp[3] = max(dp[2], dp[1] + 2*3) = max(10, 2+6) = 10
    # Wait, the prompt example output is 10. My logic matches.
    # However, looking at the user provided python code in prompt:
    # One snippet says: `dp[i] = max(dp[i-1], dp[i-2] + a[i]*i)`
    # Another says: `dp[i] = max(dp[i-1], dp[i-2] + i * a[i])`
    # They are the same.
    # Let's look at the provided Python snippet `Codeforces Contest 260 Div 1 Problem A`:
    # `dp[i] = max(a[i] * i + dp[i-2], dp[i-1])`
    # Yes, that is exactly what I implemented.
    assert dut.max_score.value == 10, f"Expected 10, got {dut.max_score.value}"
    
    # Test Case 4: Edge case - single large number 100000 (capped at 255 in hardware)
    # Since hardware is capped at 255, we test with 255.
    # Sequence: [255, 255, 255]
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    sequence = [255, 255, 255]
    dut._log.info(f"Loading sequence: {sequence}")
    
    for i in range(16):
        dut.load_valid.value = 1
        if i < len(sequence):
            dut.sequence_in.value = sequence[i]
        else:
            dut.sequence_in.value = 0
        await RisingEdge(dut.clk)
    
    dut.load_valid.value = 0
    
    for _ in range(260):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.done.value == 1
    # Count of 255 is 3. Points = 3 * 255 = 765
    # dp[254] = 0. dp[255] = max(dp[254], 3*255 + dp[253]) = 765
    assert dut.max_score.value == 765, f"Expected 765, got {dut.max_score.value}"
    
    dut._log.info("All tests passed!")
