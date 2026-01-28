import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    # Helper to handle signed/unsigned clamping
    if v < 0:
        return ((1 << bits) - 1) & v
    return min((1 << bits) - 1, max(0, v))

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.write_en.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done signal after {max_cycles} cycles")

async def write_array(dut, values, width=8):
    # Write values to arr_in
    dut.arr_ready.value = 0
    dut.arr_in.value = 0
    dut.write_en.value = 0
    
    # Wait for arr_ready to be asserted by the module (indicating ready state)
    # In this specific design, we trigger loading by asserting write_en
    for i, val in enumerate(values):
        val = clamp_to_width(val, width)
        dut.arr_in.value = val
        dut.write_en.value = 1
        await RisingEdge(dut.clk)
        dut.write_en.value = 0
        await RisingEdge(dut.clk) 

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_sum_inc_subseq(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test Cases
    # Scaled inputs: 8 elements max, 8-bit signed
    test_cases = [
        # Input array, index, k, expected result
        # Case 1: [1, 101, 2, 3, 100, 4, 5 ] -> subset [1, 2, 3, 100] -> sum 106? 
        # Original problem expects 11 for index=4, k=6. 
        # a[4]=100, a[6]=5. Increasing seq including 5 after index 4? 
        # Wait, python code logic is specific: dp[i][j] where j is the end.
        # a = [1, 101, 2, 3, 100, 4, 5]
        # index=4 (100), k=6 (5). 5 > 100? No. Logic: dp[index][k]
        # Python code: if a[j] > a[i] ... 
        # Let's trace: i=4, j=6. a[6]=5, a[4]=100. 5 > 100 is False.
        # So it picks dp[i-1][j]. 
        # Wait, the Python code provided: `dp[index][k]`.
        # Test 1: 11. The increasing subsequence sum ending at 5 (index 6) is 1+2+3+4+5 = 15.
        # Wait, the prompt says: "maximum sum of increasing subsequence from prefix until ith index and also including a given kth element which is after i"
        # This is ambiguous. However, we must implement the *provided* Python logic.
        # Provided Logic:
        # for i in range(n):
        #    if a[i] > a[0]: dp[0][i] = a[i] + a[0] else dp[0][i] = a[i]
        # for i in range(1, n):
        #    for j in range(n):
        #        if a[j] > a[i] and j > i: dp[i][j] = max(dp[i-1][i] + a[j], dp[i-1][j])
        #        else: dp[i][j] = dp[i-1][j]
        # This computes the max increasing subsequence sum starting at i and ending at j?
        # Or max sum ending at j that includes i?
        # The code actually calculates the max increasing subsequence sum *ending* at j *given* the start index constraint i.
        # BUT, the result is dp[index][k].
        # Let's map inputs to fit 8-bit, 8-element max.
        
        # Case 1 (Scaled): [1, 10, 2, 3, 5, 4, 5, 0], index=4 (val 5), k=6 (val 5)
        # Expected: 
        # a[4]=5, a[6]=5. Increasing (strict >) implies 5 > 5 is False.
        # Wait, python code uses strict >.
        # Let's use the exact values from test case 1 but scale to fit 8-bit: [1, 10, 2, 3, 5, 4, 5]
        # Expected result 11. (1+10 or 2+3+4+5? No, 11 matches 1+10? 1 is before 10. But index=4 is 5, k=6 is 5). 
        # Let's trace the provided Python logic manually for Test Case 1 inputs:
        # a = [1, 101, 2, 3, 100, 4, 5]
        # i=4 (100), k=6 (5). 
        # dp[4][6] calculation depends on previous rows.
        # We will trust the test cases provided in the prompt are correct for the *logic* defined.
        # We will implement the logic exactly as specified.
        
        # To fit 8-bit constraints, we use scaled inputs if needed, or assume inputs are small.
        # Let's map the test cases to 8-bit values.
        # T1: [1, 10, 2, 3, 5, 4, 5] (Scaled 101->10, 100->5). 
        # Wait, 100->5 changes the data structure. 
        # Let's keep original values if they fit 8-bit signed (-128 to 127).
        # Original: [1, 101, 2, 3, 100, 4, 5] -> All fit in 8-bit signed.
        # We just need 8 elements. Pad 0 at end.

        ( [1, 101, 2, 3, 100, 4, 5, 0], 4, 6, 11 ),
        ( [1, 101, 2, 3, 100, 4, 5, 0], 2, 5, 7 ),
        ( [11, 15, 19, 21, 26, 28, 31, 0], 2, 4, 71 )
    ]

    for i, (arr_vals, idx, k_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}")
        
        # 1. Load Array
        # We need to drive the interface to load 8 elements.
        # Based on spec: wait for arr_ready (init high?), then write 8 times.
        # Assuming simple load protocol.
        
        # Wait for initial state
        await Timer(10, units='ns')
        
        # Write array elements
        for j in range(8):
            val = clamp_to_width(arr_vals[j], 8)
            dut.arr_in.value = val
            dut.write_en.value = 1
            await RisingEdge(dut.clk)
            dut.write_en.value = 0
            await RisingEdge(dut.clk)
            
        # 2. Start Computation
        dut.index.value = idx
        dut.k.value = k_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 3. Wait for Done
        await wait_for_done(dut)
        
        # 4. Check Result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result signal undefined")
            
        got = int(dut.result.value)
        # Handle signed result if expected is negative (not in these tests, but good practice)
        if got > 127: # Treat as signed if high bit set? No, result is 16-bit.
             pass # Cocotb int conversion handles negative if width known, here we assume unsigned read
             
        # Note: The provided python code returns 11, 7, 71. All positive.
        if got != expected:
             raise TestFailure(f"Test {i+1}: Expected {expected}, got {got}")
             
        cocotb.log.info(f"Test {i+1} Passed: {got}")
        
        # Small delay between tests
        await Timer(100, units='ns')
