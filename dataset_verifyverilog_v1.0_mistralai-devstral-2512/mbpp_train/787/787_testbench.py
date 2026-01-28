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

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 1000

def ascii_val(c):
    return ord(c)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_string(dut, s):
    for i, c in enumerate(s):
        val = ascii_val(c)
        # Access as array of signals arr[i]
        if hasattr(dut, 'input_str'):
            dut.input_str[i].value = clamp_to_width(val, DATA_WIDTH)
        # Also handle potential named ports input_str_0, input_str_1...
        elif hasattr(dut, f'input_str_{i}'):
            getattr(dut, f'input_str_{i}').value = clamp_to_width(val, DATA_WIDTH)
    # Set len
    if hasattr(dut, 'str_len'):
        dut.str_len.value = len(s)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_pattern_matcher(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational version - no clock
        pass
    
    # Test cases: (input_string, expected_found, description)
    test_cases = [
        ("ac", False, "No pattern"),
        ("dc", False, "No pattern start"),
        ("abbbba", True, "Pattern in middle"),
        ("caacabbbba", True, "Pattern later in string"),
        ("abbb", True, "Exact pattern"),
        ("abbbb", True, "Longer sequence contains pattern"),
        ("abcb", False, "Wrong middle char"),
        ("baaa", False, "Wrong order"),
        ("aaabbb", False, "Wrong count"),
        ("", False, "Empty string"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp_str, exp_found, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: '{inp_str}'")
        try:
            if is_seq:
                await write_string(dut, inp_str)
                
                # Start processing
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read results
                if not is_value_defined(dut.found.value):
                    raise TestFailure("Result 'found' undefined")
                    
                result = int(dut.found.value)
                expected = 1 if exp_found else 0
                
                if result != expected:
                    raise TestFailure(f"Expected found={expected}, got {result}")
                else:
                    passed += 1
            else:
                # Combinational
                await write_string(dut, inp_str)
                await Timer(50, units='ns')
                
                if not is_value_defined(dut.found.value):
                    raise TestFailure("Result 'found' undefined")
                    
                result = int(dut.found.value)
                expected = 1 if exp_found else 0
                
                if result != expected:
                    raise TestFailure(f"Expected found={expected}, got {result}")
                else:
                    passed += 1
                    
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Tests: Passed={passed}, Failed={failed}")
    if failed:
        raise TestFailure(f"{failed} tests failed")