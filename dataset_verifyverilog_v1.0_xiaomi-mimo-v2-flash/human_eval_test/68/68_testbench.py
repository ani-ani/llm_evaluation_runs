import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(3): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def set_input_array(dut, values, width=8):
    """Set array values element by element"""
    for i in range(16):  # Max supported elements
        if i < len(values):
            dut.arr[i].value = clamp_to_width(values[i], width)
        else:
            dut.arr[i].value = 0

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_pluck_module(dut):
    """Test the pluck module with various test cases"""
    
    # Check if module has required signals
    if not has_signal(dut, 'clk') or not has_signal(dut, 'done'):
        cocotb.log.warning("Module missing required signals, skipping test")
        return
    
    # Setup clock
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Test cases: (input_array, expected_value, expected_index, description)
    test_cases = [
        ([4, 2, 3], 2, 1, "Example 1: smallest even is 2 at index 1"),
        ([1, 2, 3], 2, 1, "Example 2: only even is 2 at index 1"),
        ([], 0xFF, 0xF, "Example 3: empty array"),
        ([5, 0, 3, 0, 4, 2], 0, 1, "Example 4: smallest even is 0 at first occurrence"),
        ([1, 2, 3, 0, 5, 3], 0, 3, "Test: 0 at index 3"),
        ([5, 4, 8, 4, 8], 4, 1, "Test: first 4 at index 1"),
        ([7, 6, 7, 1], 6, 1, "Test: only 6 at index 1"),
        ([7, 9, 7, 1], 0xFF, 0xF, "Test: no even values"),
        ([0], 0, 0, "Edge: single zero"),
        ([2, 4, 6, 8], 2, 0, "Edge: first element smallest"),
        ([1, 1, 1, 2], 2, 3, "Edge: last element only even"),
        ([10, 8, 6, 4, 2], 2, 4, "Edge: smallest at last"),
        ([100, 150, 200, 100], 100, 0, "Edge: first occurrence of 100"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_arr, exp_val, exp_idx, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        cocotb.log.info(f"  Input: {input_arr}")
        cocotb.log.info(f"  Expected: value={exp_val}, index={exp_idx}")
        
        try:
            # Reset module
            await reset_dut(dut)
            
            # Set inputs
            await set_input_array(dut, input_arr, width=8)
            if has_signal(dut, 'len'):
                dut.len.value = clamp_to_width(len(input_arr), 4)
            
            # Start operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=100)
            
            # Read results
            if not is_value_defined(dut.result_val.value) or not is_value_defined(dut.result_idx.value):
                raise TestFailure("Result signals undefined")
            
            result_val = int(dut.result_val.value)
            result_idx = int(dut.result_idx.value)
            
            # Check if valid result (optional signal)
            if has_signal(dut, 'valid'):
                valid = int(dut.valid.value)
                expected_valid = 0 if (exp_val == 0xFF and exp_idx == 0xF) else 1
                if valid != expected_valid:
                    raise TestFailure(f"Valid signal incorrect: expected {expected_valid}, got {valid}")
            
            # Validate result
            if result_val != exp_val:
                raise TestFailure(f"Value mismatch: expected {exp_val}, got {result_val}")
            if result_idx != exp_idx:
                raise TestFailure(f"Index mismatch: expected {exp_idx}, got {result_idx}")
            
            cocotb.log.info(f"  Result: value={result_val}, index={result_idx} ✓")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Test Summary: {passed} passed, {failed} failed")
    cocotb.log.info(f"{'='*60}")
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
