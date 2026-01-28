import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Modulo constant
MOD = 1000000007

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference solution for validation
def solve_reference(s_digits):
    if not s_digits:
        return 0
    
    # count_mod3[r] = number of valid subsets with sum % 3 == r
    # Valid subsets: non-empty, sum % 3 == 0
    # Special case: subset containing only '0' is valid (sum 0)
    
    count_mod3 = [0, 0, 0]
    
    for d in s_digits:
        d_mod = d % 3
        new_counts = list(count_mod3)
        
        # Case 1: The digit itself is '0'
        # Subset {0} is valid (forms number 0)
        if d == 0:
            new_counts[0] = (new_counts[0] + 1) % MOD
            
        # Case 2: Append d to existing subsets
        for r in range(3):
            new_rem = (r + d_mod) % 3
            new_counts[new_rem] = (new_counts[new_rem] + count_mod3[r]) % MOD
            
        count_mod3 = new_counts
        
    return count_mod3[0]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_byteconn333ct(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (digits_string, expected_result)
    # 1. "361": valid subsets? {3}, {6}, {3,6} -> 3
    # 2. "11": sum 2, not divisible. Subsets: {1}(1), {1}(1), {1,1}(2). None divisible by 3. -> 0
    # 3. "3051": 
    #    Digits: 3, 0, 5, 1
    #    Valid: {3}, {0}, {3,0}, {5,1}, {3,5,1}, {0,5,1} -> 6
    
    test_cases = [
        ("361", 3),
        ("11", 0),
        ("3051", 6)
    ]
    
    for i, (s_input, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: Input='{s_input}'")
        
        # Prepare input digits
        digits = [int(c) for c in s_input]
        n = len(digits)
        
        # Load data into dut (serial or parallel)
        # Assuming data_in is 8-bit, sends one char per cycle (or packed)
        # Let's assume the dut has a 16x4 array for digits or a stream interface.
        # Given the prompt spec, we use a stream interface `data_in` (8-bit) and `len`.
        # Since it's a stream, we drive data_in sequentially.
        
        if has_signal(dut, 'data_in'):
            # Stream input mode
            dut.start.value = 1
            dut.len.value = n
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Feed digits
            for d in digits:
                dut.data_in.value = ord(str(d))
                await RisingEdge(dut.clk)
                # Check if ready signal exists
                if has_signal(dut, 'ready'):
                    while not int(dut.ready.value):
                        await RisingEdge(dut.clk)
            
            # Pad with 0x00 if stream expects fixed width or just stop
            dut.data_in.value = 0
        else:
            # Parallel array interface: arr[0:15]
            dut.start.value = 1
            dut.len.value = n
            
            for idx in range(16):
                if idx < n:
                    # Handle potential bus width (e.g. arr[0] is 4-bit)
                    val = digits[idx]
                    try:
                        getattr(dut, f'arr_{idx}').value = val
                    except AttributeError:
                        # Try indexed array access
                        if has_signal(dut, 'arr'):
                            dut.arr[idx].value = val
                        else:
                            raise
                else:
                    try:
                        getattr(dut, f'arr_{idx}').value = 0
                    except AttributeError:
                        if has_signal(dut, 'arr'):
                            dut.arr[idx].value = 0
            
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal undefined")
            
        result = int(dut.result.value)
        
        # Verify against reference
        ref = solve_reference(digits)
        
        if result != expected:
             raise TestFailure(f"Mismatch: Expected {expected}, Got {result} (Ref: {ref})")
             
        cocotb.log.info(f"Test {i+1} Passed: {result}")
        
        # Reset between tests
        await reset_dut(dut)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Edge case: Single '0'
    # Result should be 1 ({0} is valid)
    digits = [0]
    n = 1
    
    dut.start.value = 1
    dut.len.value = n
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    if has_signal(dut, 'data_in'):
        dut.data_in.value = ord('0')
        await RisingEdge(dut.clk)
    else:
        getattr(dut, 'arr_0').value = 0
        
    await wait_for_done(dut)
    result = int(dut.result.value)
    
    if result != 1:
        raise TestFailure(f"Edge case '0' failed: Expected 1, Got {result}")
        
    cocotb.log.info("Edge case '0' Passed")
