import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, vals, width=8):
    """Write array elements individually (not dut.arr.value=list)"""
    for i, v in enumerate(vals):
        if i >= 8: break  # Max 8 elements
        if has_signal(dut, f'arr_{i}'):
            getattr(dut, f'arr_{i}').value = clamp_to_width(v, width)
        else:
            # Fallback for packed array
            dut.arr[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_count_pairs(dut):
    """
    Test counting unequal unordered pairs in array
    """
    CLK_NS = 10
    MAX_CYCLES = 500
    
    # Start clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases matching Python spec
    test_cases = [
        ([1,2,1], 3, 2, "Test 1: [1,2,1] -> 2"),
        ([1,1,1,1], 4, 0, "Test 2: [1,1,1,1] -> 0"),
        ([1,2,3,4,5], 5, 10, "Test 3: [1,2,3,4,5] -> 10"),
        ([0,1,2,3,4,5,6,7], 8, 28, "Test 4: 8 distinct -> 28"),
        ([], 0, 0, "Test 5: Empty array -> 0"),
        ([5], 1, 0, "Test 6: Single element -> 0"),
    ]
    
    passed = failed = 0
    
    for i, (arr_vals, arr_len, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running test {i+1}: {desc}")
        try:
            # Write array elements
            await write_array(dut, arr_vals, width=8)
            
            if is_seq:
                # Set length
                if has_signal(dut, 'len'):
                    dut.len.value = arr_len
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=MAX_CYCLES)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                
                cocotb.log.info(f"  PASS: result={result}")
                passed += 1
            else:
                # Combinational: small delay
                await Timer(100, units='ns')
                
                # For combinational, we might need to set len manually
                if has_signal(dut, 'len'):
                    dut.len.value = arr_len
                    await Timer(10, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                
                cocotb.log.info(f"  PASS: result={result}")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")
