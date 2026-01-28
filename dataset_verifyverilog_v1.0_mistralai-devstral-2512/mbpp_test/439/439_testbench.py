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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# Constants
DATA_WIDTH = 8
RESULT_WIDTH = 32
MAX_LEN = 8
CLK_NS = 10

def python_multiple_to_single(L):
    # Direct Python implementation from problem statement
    x = int("".join(map(str, L)))
    return x

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def set_input_array(dut, values, length):
    if has_signal(dut, 'input_integers'):
        # Assuming it's a bus array like [7:0] input_integers [0:7]
        # Access might vary based on tool, but usually dut.input_integers[i] works
        for i in range(MAX_LEN):
            if i < length:
                val = values[i]
                # Handle signed extension for 8-bit input
                # dut.input_integers expects 8-bit values
                dut.input_integers[i].value = clamp_to_width(val if val >= 0 else (1 << DATA_WIDTH) + val, DATA_WIDTH)
            else:
                dut.input_integers[i].value = 0
    else:
        # Fallback for individual ports if generated as dut.input_integers_0, dut.input_integers_1...
        for i in range(MAX_LEN):
            port_name = f'input_integers_{i}'
            if has_signal(dut, port_name):
                if i < length:
                    val = values[i]
                    getattr(dut, port_name).value = clamp_to_width(val if val >= 0 else (1 << DATA_WIDTH) + val, DATA_WIDTH)
                else:
                    getattr(dut, port_name).value = 0
    
    if has_signal(dut, 'len'):
        dut.len.value = length

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_multiple_to_single(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational circuit assumption
        await Timer(100, units='ns')

    test_cases = [
        ([11, 33, 50], 113350, "Positive 2-digit numbers"),
        ([-1, 2, 3, 4, 5, 6], -123456, "Negative start, 1-digit then 2-digits"),
        ([10, 15, 20, 25], 10152025, "All positive 2-digit numbers"),
        ([99, 99, 99, 99, 99, 99, 99, 99], 9999999999999999, "Max 8 numbers, 16 digits (approx)"),
        ([5, 10], 510, "Mixed 1 and 2 digits")
    ]

    passed = 0
    failed = 0

    for i, (inputs, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Inputs: {inputs}")
        
        # Set inputs
        await set_input_array(dut, inputs, len(inputs))

        if has_signal(dut, 'clk'):
            # Sequential
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            try:
                await wait_for_done(dut, 50)
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal is undefined")
                
                result = int(dut.result.value)
                
                # Convert result from unsigned to signed (32-bit)
                if result >= (1 << (RESULT_WIDTH - 1)):
                    result = result - (1 << RESULT_WIDTH)
                
                if result != expected:
                    # Allow for overflow limitations in 32-bit for very large numbers
                    # 99... (16 digits) is 10^16-1, which is larger than 2^31-1
                    # The test case 999... might overflow 32-bit signed. 
                    # Python int handles arbitrary precision, Verilog 32-bit does not.
                    # We will check if the expected value fits in 32-bit signed.
                    if abs(expected) >= (1 << 31):
                        cocotb.log.warning(f"Expected {expected} exceeds 32-bit signed range. Clamping check.")
                        # Check if we matched the truncated value
                        trunc_exp = expected - (1 << 32) if expected < 0 else expected
                        trunc_exp = trunc_exp & ((1 << 32) - 1)
                        if result != (trunc_exp if trunc_exp < (1<<31) else trunc_exp - (1<<32)):
                            raise TestFailure(f"Expected {expected} (truncated {trunc_exp}), got {result}")
                    else:
                        raise TestFailure(f"Expected {expected}, got {result}")
                passed += 1
            except TestFailure as e:
                cocotb.log.error(f"FAIL: {e}")
                failed += 1
        else:
            # Combinational
            await Timer(50, units='ns')
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            result = int(dut.result.value)
            if result >= (1 << (RESULT_WIDTH - 1)):
                result = result - (1 << RESULT_WIDTH)
            if result != expected:
                 raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
