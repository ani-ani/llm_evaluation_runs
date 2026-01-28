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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# ASCII character helpers
def char_to_ascii(c):
    return ord(c) if c else 0

# Wait for done signal
async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Reset DUT
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'char_valid'): dut.char_valid.value = 0
    if has_signal(dut, 'char_done'): dut.char_done.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Send a character to DUT
async def send_char(dut, c, cycle=0):
    char_val = char_to_ascii(c)
    dut.char_in.value = clamp_to_width(char_val, 8)
    dut.char_valid.value = 1
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    await RisingEdge(dut.clk)
    return cycle + 2

# Send string to DUT
async def send_string(dut, s, cycles=0):
    for i, c in enumerate(s):
        cycles = await send_char(dut, c, cycles)
    # Mark end of string
    dut.char_done.value = 1
    await RisingEdge(dut.clk)
    dut.char_done.value = 0
    await RisingEdge(dut.clk)
    return cycles + 2

# Test runner
async def test_file_name(dut, filename, expected_valid, expected_err=0):
    cocotb.log.info(f"Testing: '{filename}' -> Expected: {'Yes' if expected_valid else 'No'}")
    
    # Reset
    await reset_dut(dut)
    
    # Start validation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Send filename
    cycles = 0
    cycles = await send_string(dut, filename, cycles)
    
    # Wait for completion
    await wait_for_done(dut, 200)
    
    # Check results
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    result = int(dut.result.value)
    exp = 1 if expected_valid else 0
    
    if result != exp:
        err_code = safe_int(dut.err_type.value) if has_signal(dut, 'err_type') else 0
        raise TestFailure(f"Expected {exp}, got {result} (err_type={err_code})")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_file_name_check(dut):
    """Test file name validation module"""
    
    # Check for required signals
    if not all([has_signal(dut, s) for s in ['clk', 'rst_n', 'start', 'char_in', 'char_valid', 'char_done', 'result', 'done']]):
        cocotb.log.warning("Some required signals missing, attempting test anyway...")
    
    # Setup clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem description
    test_cases = [
        ("example.txt", True, 0),
        ("1example.dll", False, 4),
        ("s1sdf3.asd", False, 2),  # bad extension
        ("K.dll", True, 0),
        ("MY16FILE3.exe", True, 0),
        ("His12FILE94.exe", False, 3),  # >3 digits
        ("_Y.txt", False, 4),  # bad start
        ("?aREYA.exe", False, 4),  # bad start
        ("/this_is_valid.dll", False, 4),  # bad start
        ("this_is_valid.wow", False, 2),  # bad extension
        ("this_is_valid.txt", True, 0),
        ("this_is_valid.txtexe", False, 6),  # multiple dots
        ("#this2_i4s_5valid.ten", False, 4),  # bad start
        ("@this1_is6_valid.exe", False, 4),  # bad start
        ("this_is_12valid.6exe4.txt", False, 6),  # multiple dots
        ("all.exe.txt", False, 6),  # multiple dots
        ("I563_No.exe", True, 0),
        ("Is3youfault.txt", True, 0),
        ("no_one#knows.dll", True, 0),
        ("1I563_Yes3.exe", False, 4),  # bad start
        ("I563_Yes3.txtt", False, 2),  # bad extension
        ("final..txt", False, 6),  # multiple dots
        ("final132", False, 1),  # no dot
        ("_f4indsartal132.", False, 4),  # bad start
        (".txt", False, 5),  # empty name
        ("s.", False, 5),  # empty extension
    ]
    
    passed = 0
    failed = 0
    
    for i, (filename, expected_valid, expected_err) in enumerate(test_cases):
        try:
            await test_file_name(dut, filename, expected_valid, expected_err)
            passed += 1
            cocotb.log.info(f"  PASS")
        except TestFailure as e:
            failed += 1
            cocotb.log.error(f"  FAIL: {e}")
        except Exception as e:
            failed += 1
            cocotb.log.error(f"  ERROR: {e}")
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")