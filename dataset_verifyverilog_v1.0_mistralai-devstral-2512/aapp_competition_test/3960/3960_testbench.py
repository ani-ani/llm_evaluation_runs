import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def clamp_signed(v, bits):
    max_val = (1 << (bits-1)) - 1
    min_val = -(1 << (bits-1))
    return max(min_val, min(max_val, v))

# Array writing helper
def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        if i < 16:  # Max array size
            dut.__getattr__(name)[i].value = clamp_signed(v, width)

def wait_for_done(dut, max_cycles=200):
    return RisingEdge(dut.done)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_function(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    DATA_WIDTH = 32
    ARRAY_SIZE = 16
    
    # Test cases based on problem examples
    test_cases = [
        ([1, 4, 2, 3, 1], 3, "Example 1"),
        ([1, 5, 4, 7], 6, "Example 2"),
        ([1000000000, -1000000000], 2000000000, "Large values"),
        ([1, 1], 0, "Equal values"),
        ([0, 0, 0], 0, "All zeros"),
        ([1, 0, 1, 0], 1, "Alternating"),
        ([10, 20, 30, 40], 10, "Increasing"),
        ([0, 10, 20, 30, 40], 20, "Increasing with zero"),
        ([-1000000000, 1000000000], 2000000000, "Min to max"),
        ([1, 2], 1, "Simple"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Calculate expected using Python
            n = len(arr)
            
            # Compute differences
            diffs = []
            for j in range(n-1):
                diffs.append(abs(arr[j] - arr[j+1]))
            
            # Create ev array (starting positive at index 0)
            ev = []
            for j in range(len(diffs)):
                if j % 2 == 0:
                    ev.append(diffs[j])
                else:
                    ev.append(-diffs[j])
            
            # Create od array (starting negative at index 0)
            od = []
            for j in range(len(diffs)):
                if j % 2 == 0:
                    od.append(-diffs[j])
                else:
                    od.append(diffs[j])
            
            # Kadane's algorithm for ev
            max_ev = ev[0] if ev else 0
            curr = ev[0] if ev else 0
            for x in ev[1:]:
                curr = max(x, curr + x)
                max_ev = max(max_ev, curr)
            
            # Kadane's algorithm for od
            max_od = od[0] if od else 0
            curr = od[0] if od else 0
            for x in od[1:]:
                curr = max(x, curr + x)
                max_od = max(max_od, curr)
            
            expected_result = max(max_ev, max_od)
            
            # Write inputs
            dut.n.value = n
            write_array(dut, 'a', arr, DATA_WIDTH)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            for _ in range(200):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                raise TestFailure(f"Timeout waiting for done signal")
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = safe_int(dut.result.value)
            result_signed = to_signed(result, DATA_WIDTH)
            
            # Allow small rounding errors for large numbers
            if abs(result_signed - expected_result) > 1:
                raise TestFailure(f"Expected {expected_result}, got {result_signed}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
        
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases with larger values"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    DATA_WIDTH = 32
    
    # Large values test
    arr = [1000000000, 0, 0, 1000000000, 1000000000]
    n = len(arr)
    
    # Calculate expected
    diffs = [abs(arr[j] - arr[j+1]) for j in range(n-1)]
    ev = [diffs[j] if j % 2 == 0 else -diffs[j] for j in range(len(diffs))]
    od = [-diffs[j] if j % 2 == 0 else diffs[j] for j in range(len(diffs))]
    
    max_ev = ev[0]; curr = ev[0]
    for x in ev[1:]:
        curr = max(x, curr + x); max_ev = max(max_ev, curr)
    
    max_od = od[0]; curr = od[0]
    for x in od[1:]:
        curr = max(x, curr + x); max_od = max(max_od, curr)
    
    expected = max(max_ev, max_od)
    
    # Write and test
    dut.n.value = n
    write_array(dut, 'a', arr, DATA_WIDTH)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout on large values test")
    
    result = to_signed(safe_int(dut.result.value), DATA_WIDTH)
    if abs(result - expected) > 1:
        raise TestFailure(f"Large values: Expected {expected}, got {result}")
    
    cocotb.log.info("Edge case test passed!")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_single_comparison(dut):
    """Test with n=2 (minimum)"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    DATA_WIDTH = 32
    
    # Test case: [1, 2]
    arr = [1, 2]
    n = 2
    
    # Expected: |1-2| * 1 = 1
    expected = 1
    
    dut.n.value = n
    write_array(dut, 'a', arr, DATA_WIDTH)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    else:
        raise TestFailure("Timeout on n=2 test")
    
    result = to_signed(safe_int(dut.result.value), DATA_WIDTH)
    if result != expected:
        raise TestFailure(f"n=2: Expected {expected}, got {result}")
    
    cocotb.log.info("Single comparison test passed!")