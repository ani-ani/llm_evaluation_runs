import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 4
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array(dut, name, vals, width):
    # Ensure we have at least ARRAY_SIZE elements
    vals_padded = vals + [0] * (ARRAY_SIZE - len(vals))
    for i, v in enumerate(vals_padded):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

async def read_result(dut):
    return int(dut.result.value)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_max_num(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - just set inputs
        pass
    
    # Test cases: (digits list, expected result, description)
    test_cases = [
        ([1, 2, 3], 321, "Simple 3-digit"),
        ([4, 5, 6, 1], 6541, "4-digit"),
        ([1, 2, 3, 9], 9321, "4-digit with 9"),
        ([9, 9, 9, 9, 9, 9, 9, 9], 99999999, "8 nines"),
        ([0, 0, 0], 0, "All zeros"),
        ([5], 5, "Single digit")
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {inp}")
        try:
            # Write input digits
            await write_array(dut, 'digits', inp, DATA_WIDTH)
            
            # Write length
            if has_signal(dut, 'len'):
                dut.len.value = len(inp)
            
            if is_seq:
                # Start the operation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=MAX_CYCLES)
            else:
                # Combinational logic, give some propagation time
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = await read_result(dut)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
