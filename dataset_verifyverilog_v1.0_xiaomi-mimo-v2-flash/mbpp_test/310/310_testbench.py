import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

# ASCII whitespace constants
SPACE = 0x20
TAB = 0x09
NEWLINE = 0x0A

def is_whitespace(byte_val):
    byte_val = byte_val & 0xFF
    return byte_val == SPACE or byte_val == TAB or byte_val == NEWLINE

async def write_string(dut, string_val, length):
    """Write ASCII string to dut.input_string array, truncated to length"""
    # Pad with zeros
    padded = string_val.ljust(16, ' ')
    for i in range(16):
        char = padded[i] if i < len(string_val) else ' '
        ascii_val = ord(char)
        # Assign to input_string array (assumes it's indexable)
        dut.input_string[i].value = ascii_val
    dut.input_length.value = length

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_string_to_tuple(dut):
    CLK_NS = 10
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational module
        await Timer(1, units='ns')
    
    test_cases = [
        ("python 3.0", 11, [ord('p'), ord('y'), ord('t'), ord('h'), ord('o'), ord('n'), ord('3'), ord('.'), ord('0')], 9),
        ("item1", 5, [ord('i'), ord('t'), ord('e'), ord('m'), ord('1')], 5),
        ("15.10", 5, [ord('1'), ord('5'), ord('.'), ord('1'), ord('0')], 5),
        ("a b c", 5, [ord('a'), ord('b'), ord('c')], 3),
        ("   ", 3, [], 0),
        ("hello", 5, [ord('h'), ord('e'), ord('l'), ord('l'), ord('o')], 5),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, input_len, expected_bytes, expected_len) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{input_str}' -> expected {expected_len} chars")
        try:
            # Write input
            await write_string(dut, input_str, input_len)
            
            # Start processing
            if has_signal(dut, 'clk'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational: wait for settle
                await Timer(10, units='ns')
            
            # Read output
            output_len = int(dut.output_length.value) if is_value_defined(dut.output_length.value) else 0
            
            # Verify length
            if output_len != expected_len:
                raise TestFailure(f"Length mismatch: expected {expected_len}, got {output_len}")
            
            # Read output tuple (each byte)
            output_bytes = []
            for j in range(16):
                byte_val = int(dut.output_tuple[j].value) if is_value_defined(dut.output_tuple[j].value) else 0
                if j < output_len:
                    output_bytes.append(byte_val)
            
            # Verify bytes
            if output_bytes != expected_bytes:
                raise TestFailure(f"Tuple mismatch: expected {expected_bytes}, got {output_bytes}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {output_bytes}")
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAIL: {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
    
    cocotb.log.info(f"All {passed} tests passed")
