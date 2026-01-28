import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Helpers from the template
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

# Helper to write string to array
def write_string_to_array(dut, string, data_width=8):
    """Write ASCII string to input array, padding with spaces if needed"""
    # Convert string to list of ASCII values
    chars = list(string)
    ascii_vals = [ord(c) for c in chars]
    
    # Pad with spaces (0x20) to reach ARRAY_SIZE
    while len(ascii_vals) < ARRAY_SIZE:
        ascii_vals.append(0x20)
    
    # Write each byte individually
    for i, val in enumerate(ascii_vals):
        dut.input_string[i].value = clamp_to_width(val, data_width)
    
    return len(chars)

# Helper to read output array
def read_string_from_array(dut, data_width=8):
    """Read ASCII string from output array"""
    result = []
    for i in range(ARRAY_SIZE):
        if has_signal(dut, f'output_string_{i}'):
            val = int(getattr(dut, f'output_string_{i}').value)
        else:
            val = int(dut.output_string[i].value)
        if val != 0x20:  # Stop at space padding
            result.append(chr(val))
        else:
            break
    return ''.join(result)

# Expected result for test cases
def expected_result(test_str):
    """Python version of the expected transformation"""
    res = ''
    dig = ''
    for ele in test_str:
        if ele.isdigit():
            dig += ele
        else:
            res += ele
    res += dig
    return res

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_move_num(dut):
    """Test the move_num module with various test cases"""
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Start clock
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational - just wait
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        ('I1love143you55three3000thousand', 'Iloveyouthreethousand1143553000'),
        ('Avengers124Assemble', 'AvengersAssemble124'),
        ('Its11our12path13to14see15things16do17things', 'Itsourpathtoseethingsdothings11121314151617'),
        ('abc123', 'abc123'),  # Edge: all non-digits then digits
        ('123abc', 'abc123'),  # Edge: all digits then non-digits
        ('1a2b3c', 'abc123'),  # Edge: mixed
        ('', ''),  # Edge: empty string
        ('1', '1'),  # Edge: single digit
        ('a', 'a'),  # Edge: single letter
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input='{input_str}', Expected='{expected_str}'")
        
        try:
            # Write input string
            actual_len = write_string_to_array(dut, input_str)
            
            # Write valid length (actual string length)
            if has_signal(dut, 'valid_length'):
                dut.valid_length.value = actual_len
            
            if is_seq:
                # Start processing
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=100)
                
                # Check valid signal
                if has_signal(dut, 'valid'):
                    valid_val = int(dut.valid.value)
                    if valid_val != 1:
                        raise TestFailure(f"Valid signal should be 1, got {valid_val}")
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read output
            output_str = read_string_from_array(dut)
            
            # The output may have spaces, strip them for comparison
            # But digits should be at the end
            output_stripped = output_str.rstrip(' ')
            
            # For empty string case
            if expected_str == '':
                expected_stripped = ''
            else:
                expected_stripped = expected_str
            
            # Compare
            if output_stripped != expected_stripped:
                raise TestFailure(f"Output mismatch. Got '{output_stripped}', expected '{expected_stripped}'")
            
            # Additional check: digits should be at the end
            # Find first digit position
            first_digit = None
            for idx, char in enumerate(output_stripped):
                if char.isdigit():
                    first_digit = idx
                    break
            
            if first_digit is not None:
                # Check all characters after first digit are digits
                for idx in range(first_digit, len(output_stripped)):
                    if not output_stripped[idx].isdigit():
                        raise TestFailure(f"Non-digit found after first digit at position {idx}")
            
            cocotb.log.info(f"Test {i+1} PASSED")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
            
        # Small delay between tests for sequential
        if is_seq:
            await Timer(CLK_NS * 2, units='ns')
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")

# Helper function to wait for done signal
async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal to become 1"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done'):
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
    raise TestFailure(f"Timeout after {max_cycles} cycles waiting for done signal")
