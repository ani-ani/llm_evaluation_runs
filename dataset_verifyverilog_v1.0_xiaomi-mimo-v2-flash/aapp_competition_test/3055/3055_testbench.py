import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
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

# Test constants
CLK_NS = 10
MAX_CYCLES = 1000
DATA_WIDTH = 8
MAX_NAMES = 100
MAX_NAME_LEN = 14  # Only first 14 chars needed

THOREHUSFELDT = "ThoreHusfeldt"  # 13 chars? Wait: T(1)h(2)o(3)r(4)e(5)H(6)u(7)s(8)f(9)e(10)l(11)d(12)t(13) - 13 chars
# Actually: ThoreHusfeldt = 13 characters
THOREHUSFELDT_BYTES = [ord(c) for c in THOREHUSFELDT]  # 13 bytes
THOREHUSFELD = "ThoreHusfeld"  # 12 chars
THOREHUSFELD_BYTES = [ord(c) for c in THOREHUSFELD]  # 12 bytes

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'name_valid'): dut.name_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_string_to_bytes(s, length=14):
    """Pack string into 8-bit array values"""
    bytes_list = [ord(c) for c in s[:length]]
    while len(bytes_list) < length:
        bytes_list.append(0)  # Pad with null
    return bytes_list

async def send_name(dut, name, name_index, clk):
    """Send a name character by character via name_char/name_valid signals"""
    if has_signal(dut, 'name_char') and has_signal(dut, 'name_valid'):
        # Send max 14 chars or actual length
        send_len = min(len(name), 14)
        for i in range(send_len):
            dut.name_char.value = ord(name[i])
            dut.name_valid.value = 1
            dut.name_index.value = name_index
            await RisingEdge(clk)
        # Send termination signal (null or index wrap)
        dut.name_valid.value = 0
        await RisingEdge(clk)

@cocotb.test(timeout_time=10000, timeout_unit="ns")
async def test_thore_prefix(dut):
    """Test ThoreHusfeldt prefix finding logic"""
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # (names_list, thore_position, expected_output_type, description)
        ("2\nThoreTiemann\nThoreHusfeldt\n", 1, "ThoreH", "Another Thore above, best ThoreH"),
        ("2\nThoreHusfeldt\nJohanSannemo\n", 0, "Thore is awesome", "Thore first"),
        ("2\nThoreHusfeldter\nThoreHusfeldt\n", 1, "Thore sucks", "ThoreHusfeld prefix above"),
        ("2\nJohanSannemo\nThoreHusfeldt\n", 1, "T", "Unique single char prefix"),
    ]
    
    for test_idx, (input_str, thore_idx, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx+1}: {desc}")
        
        # Parse input
        lines = input_str.strip().split('\n')
        n = int(lines[0])
        names = lines[1:]
        
        # Assert ThoreHusfeldt at expected position
        if names[thore_idx] != "ThoreHusfeldt":
            raise TestFailure(f"Test case setup error: ThoreHusfeldt not at index {thore_idx}")
        
        # Send all names
        for i, name in enumerate(names):
            await send_name(dut, name, i, dut.clk)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for result
        await wait_for_done(dut)
        
        # Read result bytes
        result_chars = []
        max_result_len = 20  # "Thore is awesome" = 15 chars
        
        for i in range(max_result_len):
            if has_signal(dut, f'result_byte_{i}'):
                val = int(getattr(dut, f'result_byte_{i}').value)
                if val != 0:
                    result_chars.append(chr(val))
            elif has_signal(dut, 'result_char'):
                # Read sequentially
                if i == 0:
                    # Reset reading
                    pass
                val = int(dut.result_char.value)
                if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                    if val != 0:
                        result_chars.append(chr(val))
            else:
                # Try reading packed array
                break
        
        result_str = ''.join(result_chars)
        
        # Validate
        if expected == "Thore is awesome":
            expected_str = "Thore is awesome"
        elif expected == "ThoreH":
            expected_str = "ThoreH"
        elif expected == "Thore sucks":
            expected_str = "Thore sucks"
        elif expected == "T":
            expected_str = "T"
        else:
            raise TestFailure(f"Unknown expected output: {expected}")
        
        if result_str != expected_str:
            raise TestFailure(f"Expected '{expected_str}', got '{result_str}'")
        
        cocotb.log.info(f"PASS: Got expected '{result_str}'")
        
        # Reset for next test
        await reset_dut(dut)
    
    cocotb.log.info("All tests passed!")
