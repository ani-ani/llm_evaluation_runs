import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

# ASCII conversion helpers
def to_ascii_bytes(s):
    return [ord(c) for c in str(s)]

def from_ascii_bytes(bytes):
    return ''.join(chr(b) for b in bytes if b != 0)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(1, units='ns')
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

# Test cases from examples
TEST_CASES = [
    (2, "6"),
    (3, "6669"),
    (10, "-1"),
    (1000, "-1"),
    (4, "75"),
    (5, "-1"),
    (6, "8333333333333334"),
    (7, "14286"),
    (8, "125"),
    (9, "11111111111111111111111111111111111111111111111111111111111111111111111111111112"),
    (11, "1818181818181818181818181819009091009091"),
    (12, "58333333333333333333333333333333333333333333333333333333333334009175"),
    (13, "307692307692307692307692307692307692307692307693008540"),
    (14, "6428571428571428571428571428571428571428571428571428571428572007145"),
    (15, "4666666666666666666666666666666666667006674006668"),
    (16, "-1"),
    (32, "-1"),
    (64, "-1"),
    (128, "-1"),
    (256, "-1"),
    (512, "-1"),
    (20, "-1"),
    (40, "-1"),
    (80, "-1"),
    (160, "-1"),
    (320, "-1"),
    (640, "-1"),
    (25, "-1"),
    (50, "-1"),
    (100, "-1"),
    (200, "-1"),
    (400, "-1"),
    (800, "-1"),
    (125, "-1"),
    (250, "-1"),
    (500, "-1"),
    (625, "-1"),
    (31, "64516129032258064516129032258064516129032258064516129032258064516129032258064516129032258064516129032258064516129032258064516129032258064516129032259009710"),
    (43, "93023255813953488372093023255813953488372093023255813953488372093023255813953488372093023255813953488372093023255813953488372093023255813953488372093023255813953488372093023255813953488372093023255813953488372093023255813953488372093023255813953488372093023255813953488372093023255813953488373009884"),
]

MAX_OUTPUT_LEN = 1000  # Keep manageable for simulation

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_baron_munchausen(dut):
    """Test the Baron Munchausen digit sum solver module"""
    
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, (a_in, expected_output) in enumerate(TEST_CASES):
        cocotb.log.info(f"Test {i+1}: a={a_in}, expected={expected_output[:50]}..." if len(expected_output) > 50 else f"Test {i+1}: a={a_in}, expected={expected_output}")
        
        try:
            # Set input a
            if has_signal(dut, 'a'):
                dut.a.value = clamp_to_width(a_in, 10)
            
            # Start computation
            if is_seq and has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check valid flag
            valid = 0
            if has_signal(dut, 'valid'):
                if not is_value_defined(dut.valid.value):
                    raise TestFailure("Valid signal undefined")
                valid = int(dut.valid.value)
            
            # Read output string
            result_str = ""
            if has_signal(dut, 'n_str'):
                # Array of bytes (ASCII)
                bytes_list = []
                for j in range(min(MAX_OUTPUT_LEN, 500)):
                    try:
                        if hasattr(dut.n_str[j], 'value'):
                            byte_val = int(dut.n_str[j].value)
                            if byte_val != 0:
                                bytes_list.append(byte_val)
                    except (AttributeError, ValueError):
                        pass
                result_str = ''.join(chr(b) for b in bytes_list if 32 <= b < 127)
            elif has_signal(dut, 'result'):
                # Single value - convert to string
                if is_value_defined(dut.result.value):
                    result_val = int(dut.result.value)
                    if result_val == -1 or result_val == 0:
                        result_str = "-1"
                    else:
                        result_str = str(result_val)
            
            # Validate
            if expected_output == "-1":
                if valid == 0 or result_str.find('-1') != -1:
                    passed += 1
                else:
                    raise TestFailure(f"Expected -1, got valid={valid}, result={result_str}")
            else:
                if result_str == expected_output:
                    passed += 1
                else:
                    raise TestFailure(f"Mismatch. Expected: {expected_output}, Got: {result_str}")
                    
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}, a={a_in}): {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR (Test {i+1}, a={a_in}): {e}")
            failed += 1
    
    cocotb.log.info(f"Results: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
