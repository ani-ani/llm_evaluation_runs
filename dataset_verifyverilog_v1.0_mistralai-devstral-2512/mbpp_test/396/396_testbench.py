import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers from template
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def ascii_to_bytes(s):
    return [ord(c) for c in s]

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

async def write_string(dut, string_str):
    """Write string to array, pad with zeros"""
    bytes_arr = ascii_to_bytes(string_str)
    length = len(bytes_arr)
    dut.string_len.value = length
    
    # Write individual bytes
    for i in range(8):
        val = bytes_arr[i] if i < length else 0
        dut.string_data[i].value = clamp_to_width(val, 8)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_check_char(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ("abba", 1, "abba"),
        ("a", 1, "single char"),
        ("abcd", 0, "different chars"),
        ("", 0, "empty string"),
        ("xyzxyz", 1, "xyzxyz"),
        ("abcxyz", 0, "abcxyz")
    ]
    
    passed = failed = 0
    
    for i, (string, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{string}' - {desc}")
        try:
            # Write input
            await write_string(dut, string)
            
            # Start operation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational mode
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")