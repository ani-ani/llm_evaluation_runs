import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 4  # BCD
MAX_LEN = 32
CLK_NS = 10
MAX_CYCLES = 2000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def string_to_packed_array(s):
    """Converts a string of digits to a packed 128-bit integer (32 nibbles)."""
    val = 0
    for i, char in enumerate(s):
        if i >= MAX_LEN:
            break
        digit = int(char)
        val |= (digit << (i * DATA_WIDTH))
    return val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_max_palindrome_partition(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - just set inputs
        pass

    # Test cases (Input String, Expected Result)
    test_cases = [
        ("652526", 4),
        ("12121131221", 7),
        ("123456789", 1),
        ("132594414896459441321", 9),
        ("1111", 4),
        ("12321", 3),
        ("1", 1)
    ]

    passed = 0
    failed = 0

    for s_in, expected in test_cases:
        cocotb.log.info(f"Testing input: '{s_in}' expecting {expected}")
        
        # Prepare inputs
        packed_s = string_to_packed_array(s_in)
        length = len(s_in)

        # Apply inputs
        dut.s.value = packed_s
        dut.len.value = length

        if is_seq:
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            try:
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal is undefined")
                
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                
                passed += 1
            except TestFailure as e:
                cocotb.log.error(f"FAIL for '{s_in}': {e}")
                failed += 1
        else:
            # Combinational check
            await Timer(10, units='ns')
            result = int(dut.result.value)
            if result != expected:
                cocotb.log.error(f"FAIL Combinational: Expected {expected}, got {result}")
                failed += 1
            else:
                passed += 1

    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed successfully")
