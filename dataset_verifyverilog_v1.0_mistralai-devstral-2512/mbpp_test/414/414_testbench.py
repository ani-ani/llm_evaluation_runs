import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
MAX_LEN = 8
CLK_NS = 10
MAX_CYCLES = 100

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
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def write_array(dut, prefix, values, length):
    """Write values to array ports (arr_0, arr_1, ...)"""
    for i in range(MAX_LEN):
        port_name = f"{prefix}{i}"
        if hasattr(dut, port_name):
            if i < length:
                setattr(dut, port_name, clamp_to_width(values[i], DATA_WIDTH))
            else:
                setattr(dut, port_name, 0)

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal to be 1"""
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(1, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    """Reset the DUT"""
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(1, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_overlapping(dut):
    """Test overlapping function"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        await reset_dut(dut)
    else:
        await Timer(1, units='ns')
    
    test_cases = [
        ("Test 1: No overlap", [1,2,3,4,5], 5, [6,7,8,9], 4, 0),
        ("Test 2: No overlap", [1,2,3], 3, [4,5,6], 3, 0),
        ("Test 3: Full overlap", [1,4,5], 3, [1,4,5], 3, 1),
        ("Test 4: Partial overlap", [1,2,3], 3, [3,4,5], 3, 1),
        ("Test 5: Single element match", [5], 1, [4,5,6], 3, 1),
        ("Test 6: Empty arrays", [], 0, [], 0, 0),
        ("Test 7: A empty", [], 0, [1,2,3], 3, 0),
        ("Test 8: B empty", [1,2,3], 3, [], 0, 0),
    ]
    
    passed = failed = 0
    
    for desc, arr_a, len_a, arr_b, len_b, exp in test_cases:
        cocotb.log.info(f"Running: {desc}")
        try:
            # Write arrays
            await write_array(dut, 'arr_a_', arr_a, len_a)
            await write_array(dut, 'arr_b_', arr_b, len_b)
            
            # Set lengths
            dut.len_a.value = len_a
            dut.len_b.value = len_b
            
            if is_seq:
                # Sequential mode: trigger start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                # Combinational: wait for propagation
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.overlapping.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.overlapping.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Final result
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")