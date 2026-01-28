import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 32  # Max chars in HW version
CLK_NS = 10
MAX_CYCLES = 256

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
    try: getattr(dut, name); return True
    except AttributeError: return False

def encode_string(s, max_len=ARRAY_SIZE, width=DATA_WIDTH):
    """Convert string to list of ASCII codes, pad with spaces"""
    codes = []
    for char in s[:max_len]:
        codes.append(clamp_to_width(ord(char), width))
    # Pad remaining with spaces
    while len(codes) < max_len:
        codes.append(0x20)  # Space
    return codes

def decode_string(codes):
    """Convert list of ASCII codes to string"""
    return ''.join(chr(clamp_to_width(c, DATA_WIDTH)) for c in codes)

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_encrypted_text(dut, text):
    """Write encrypted text to input array element by element"""
    codes = encode_string(text, ARRAY_SIZE, DATA_WIDTH)
    for i in range(ARRAY_SIZE):
        # Check for encrypted_text array
        if has_signal(dut, f'encrypted_text_{i}'):
            getattr(dut, f'encrypted_text_{i}').value = codes[i]
        elif has_signal(dut, 'encrypted_text'):
            dut.encrypted_text[i].value = codes[i]
        else:
            raise TestFailure("No encrypted_text port found")

async def read_result(dut):
    """Read decrypted result from output array"""
    codes = []
    for i in range(ARRAY_SIZE):
        if has_signal(dut, f'result_{i}'):
            val = getattr(dut, f'result_{i}').value
        elif has_signal(dut, 'result'):
            val = dut.result[i].value
        else:
            raise TestFailure("No result port found")
        if is_value_defined(val):
            codes.append(int(val))
        else:
            codes.append(0x20)  # Default space
    return decode_string(codes)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pirate_decryption(dut):
    """Test the pirate cipher decryption module"""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_text, expected_result_or_none)
    # Note: HW version only processes first 32 chars
    test_cases = [
        ("ex eoii jpxbmx cvz uxju sjzzcn jzz", "we will avenge our dead parrot arr"),
        ("wl jkd", "Impossible"),
        ("dyd jkl cs", "Impossible"),
        ("", "Impossible"),  # Empty input
        ("a b c d e f g", "Impossible"),  # Too many single letters
    ]
    
    passed = 0
    failed = 0
    
    for i, (encrypted, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: Input='{encrypted}'")
        
        try:
            # Write input
            await write_encrypted_text(dut, encrypted)
            
            # Set length if present
            if has_signal(dut, 'length'):
                dut.length.value = clamp_to_width(len(encrypted), 6)
            
            # Start decryption
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut, MAX_CYCLES)
            
            # Check result
            if not is_value_defined(dut.possible.value):
                raise TestFailure("'possible' signal undefined")
            
            possible = int(dut.possible.value)
            result = await read_result(dut)
            
            # Trim result to actual input length
            if len(result) > len(encrypted):
                result = result[:len(encrypted)]
            
            if possible:
                if result != expected:
                    raise TestFailure(f"Expected '{expected}', got '{result}'")
                cocotb.log.info(f"SUCCESS: Decrypted to '{result}'")
            else:
                if expected != "Impossible":
                    raise TestFailure(f"Expected '{expected}', but decryption failed")
                cocotb.log.info("SUCCESS: Correctly identified as Impossible")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    # Final summary
    if failed:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")
    
    cocotb.log.info(f"\nAll {passed} tests passed!")

@cocotb.test(timeout_time=3000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases and bounds"""
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    edge_cases = [
        (" " * 32, "Impossible"),  # All spaces
        ("a" * 20, "Impossible"),  # Repeated single letter
        ("ab cd ef", "Impossible"),  # Not enough constraints
    ]
    
    for i, (encrypted, expected) in enumerate(edge_cases):
        cocotb.log.info(f"Edge test {i+1}: '{encrypted[:20]}...'")
        try:
            await write_encrypted_text(dut, encrypted)
            if has_signal(dut, 'length'):
                dut.length.value = clamp_to_width(len(encrypted), 6)
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut, MAX_CYCLES)
            
            possible = int(dut.possible.value) if is_value_defined(dut.possible.value) else 0
            if possible:
                raise TestFailure(f"Unexpected success for impossible case: {encrypted}")
            cocotb.log.info(f"Edge test {i+1} passed")
            
        except TestFailure as e:
            cocotb.log.error(f"Edge test {i+1} FAIL: {e}")
            raise