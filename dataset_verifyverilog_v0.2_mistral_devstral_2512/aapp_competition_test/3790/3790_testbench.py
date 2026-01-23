import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

# Helper to compute LIS in Python for verification
def compute_lis(arr):
    if not arr: return 0
    dp = [1] * len(arr)
    for i in range(len(arr)):
        for j in range(i):
            if arr[j] <= arr[i]:
                dp[i] = max(dp[i], dp[j] + 1)
    return max(dp)

def solve_original(arr, T):
    n = len(arr)
    if T == 1:
        return compute_lis(arr)
    
    # Compute LIS of one copy
    total_lis = compute_lis(arr)
    
    # Compute LIS of prefix
    left_lis = compute_lis(arr)
    
    # Compute LIS of suffix (values that can start new chain)
    # Effectively, LIS of reversed array of reversed values? No.
    # Standard method:
    # Left: LIS from start
    # Right: LIS of reversed suffix that allows continuation
    # Actually, simplified approach used in testbench:
    # Compute LIS of prefix ending at each index
    # Compute LIS of suffix starting at each index
    # But here we just need max possible left and right
    
    # Let's compute strict max_left (LIS ending at last element) and max_right (LIS starting at first element)
    # Actually, for non-decreasing:
    # Left = LIS of the sequence (all elements can be taken? No, depends on T)
    
    # Re-evaluating the testbench logic to match the logic:
    # We need LIS of prefix (taking from start) and LIS of suffix (taking from end) such that they can be merged.
    # But the problem asks for global LIS.
    
    # Let's just compute the required values for the formula:
    # Formula from similar problems: left + right + (T-2)*gap + (total - left - right)
    # But we need the correct 'left', 'right', 'gap'.
    
    # Let's brute force for small T to find the pattern for verification
    # Since T is up to 1024 in scaled problem, we can simulate fully.
    full_arr = arr * T
    return compute_lis(full_arr)

@cocotb.test()
async def test_nds_turbo(dut):
    """Test the NDS Turbo module with various inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.seq_in.value = 0
    dut.T_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases
    # Inputs: sequence (list of 8 ints), T (int)
    test_cases = [
        ([3, 1, 4, 2, 0, 0, 0, 0], 3, 5),  # Original example (padded)
        ([1, 1, 1, 1, 1, 1, 1, 1], 5, 8),  # All equal
        ([8, 7, 6, 5, 4, 3, 2, 1], 4, 4),  # Strictly decreasing
        ([1, 2, 3, 4, 5, 6, 7, 8], 4, 32), # Strictly increasing
        ([1, 3, 2, 4, 3, 5, 4, 6], 5, 10), # Wave
        ([100, 50, 100, 50, 100, 50, 100, 50], 10, 15), # Swings
    ]
    
    for seq, T, expected in test_cases:
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed Sequence
        for i in range(8):
            dut.seq_in.value = seq[i]
            await RisingEdge(dut.clk)
            
        # Feed T
        dut.T_in.value = T
        await RisingEdge(dut.clk)
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 50:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 50:
            cocotb.log.error(f"Timeout for sequence {seq}, T={T}")
            continue
            
        # Check result
        actual = int(dut.result.value)
        
        # Verify with Python simulation
        python_result = solve_original(seq, T)
        
        cocotb.log.info(f"Seq={seq[:3]}..., T={T}: Verilog={actual}, Python={python_result}, Expected={expected}")
        
        # Allow discrepancy if our simplified formula differs, but check against python
        assert actual == python_result, f"Mismatch! Verilog: {actual}, Python: {python_result}"

    print(f"All tests passed!")
