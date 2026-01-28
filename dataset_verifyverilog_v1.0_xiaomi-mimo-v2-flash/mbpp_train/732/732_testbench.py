import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Include helper functions from prompt
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
ARRAY_SIZE = 16  # Fixed array size as per spec

# Helper to convert string to list of ASCII ints
def str_to_ascii(s):
    return [ord(c) for c in s]

# Helper to write input string to DUT
def write_input_string(dut, chars):
    for i, ascii_val in enumerate(chars):
        dut.input_str[i].value = clamp_to_width(ascii_val, DATA_WIDTH)

# Helper to read output string from DUT
def read_output_string(dut, length):
    result = []
    for i in range(length):
        if is_value_defined(dut.output_str[i].value):
            result.append(int(dut.output_str[i].value))
        else:
            # If undefined, treat as 0 or raise error
            raise TestFailure(f"Output at index {i} is undefined")
    return result

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_replace_specialchar(dut):
    # Setup clock if it exists
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic - just wait
        await Timer(100, units='ns')

    # Test cases mapping: (input_string, expected_output_string, description)
    test_cases = [
        ("Python language, Programming language.", "Python:language::Programming:language:", "Case 1: Comma and dot"),
        ("a b c,d e f", "a:b:c:d:e:f", "Case 2: Spaces and comma"),
        ("ram reshma,ram rahim", "ram:reshma:ram:rahim", "Case 3: Comma only"),
        ("", "", "Case 4: Empty string"),
        ("normal text", "normal:text", "Case 5: Single space"),
        ("end.", "end:", "Case 6: Dot at end"),
        ("a.b,c d", "a:b:c:d", "Case 7: Mixed delimiters"),
    ]

    passed = 0
    failed = 0

    for idx, (inp_str, exp_str, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {idx + 1}: {desc}")
        try:
            # Prepare inputs
            inp_ascii = str_to_ascii(inp_str)
            length = len(inp_ascii)
            
            # Check if DUT has length port
            if has_signal(dut, 'length'):
                dut.length.value = clamp_to_width(length, 4)  # 4-bit length
            
            # Write input string
            write_input_string(dut, inp_ascii)
            
            # Start processing
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, MAX_CYCLES)
                
                # Read output
                result_ascii = read_output_string(dut, length)
            else:
                # Combinational module
                await Timer(100, units='ns')
                result_ascii = read_output_string(dut, length)
            
            # Convert to string for comparison
            result_str = "".join(chr(c) for c in result_ascii)
            
            if result_str != exp_str:
                raise TestFailure(f"Expected '{exp_str}', got '{result_str}'")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")

        except TestFailure as e:
            cocotb.log.error(f"FAIL in Test {idx + 1}: {desc} - {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')

    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
