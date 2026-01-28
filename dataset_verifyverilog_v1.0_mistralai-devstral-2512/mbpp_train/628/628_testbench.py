import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
MAX_INPUT_LEN = 16
MAX_OUTPUT_LEN = 24
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

def string_to_bytes(s):
    """Convert Python string to list of ASCII bytes."""
    return [ord(c) for c in s] + [0x00] * (MAX_INPUT_LEN - len(s))

def bytes_to_string(b):
    """Convert list of bytes to Python string, stopping at null."""
    chars = []
    for byte in b:
        if byte == 0x00:
            break
        chars.append(chr(byte))
    return ''.join(chars)

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

async def write_input_string(dut, s):
    """Write input string to dut.input_str array."""
    bytes_list = string_to_bytes(s)
    for i, byte in enumerate(bytes_list[:MAX_INPUT_LEN]):
        if has_signal(dut, f'input_str_{i}'):
            getattr(dut, f'input_str_{i}').value = clamp_to_width(byte, DATA_WIDTH)
        elif has_signal(dut, 'input_str'):
            dut.input_str[i].value = clamp_to_width(byte, DATA_WIDTH)

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_replace_spaces(dut):
    # Check for required signals
    if not (has_signal(dut, 'clk') and has_signal(dut, 'rst_n')):
        raise TestFailure("Missing required signals: clk, rst_n")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_output_string, description)
    test_cases = [
        ("My Name is Dawood", "My%20Name%20is%20Dawood", "Basic case with multiple spaces"),
        ("I am a Programmer", "I%20am%20a%20Programmer", "Four spaces"),
        ("I love Coding", "I%20love%20Coding", "Two spaces"),
        ("NoSpaces", "NoSpaces", "No spaces"),
        ("Space at end ", "Space%20at%20end%20", "Trailing space"),
        ("  ", "%20%20", "Two spaces only"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_output, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        cocotb.log.info(f"  Input: '{input_str}' (len={len(input_str)})")
        cocotb.log.info(f"  Expected: '{expected_output}' (len={len(expected_output)})")
        
        try:
            # Write input
            await write_input_string(dut, input_str)
            
            # Set input length
            input_len = len(input_str)
            if has_signal(dut, 'input_len'):
                dut.input_len.value = clamp_to_width(input_len, 4)
            else:
                cocotb.log.warning("input_len signal not found, assuming full length")
            
            # Start operation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read output
            if not is_value_defined(dut.output_len.value):
                raise TestFailure("output_len undefined")
            
            output_len = int(dut.output_len.value)
            cocotb.log.info(f"  Output length: {output_len}")
            
            # Read output string
            output_chars = []
            for idx in range(MAX_OUTPUT_LEN):
                if has_signal(dut, f'output_str_{idx}'):
                    byte_val = int(getattr(dut, f'output_str_{idx}').value)
                elif has_signal(dut, 'output_str'):
                    byte_val = int(dut.output_str[idx].value)
                else:
                    break
                
                # Stop at null or max length
                if byte_val == 0x00 and len(output_chars) == 0:
                    continue
                if byte_val == 0x00:
                    break
                output_chars.append(byte_val)
            
            output_string = ''.join(chr(b) for b in output_chars[:output_len])
            cocotb.log.info(f"  Output: '{output_string}'")
            
            # Validate
            if output_len != len(expected_output):
                raise TestFailure(f"Length mismatch: expected {len(expected_output)}, got {output_len}")
            
            if output_string != expected_output:
                raise TestFailure(f"Content mismatch: expected '{expected_output}', got '{output_string}'")
            
            passed += 1
            cocotb.log.info(f"  Result: PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  Result: FAIL - {e}")
            failed += 1
        
        # Prepare for next test
        if i < len(test_cases) - 1:
            await reset_dut(dut)
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")
    
    cocotb.log.info(f"\nAll {passed} tests passed!")
