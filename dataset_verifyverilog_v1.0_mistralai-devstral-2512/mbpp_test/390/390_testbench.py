import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Configuration
DATA_WIDTH = 4
ARRAY_SIZE = 16
STRING_WIDTH = 8  # chars
CLK_NS = 10
MAX_CYCLES = 50

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

def ascii_char_to_val(c):
    """Convert ASCII char to 4-bit value for input"""
    if '0' <= c <= '9':
        return ord(c) - ord('0')
    elif 'A' <= c <= 'F':
        return ord(c) - ord('A') + 10
    else:
        return 0

def val_to_ascii_char(v):
    """Convert 4-bit value to ASCII character"""
    if v < 10:
        return chr(ord('0') + v)
    else:
        return chr(ord('A') + v - 10)

def create_prefix_suffix(prefix_str, suffix_str, width=STRING_WIDTH):
    """Pack ASCII string into 64-bit value (8 chars * 8 bits)"""
    prefix_val = 0
    suffix_val = 0
    
    for i in range(width):
        if i < len(prefix_str):
            char_val = ord(prefix_str[i])
        else:
            char_val = 0x20  # space
        prefix_val |= (char_val & 0xFF) << ((width - 1 - i) * 8)
    
    for i in range(width):
        if i < len(suffix_str):
            char_val = ord(suffix_str[i])
        else:
            char_val = 0x20  # space
        suffix_val |= (char_val & 0xFF) << ((width - 1 - i) * 8)
    
    return prefix_val, suffix_val

def pack_result_string(chars):
    """Pack 8 ASCII characters into 64-bit value"""
    result = 0
    for i, char in enumerate(chars):
        result |= (ord(char) & 0xFF) << ((7 - i) * 8)
    return result

async def write_input_array(dut, values):
    """Write values to data_in array"""
    for i in range(ARRAY_SIZE):
        if i < len(values):
            val = ascii_char_to_val(values[i])
        else:
            val = 0
        getattr(dut, f'data_in_{i}').value = clamp_to_width(val, DATA_WIDTH)

async def read_result_array(dut):
    """Read formatted strings from result array"""
    results = []
    for i in range(ARRAY_SIZE):
        result_val = int(getattr(dut, f'result_{i}').value)
        # Extract 8 characters from 64-bit value
        chars = []
        for j in range(8):
            char_val = (result_val >> ((7 - j) * 8)) & 0xFF
            if char_val >= 0x20 and char_val <= 0x7E:
                chars.append(chr(char_val))
            else:
                chars.append('?')
        results.append(''.join(chars).rstrip())
    return results

async def reset_dut(dut):
    """Reset the DUT"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    """Wait for done signal"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_string_format(dut):
    """Test string formatting functionality"""
    
    # Check if sequential (has clk)
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {
            'prefix': 'temp',
            'suffix': '',
            'inputs': ['1', '2', '3', '4'],
            'expected': ['temp1', 'temp2', 'temp3', 'temp4']
        },
        {
            'prefix': 'python',
            'suffix': '',
            'inputs': ['A', 'B', 'C', 'D'],  # Using A=10, B=11, etc.
            'expected': ['pythonA', 'pythonB', 'pythonC', 'pythonD']
        },
        {
            'prefix': 'string',
            'suffix': '',
            'inputs': ['5', '6', '7', '8'],
            'expected': ['string5', 'string6', 'string7', 'string8']
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, test in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: prefix='{test['prefix']}', inputs={test['inputs']}")
        
        try:
            # Set prefix and suffix
            prefix_val, suffix_val = create_prefix_suffix(test['prefix'], test['suffix'])
            dut.prefix.value = prefix_val
            dut.suffix.value = suffix_val
            
            # Write input array
            for j in range(ARRAY_SIZE):
                if j < len(test['inputs']):
                    val = ascii_char_to_val(test['inputs'][j])
                else:
                    val = 0
                getattr(dut, f'data_in_{j}').value = clamp_to_width(val, DATA_WIDTH)
            
            # Start operation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read results
            results = []
            for j in range(ARRAY_SIZE):
                result_val = int(getattr(dut, f'result_{j}').value)
                # Extract characters
                chars = []
                for k in range(8):
                    char_val = (result_val >> ((7 - k) * 8)) & 0xFF
                    if char_val >= 0x20 and char_val <= 0x7E:
                        chars.append(chr(char_val))
                    else:
                        chars.append('?')
                results.append(''.join(chars).rstrip())
            
            # Verify results
            for j, (result, expected) in enumerate(zip(results[:len(test['expected'])], test['expected'])):
                if result != expected:
                    raise TestFailure(f"Index {j}: Expected '{expected}', got '{result}'")
            
            # Check done signal
            if is_seq:
                if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                    raise TestFailure("done signal not set")
            
            cocotb.log.info(f"  PASS: Results match expected")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"\nAll {passed} tests passed!")