import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 300

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

async def write_input_array(dut, vals, width=DATA_WIDTH, size=ARRAY_SIZE):
    """Write signed integer values to individual array ports"""
    for i in range(size):
        if i < len(vals):
            val = from_signed(vals[i], width)  # Convert negative to 2's complement
            dut.__setattr__(f'arr_i_{i}').value = clamp_to_width(val, width)
        else:
            dut.__setattr__(f'arr_i_{i}').value = 0

async def read_output_array(dut, width=DATA_WIDTH, size=ARRAY_SIZE):
    """Read signed integers from output array"""
    result = []
    for i in range(size):
        val = int(dut.__getattr__(f'arr_o_{i}').value)
        if is_value_defined(val):
            result.append(to_signed(val, width))
        else:
            result.append(0)
    return result

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_neg_nos(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        # (input_list, expected_output_list, description)
        ([-1, 4, 5, -6], [-1, -6], "mixed positive and negative"),
        ([-1, -2, 3, 4], [-1, -2], "two negatives first"),
        ([-7, -6, 8, 9], [-7, -6], "two negatives first, longer positive"),
        ([1, 2, 3, 4], [], "all positive"),
        ([-1, -2, -3, -4], [-1, -2, -3, -4], "all negative"),
        ([0, 0, 0, 0], [], "all zero"),
        ([-1, 1, -2, 2, -3, 3, -4, 4], [-1, -2, -3, -4], "alternating sign, full array"),
    ]
    
    passed = failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"  Input: {inp}")
        cocotb.log.info(f"  Expected output: {exp}")
        
        try:
            # Write input array
            if is_seq:
                await write_input_array(dut, inp, DATA_WIDTH, ARRAY_SIZE)
                dut.len_i.value = len(inp)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await write_input_array(dut, inp, DATA_WIDTH, ARRAY_SIZE)
                dut.len_i.value = len(inp)
                await Timer(100, units='ns')
            
            # Read results
            result = await read_output_array(dut, DATA_WIDTH, ARRAY_SIZE)
            len_o = safe_int(dut.len_o.value)
            
            if not is_value_defined(dut.len_o.value):
                raise TestFailure("len_o undefined")
            
            # Extract actual negatives (ignore zero-padded tail)
            actual_negs = result[:len_o]
            
            cocotb.log.info(f"  Got output: {actual_negs}, len_o={len_o}")
            
            if actual_negs != exp:
                raise TestFailure(f"Expected {exp}, got {actual_negs}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")
