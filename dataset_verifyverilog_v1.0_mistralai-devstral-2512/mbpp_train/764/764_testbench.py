import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 100

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

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(1, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(1, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def write_string(dut, s):
    """Write ASCII string to str_data array, mark valid positions"""
    # Pad string to MAX_LEN with zeros (null bytes)
    padded = s.ljust(MAX_LEN, '\x00')
    
    # Convert to ASCII bytes
    ascii_vals = [ord(c) for c in padded[:MAX_LEN]]
    
    # Create valid mask (1 for non-null characters)
    valid_mask = 0
    for i in range(MAX_LEN):
        if ascii_vals[i] != 0:
            valid_mask |= (1 << i)
    
    # Write to str_data array (individual elements)
    for i in range(MAX_LEN):
        dut.str_data[i].value = clamp_to_width(ascii_vals[i], DATA_WIDTH)
    
    # Write valid mask
    if has_signal(dut, 'str_valid'):
        dut.str_valid.value = valid_mask
    
    return ascii_vals, valid_mask

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_number_ctr(dut):
    """Test digit counting in string"""
    
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: still need to check results
        dut.rst_n.value = 1
    
    # Test cases
    test_cases = [
        ('program2bedone', 1, "single digit at end"),
        ('3wonders', 1, "single digit at start"),
        ('123', 3, "three consecutive digits"),
        ('3wond-1ers2', 3, "digits with hyphen"),
        ('', 0, "empty string"),
        ('abcdefghij', 0, "no digits"),
        ('1234567890', 10, "ten digits"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp_str, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write string to DUT
            ascii_vals, valid_mask = await write_string(dut, inp_str)
            
            # For combinational: just wait a bit
            if is_seq:
                # Sequential: assert start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational: wait for propagation
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result} for string '{inp_str}'")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info("All tests passed!")