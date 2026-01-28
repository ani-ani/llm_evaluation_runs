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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done after {max_cycles} cycles")

async def write_array(dut, name, vals, width=8):
    # Access individual array elements (unpacked array)
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_frequency(dut):
    CLK_NS = 10
    MAX_CYCLES = 100
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    else:
        raise TestFailure("Module requires a clock signal 'clk'")
    
    await reset_dut(dut)
    
    # Test cases: (arr, target, expected_count, description)
    test_cases = [
        ([1, 2, 3], 4, 0, "Element not in list"),
        ([1, 2, 2, 3, 3, 3, 4], 3, 3, "Multiple occurrences"),
        ([0, 1, 2, 3, 1, 2], 1, 2, "Two occurrences"),
        ([5, 5, 5, 5], 5, 4, "All elements match"),
        ([1, 2, 3], 1, 1, "First element match"),
        ([], 5, 0, "Empty array (len=0)")
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, target, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Write inputs
            await write_array(dut, 'arr', arr, width=8)
            dut.target.value = clamp_to_width(target, 8)
            dut.len.value = clamp_to_width(len(arr), 4)
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            # Check if done is high for exactly 1 cycle (implicit in wait_for_done)
            # Reset for next test
            await RisingEdge(dut.clk)
            if int(dut.done.value) != 0:
                raise TestFailure("Done signal remained high after cycle")
                
            passed += 1
            cocotb.log.info(f"PASS: Result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed successfully")