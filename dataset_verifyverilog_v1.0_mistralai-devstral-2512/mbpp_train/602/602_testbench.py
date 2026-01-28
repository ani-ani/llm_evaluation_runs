import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_first_repeated_char(dut):
    # Setup
    CLK_NS = 10
    DATA_WIDTH = 8
    ARRAY_SIZE = 16
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational needs some settling time
        dut.rst_n.value = 1

    # Helper to set string array
    async def set_string(s):
        # Pack string into 16 chars
        vals = [ord(c) for c in s] + [0] * (16 - len(s))
        # Handle different port styles
        if has_signal(dut, 'str'):
            # Check if it's a single signal (packed) or array
            try:
                # Try accessing as vector
                dut.str.value = 0
                for i in range(16):
                    dut.str[i].value = clamp_to_width(vals[i], DATA_WIDTH)
            except (AttributeError, TypeError):
                # Try individual ports str_0, str_1...
                for i in range(16):
                    try:
                        port = getattr(dut, f'str_{i}')
                        port.value = clamp_to_width(vals[i], DATA_WIDTH)
                    except AttributeError:
                        # Try str[i] syntax if supported
                        try:
                            dut.str[i].value = clamp_to_width(vals[i], DATA_WIDTH)
                        except:
                            raise TestFailure(f"Cannot find port for str[{i}]")

    # Test cases
    test_cases = [
        ("abcabc", ord('a'), "Double 'a'"),
        ("abc", 0, "No repeats"),
        ("123123", ord('1'), "Double '1'"),
        ("zzzz", ord('z'), "All same"),
        ("abca", ord('a'), "Repeat at end"),
    ]

    for i, (s, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input '{s}'")
        try:
            # Set inputs
            await set_string(s)
            if has_signal(dut, 'len'):
                dut.len.value = len(s)
            else:
                # If no length port, maybe fixed length or inferred
                pass

            if is_seq:
                # Trigger
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for result
                await wait_for_done(dut)
            else:
                # Combinational delay
                await Timer(100, units='ns')

            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected} (0x{expected:02X}), got {result} (0x{result:02X})")
            
            cocotb.log.info(f"PASS: Result {result} (0x{result:02X})")

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            raise
