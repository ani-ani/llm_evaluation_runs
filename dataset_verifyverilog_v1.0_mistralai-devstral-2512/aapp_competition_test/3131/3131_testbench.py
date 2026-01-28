import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 256
MODULO = 1000000007

# Helper functions

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python implementation to calculate expected result

def calculate_expected(arr, K, N):
    """Calculate sum of max values for all combinations of K keys from N keys"""
    if K == 0 or K > N:
        return 0
    
    # Generate all combinations
    from itertools import combinations
    total = 0
    for combo in combinations(range(N), K):
        max_val = max(arr[i] for i in combo)
        total = (total + max_val) % MODULO
    return total

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_piano_maximum(dut):
    """Test piano maximum value calculation"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # (input_array, K, expected_sum, description)
        ([2, 4, 2, 3, 4], 3, 39, "Example 1: N=5, K=3"),
        ([1, 0, 1, 1, 1], 1, 4, "Example 2: N=5, K=1"),
        ([3, 3, 4, 0, 0], 2, 31, "Example 3: N=5, K=2"),
        ([10, 20, 30], 2, 50, "Simple case: N=3, K=2"),
        ([1, 2, 3, 4], 1, 10, "K=1: sum all values"),
        ([5, 5, 5, 5], 2, 20, "All same values"),
        ([0, 0, 0, 0], 2, 0, "All zeros"),
        ([255, 255, 255, 255], 3, 255 * 4, "Max values"),  # 4 combinations of 3 from 4
    ]
    
    passed = 0
    failed = 0
    
    for idx, (input_arr, K, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: {desc}")
        
        # Pad input array to 8 elements with 0
        padded_arr = input_arr + [0] * (8 - len(input_arr))
        N = len(input_arr)
        
        try:
            # Write input values to dut.arr[0:7]
            for i in range(8):
                val = padded_arr[i] if i < len(input_arr) else 0
                if has_signal(dut, f'arr_{i}'):
                    getattr(dut, f'arr_{i}').value = clamp_to_width(val, DATA_WIDTH)
                elif has_signal(dut, 'arr'):
                    # If arr is a bus, we need to handle it differently
                    # For simplicity, we assume arr is an array
                    dut.arr[i].value = clamp_to_width(val, DATA_WIDTH)
                else:
                    raise TestFailure("Cannot find arr signals")
            
            # Set K value
            if has_signal(dut, 'k_select'):
                dut.k_select.value = K
            else:
                raise TestFailure("Cannot find k_select signal")
            
            # Start pulse
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            else:
                await Timer(100, units='ns')
            
            # Wait for done
            if has_signal(dut, 'done'):
                await wait_for_done(dut)
            else:
                await Timer(1000, units='ns')
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal not found")
            
            result_val = int(dut.result.value)
            
            # Verify result
            if result_val != expected:
                raise TestFailure(f"Expected {expected}, got {result_val}")
            
            cocotb.log.info(f"  PASS: result={result_val} (expected={expected})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} tests passed")
    
    cocotb.log.info(f"All {passed} tests passed!")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases"""
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    edge_cases = [
        # K=0 case
        ([1, 2, 3], 0, 0, "K=0 (no keys)"),
        # K > N case
        ([1, 2], 5, 0, "K > N"),
        # Single element
        ([42], 1, 42, "Single element, K=1"),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (input_arr, K, expected, desc) in enumerate(edge_cases):
        cocotb.log.info(f"Edge test {idx+1}: {desc}")
        
        try:
            # Write inputs
            for i in range(8):
                val = input_arr[i] if i < len(input_arr) else 0
                if has_signal(dut, f'arr_{i}'):
                    getattr(dut, f'arr_{i}').value = clamp_to_width(val, DATA_WIDTH)
                else:
                    dut.arr[i].value = clamp_to_width(val, DATA_WIDTH)
            
            if has_signal(dut, 'k_select'):
                dut.k_select.value = K
            
            # Start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Wait
            if has_signal(dut, 'done'):
                await wait_for_done(dut)
            else:
                await Timer(500, units='ns')
            
            # Read
            result_val = int(dut.result.value)
            
            if result_val != expected:
                raise TestFailure(f"Expected {expected}, got {result_val}")
            
            cocotb.log.info(f"  PASS: result={result_val}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} edge tests failed")
    
    cocotb.log.info(f"All {passed} edge tests passed!")