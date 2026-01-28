import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# MANDATORY HELPERS
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

# ARRAY ACCESS: always individual
def write_char(dut, char, valid, last, width=8):
    dut.str_data.value = clamp_to_width(ord(char), width) if char else 0
    dut.str_valid.value = valid
    dut.str_last.value = last

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

CLK_NS = 10
MAX_CYCLES = 200

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_correct_bracketing(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (string, expected_result)
    test_cases = [
        ("<>", True, "simple pair"),
        ("<<><>>", True, "nested pairs"),
        ("<><><<><>><>", True, "mixed pairs"),
        ("<><><<<><><>><>><<><><<>>>", True, "long valid"),
        ("<<<><>>>>", False, "unclosed"),
        ("><<>", False, "wrong order"),
        ("<", False, "single open"),
        ("<<<<", False, "all open"),
        (">", False, "single close"),
        ("<<>", False, "unclosed pair"),
        ("<><><<><>><><>", False, "extra close"),
        ("<><><<><>><>>><>", False, "two extra close"),
    ]
    
    passed = failed = 0
    
    for i, (test_str, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{test_str}' -> {exp} ({desc})")
        try:
            if is_seq:
                # Reset for each test
                await reset_dut(dut)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Send characters sequentially
                for idx, ch in enumerate(test_str):
                    last = (idx == len(test_str) - 1)
                    write_char(dut, ch, valid=1, last=1 if last else 0)
                    await RisingEdge(dut.clk)
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value) == 1
                if result != exp:
                    raise TestFailure(f"Expected {exp}, got {result}")
            else:
                # Combinational - single cycle test
                # Pack string into input ports (if they exist as separate signals)
                if has_signal(dut, 'str_data'):
                    # For sequential design, skip comb tests
                    cocotb.log.warning(f"Test {i+1} skipped for seq design")
                    continue
                await Timer(100, units='ns')
                
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")