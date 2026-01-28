import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# --- Constants ---
CLK_NS = 10
MAX_CYCLES = 10000  # Large timeout for heavy processing

# --- Helpers ---
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'input_valid'):
        dut.input_valid.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def feed_string(dut, text):
    """Feeds the string character by character over the clock."""
    for char in text:
        dut.input_valid.value = 1
        dut.char_in.value = ord(char)  # ASCII value
        await RisingEdge(dut.clk)
        # De-assert valid if required by interface (assuming backpressure is not implemented for simplicity)
    dut.input_valid.value = 0
    dut.char_in.value = 0
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_goldbach_checker(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic assumed if no clock
        await Timer(10, units='ns')

    # Test Cases
    # Format: (Input String, Expected Result (1 or 0), Description)
    test_cases = [
        ("10 3 7", 1, "Simple valid case"),
        ("10   3   7", 1, "Extra whitespace valid"),
        ("10 3 7\n", 1, "Trailing newline valid"),
        ("314\n159 265\n358", 0, "Three lines (3 tokens but invalid)"),
        ("22 19 3", 1, "Valid primes sum to 22"),
        ("\n\n   60\n  \n  29\n  \n      31\n\t  \n\t  \n", 1, "Scattered whitespace valid"),
        ("fred!\nsam!\ngeorge!", 0, "Invalid characters"),
        ("10 3", 0, "Only two numbers"),
        ("10 3 7 11", 0, "Four numbers"),
        ("4 2 2", 0, "N <= 3 (must be > 3)"),
        ("6 2 3", 0, "3 is prime but 2+3=5 != 6 (check arithmetic)"),
        ("6 2 2", 0, "2+2=4 != 6"),
        ("6 3 3", 1, "3+3=6"),
        ("8 3 5", 1, "3+5=8"),
        ("1000000000 999999937 63", 0, "63 is not prime"),
        ("1000000000 999999937 61", 1, "Large valid (assuming 999999937 is checked prime > 31623)"),
        ("05 3 2", 0, "Leading zero in N"),
        ("10 03 7", 0, "Leading zero in P"),
        ("", 0, "Empty input"),
        ("  10 3 7", 1, "Leading whitespace"),
        ("10 3 7      ", 1, "Trailing whitespace"),
    ]

    passed = 0
    failed = 0

    for i, (inp_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"Input repr: {repr(inp_str)}")
        
        try:
            # Reset before each test to clear state
            if has_signal(dut, 'clk'):
                await reset_dut(dut, cycles=2)
                
            # Start signal if required
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Feed the input
            await feed_string(dut, inp_str)
            
            # Wait for completion
            if has_signal(dut, 'done'):
                await wait_for_done(dut, max_cycles=2000)
            else:
                await Timer(500, units='ns')
            
            # Check Result
            if not has_signal(dut, 'result'):
                raise TestFailure("Module missing 'result' output")
            
            result_val = int(dut.result.value)
            
            # Log details
            cocotb.log.info(f"Expected: {expected}, Got: {result_val}")
            
            if result_val != expected:
                raise TestFailure(f"Result mismatch: expected {expected}, got {result_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
