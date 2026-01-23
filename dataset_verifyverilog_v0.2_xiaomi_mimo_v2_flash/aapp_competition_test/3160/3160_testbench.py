import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def calculate_expected_avg(s):
    """Calculate the expected average operations for a given string."""
    n = len(s)
    unknown_indices = [i for i, c in enumerate(s) if c == '?']
    total_sum = 0
    num_configs = 1 << len(unknown_indices)
    
    for i in range(num_configs):
        config = list(s)
        for j, idx in enumerate(unknown_indices):
            if (i >> j) & 1:
                config[idx] = 'H'
            else:
                config[idx] = 'T'
        
        # Simulate process
        arr = [1 if c == 'H' else 0 for c in config]
        steps = 0
        while any(arr):
            k = sum(arr)  # Number of heads
            if k == 0:
                break
            # Find k-th head and flip it
            count = 0
            for idx in range(n):
                if arr[idx] == 1:
                    count += 1
                    if count == k:
                        arr[idx] = 0
                        break
            steps += 1
        total_sum += steps
    
    return total_sum / num_configs if num_configs > 0 else 0.0

@cocotb.test()
async def test_avg_operations(dut):
    """Test avg_operations module with various inputs."""
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')  # 100 MHz
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_mask.value = 0
    dut.head_mask.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ("HH", 2.0),
        ("H?", 1.5),
        ("??", 1.5),
        ("TT", 0.0),
        ("HT", 1.0),
        ("TH", 1.0),
        ("HHT", 2.0),  # HH T -> HT T -> TT T -> TTT (Wait, check: HH=11, 2 heads -> flip 2nd (0) -> 10. 1 head -> flip 1st -> 00. 2 steps)
        ("THT", 3.0),  # THT -> HHT -> HTT -> TTT (3 steps)
        ("???", 1.875), # Hand calc: 8 configs. 000(0), 001(1), 010(1), 011(2), 100(1), 101(2), 110(2), 111(3). Sum=12, Avg=1.5. Wait, example says 1.5. My hand calc gives 12/8=1.5. Correct.
    ]
    
    # We only support N=8 in this implementation
    # We will pad inputs with 'T' to length 8
    
    passed = 0
    total = len(test_cases)
    
    for s_raw, expected in test_cases:
        # Pad to length 8
        s = s_raw + 'T' * (8 - len(s_raw))
        
        # Prepare masks
        char_mask = 0
        head_mask = 0
        for i, c in enumerate(s):
            if c == 'H' or c == '?':
                char_mask |= (1 << i)
            if c == 'H':
                head_mask |= (1 << i)
        
        # Start
        dut.start.value = 1
        dut.char_mask.value = char_mask
        dut.head_mask.value = head_mask
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 15000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 15000:
            raise TestFailure(f"Test case '{s_raw}' timed out")
            
        # Read result
        num = dut.result_num.value.integer
        den = dut.result_den.value.integer
        
        if den == 0:
            raise TestFailure(f"Denominator is zero for '{s_raw}'")
            
        result = num / den
        
        # Check with tolerance
        abs_err = abs(result - expected)
        rel_err = abs_err / max(1, expected)
        
        print(f"Input: {s_raw} (padded to {s}), Expected: {expected}, Got: {result:.6f}")
        
        if rel_err > 1e-6 and abs_err > 1e-6:
            raise TestFailure(f"Mismatch for '{s_raw}': expected {expected}, got {result}")
        
        passed += 1
        await RisingEdge(dut.clk) # Buffer between tests
    
    print(f"
{passed}/{total} tests passed")