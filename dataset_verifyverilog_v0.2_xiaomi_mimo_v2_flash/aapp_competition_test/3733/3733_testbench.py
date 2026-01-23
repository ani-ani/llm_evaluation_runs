import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_sound_compression(dut):
    """Test the sound compression module with various inputs"""
    
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.valid_in.value = 0
    dut.I_param.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=6, I=1, array=[2,1,2,3,4,3] -> Expected 2
    # Scaled to n=8: Let's use values [2,1,2,3,4,3,0,0] (padding zeros)
    # With I=1, K=2^1=2 distinct values allowed
    # Frequencies: val0:2, val1:1, val2:2, val3:2, val4:1
    # Best window size 2: [val2, val3] sum=4, [val3, val4] sum=3, etc.
    # Max sum=4, Result=8-4=4 (Wait, need to match logic)
    
    # Let's use a clearer test case that matches the 8-element framework
    # Case 1: 8 elements, distinct values 0,1,2,3,4
    # Array: [0,0,1,2,2,3,3,4] (2 zeros, 1 one, 2 twos, 2 threes, 1 four)
    # I=1 -> K=2 distinct values
    # Best window of size 2: [2,3] sum=4 or [0,1] sum=3
    # Result should be 8 - 4 = 4
    
    dut.I_param.value = 1 # K=2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed 8 values: 0,0,1,2,2,3,3,4
    inputs = [0, 0, 1, 2, 2, 3, 3, 4]
    for val in inputs:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Wait for completion
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if int(dut.result.value) != 4:
        raise TestFailure(f"Case 1 Failed: Expected 4, Got {int(dut.result.value)}")
    print(f"Test Case 1 Passed: Result={int(dut.result.value)}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Case 2: I=3 (or higher) -> K=8, all distinct values allowed, result=0
    # Array: [0,1,2,3,4,5,6,7] (all distinct)
    dut.I_param.value = 3 # K=8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    inputs = [0, 1, 2, 3, 4, 5, 6, 7]
    for val in inputs:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if int(dut.result.value) != 0:
        raise TestFailure(f"Case 2 Failed: Expected 0, Got {int(dut.result.value)}")
    print(f"Test Case 2 Passed: Result={int(dut.result.value)}")
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Case 3: I=2 -> K=4
    # Array: [0,0,0,0,7,7,7,7] (values 0 and 7)
    # Frequencies: val0:4, val7:4
    # Best window size 4: Needs to cover val0 or val7
    # If window [0,1,2,3]: sum=4 (only val0)
    # If window [4,5,6,7]: sum=4 (only val7)
    # If window [0,1,2,3,4,5,6,7]: size 8, sum=8
    # Wait, K=4. Window of size 4.
    # Let's try array: [0,0,1,1,2,2,3,3] (2 of each)
    # Best window size 4: [0,1,2,3] sum=8. Result=0.
    # Let's try array: [0,0,1,1,2,2,3,7] (2 of 0,1,2,3, 1 of 7)
    # K=4. Best window: [0,1,2,3] sum=8. Result=0.
    # Let's try: [0,0,1,1,2,2,7,7] (2 of 0,1,2,7)
    # K=4. Window [0,1,2,3] sum=6. Window [4,5,6,7] sum=4 (only 7). Max=6. Result=2.
    
    dut.I_param.value = 2 # K=4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    inputs = [0, 0, 1, 1, 2, 2, 7, 7]
    for val in inputs:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if int(dut.result.value) != 2:
        raise TestFailure(f"Case 3 Failed: Expected 2, Got {int(dut.result.value)}")
    print(f"Test Case 3 Passed: Result={int(dut.result.value)}")
    
    # Case 4: Single value repeated 8 times
    # I=1 -> K=2
    # Array: [5,5,5,5,5,5,5,5]
    # Frequencies: val5:8
    # Best window size 2: Any window containing 5 has sum=8.
    # Result=0.
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.I_param.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    inputs = [5, 5, 5, 5, 5, 5, 5, 5]
    for val in inputs:
        dut.data_in.value = val
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if int(dut.result.value) != 0:
        raise TestFailure(f"Case 4 Failed: Expected 0, Got {int(dut.result.value)}")
    print(f"Test Case 4 Passed: Result={int(dut.result.value)}")
    
    print("All tests passed!")
