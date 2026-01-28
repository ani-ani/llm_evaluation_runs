import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_string_array(dut, text):
    # Pad string to exactly 8 characters
    padded = (text + '\x00' * 8)[:8]
    ascii_vals = [ord(c) for c in padded]
    
    # Accessing unpacked array elements individually
    # Assuming dut.input_str is an array of signals like dut.input_str[0], dut.input_str[1]...
    # Note: Some simulators require different access methods for unpacked arrays.
    # We will try to access attributes directly or iterate.
    
    # Try to access as a list if dut.input_str is a ModifiableObject list
    try:
        arr = dut.input_str
        # If it's a list-like object in cocotb
        for i in range(8):
            arr[i].value = ascii_vals[i]
    except (TypeError, AttributeError):
        # Fallback if dut.input_str is not iterable directly as a list
        # Try accessing specific named signals if flattened (e.g., input_str_0)
        # This handles cases where the array is flattened to individual ports
        for i in range(8):
            try:
                port = getattr(dut, f'input_str_{i}')
                port.value = ascii_vals[i]
            except AttributeError:
                # Last resort: break if signal doesn't exist
                break

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_md5_hash(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_hash_hex)
    # Note: Expected hashes are 32 hex chars (128 bits)
    test_cases = [
        ("Hello world", "3e25960a79dbc69b674cd4ec67a72c62"),
        ("", "00000000000000000000000000000000"),
        ("A B C", "000000000ef78513b0cb8cef12743f5aeb35f888".zfill(32)[-32:]), # Pad to 32 hex chars
        ("password", "000000005f4dcc3b5aa765d61d8327deb882cf99".zfill(32)[-32:])
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp_str, exp_hash_hex) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input '{inp_str}'")
        
        try:
            # Write input string
            await write_string_array(dut, inp_str)
            
            # Assert valid_in high
            dut.valid_in.value = 1
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done or assume combinational delay
            # If sequential, wait for done. If combinational, result is ready next cycle.
            # According to prompt, done is asserted when valid_in is high.
            # Let's wait for done signal.
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.hash_out.value):
                raise TestFailure("Result undefined")
                
            result_hex = f"{int(dut.hash_out.value):032x}"
            
            if result_hex != exp_hash_hex:
                raise TestFailure(f"Expected {exp_hash_hex}, got {result_hex}")
                
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
