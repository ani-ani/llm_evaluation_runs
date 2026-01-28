import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
STRING_LEN = 8
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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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

def str_to_array(s, length=STRING_LEN):
    """Convert string to ASCII list, pad with zeros if needed"""
    ascii_vals = [ord(c) for c in s]
    if len(ascii_vals) < length:
        ascii_vals.extend([0] * (length - len(ascii_vals)))
    else:
        ascii_vals = ascii_vals[:length]
    return ascii_vals

def array_to_str(arr):
    """Convert ASCII list back to string, skip zeros"""
    s = ''.join(chr(v) for v in arr if v != 0)
    return s

async def write_string(dut, name, s):
    """Write string to dut array ports"""
    ascii_vals = str_to_array(s)
    for i in range(STRING_LEN):
        getattr(dut, f'{name}_{i}').value = clamp_to_width(ascii_vals[i], DATA_WIDTH)

async def read_string(dut, name):
    """Read string from dut array ports"""
    ascii_vals = []
    for i in range(STRING_LEN):
        val = getattr(dut, f'{name}_{i}').value
        if is_value_defined(val):
            ascii_vals.append(int(val))
        else:
            ascii_vals.append(0)
    return ascii_vals

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_replace_char(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational case
        await Timer(100, units='ns')
    
    test_cases = [
        ("polygon", 'y', 'l', "pollgon"),
        ("character", 'c', 'a', "aharaater"),
        ("python", 'l', 'a', "python"),
        ("aaaa", 'a', 'b', "bbbb"),
        ("test", 'x', 'y', "test"),  # No match
        ("test", 't', 't', "test"),  # Same char
        ("        ", ' ', '.', "........"),  # Spaces
        ("a", 'a', 'b', "b"),  # Single char
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, old_ch, new_ch, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: replace '{old_ch}' with '{new_ch}' in '{input_str}' -> '{expected}'")
        try:
            # Write inputs
            await write_string(dut, 'str_in', input_str)
            
            if is_seq:
                dut.old_char.value = ord(old_ch)
                dut.new_char.value = ord(new_ch)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational
                dut.old_char.value = ord(old_ch)
                dut.new_char.value = ord(new_ch)
                await Timer(10, units='ns')
            
            # Read outputs
            result_ascii = await read_string(dut, 'str_out')
            result_str = array_to_str(result_ascii)
            
            if result_str != expected:
                raise TestFailure(f"Expected '{expected}', got '{result_str}'")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_random_cases(dut):
    """Test random strings and characters"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    random.seed(42)
    num_random = 5
    
    for i in range(num_random):
        # Generate random string
        s = ''.join(chr(random.randint(97, 122)) for _ in range(STRING_LEN))
        old_ch = chr(random.randint(97, 122))
        new_ch = chr(random.randint(97, 122))
        
        # Python reference
        expected = s.replace(old_ch, new_ch)
        
        cocotb.log.info(f"Random test {i+1}: '{s}' replace '{old_ch}' with '{new_ch}' -> '{expected}'")
        
        try:
            await write_string(dut, 'str_in', s)
            
            if is_seq:
                dut.old_char.value = ord(old_ch)
                dut.new_char.value = ord(new_ch)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                dut.old_char.value = ord(old_ch)
                dut.new_char.value = ord(new_ch)
                await Timer(10, units='ns')
            
            result_ascii = await read_string(dut, 'str_out')
            result_str = array_to_str(result_ascii)
            
            if result_str != expected:
                raise TestFailure(f"Random test failed: expected '{expected}', got '{result_str}'")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            raise
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            raise
    
    cocotb.log.info(f"All {num_random} random tests passed!")