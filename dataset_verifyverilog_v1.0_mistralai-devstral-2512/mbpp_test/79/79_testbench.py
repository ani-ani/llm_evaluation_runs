import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

async def wait_for_done(dut, max_cycles=1000):
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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_word_len(dut):
    CLK_NS = 10
    MAX_CYCLES = 100
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Helper to send string and check result
    async def send_and_check(string, expected_result):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Send characters
        for char in string:
            dut.char_in.value = ord(char)
            await RisingEdge(dut.clk)
        
        # Send null terminator
        dut.char_in.value = 0
        await RisingEdge(dut.clk)
        
        # Wait for done
        await wait_for_done(dut, max_cycles=MAX_CYCLES)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal undefined")
        result = int(dut.result.value)
        if result != expected_result:
            raise TestFailure(f"Expected {expected_result}, got {result}")
        
        # Return to idle
        dut.char_in.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    test_cases = [
        ("Hadoop", 0, "6 chars, even"),
        ("great", 1, "5 chars, odd"),
        ("structure", 1, "9 chars, odd"),
        ("a", 1, "1 char, odd"),
        ("ab", 0, "2 chars, even"),
        ("hello world", 1, "First word 'hello', 5 chars odd"),
        ("test case", 0, "First word 'test', 4 chars even"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (string, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            await send_and_check(string, exp)
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            # Reset between failures
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")