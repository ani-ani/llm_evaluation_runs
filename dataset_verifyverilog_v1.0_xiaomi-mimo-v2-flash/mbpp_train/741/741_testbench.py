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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_string(dut, s):
    """Write ASCII string to character array"""
    if len(s) > 8:
        raise TestFailure(f"String too long: {len(s)} > 8")
    chars = [ord(c) for c in s]
    while len(chars) < 8:
        chars.append(32)  # Pad with space
    for i, c in enumerate(chars):
        dut.char[i].value = c

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_all_characters_same(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational version
        pass
    
    # Test cases: (input_string, expected_result, description)
    test_cases = [
        ("python", 0, "Different characters"),
        ("aaa", 1, "All same 'a'"),
        ("data", 0, "Different characters"),
        ("aaaa", 1, "Four 'a's"),
        ("", 1, "Empty string (all 8 spaces)"),
        ("11111111", 1, "All '1's"),
        ("a b a b ", 0, "Spaces with differences")
    ]
    
    passed = failed = 0
    
    for i, (inp_str, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - '{inp_str}'")
        try:
            # Write string
            await write_string(dut, inp_str)
            
            if is_seq:
                # Start comparison
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut, max_cycles=20)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                result = int(dut.result.value)
            else:
                # Combinational - just read
                await Timer(100, units='ns')
                result = int(dut.result.value)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    else:
        cocotb.log.info(f"All {passed} tests passed!")