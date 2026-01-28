import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Reference function for LIS length
def get_lis_length(arr):
    if not arr:
        return 0
    dp = [1] * len(arr)
    for i in range(len(arr)):
        for j in range(i):
            if arr[j] <= arr[i]:  # Non-decreasing
                dp[i] = max(dp[i], dp[j] + 1)
    return max(dp)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_lis_module(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.species_in.value = 0
    dut.len_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (species_sequence, expected_lis_length)
    test_cases = [
        ([1, 2, 3, 4], 4),
        ([4, 3, 2, 1], 1),
        ([2, 1, 1], 2), # 1,1 is LIS
        ([1, 3, 2, 4, 5], 4), # 1,2,4,5
        ([5, 4, 3, 2, 1, 6], 2), # 1,6 or 2,6 etc
        ([1], 1),
        ([1, 1, 1, 1], 4)
    ]
    
    for seq, expected in test_cases:
        dut.start.value = 1
        dut.len_in.value = len(seq)
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed sequence
        for val in seq:
            dut.valid_in.value = 1
            dut.species_in.value = val
            await RisingEdge(dut.clk)
        
        dut.valid_in.value = 0
        
        # Wait for done
        timeout = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 2000:
                raise TestFailure(f"Timeout waiting for done on sequence {seq}")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for sequence {seq}")
            
        res = int(dut.result.value)
        if res != expected:
            raise TestFailure(f"Sequence {seq}: Expected LIS {expected}, got {res}")
        
        await RisingEdge(dut.clk) # Clear state for next test

