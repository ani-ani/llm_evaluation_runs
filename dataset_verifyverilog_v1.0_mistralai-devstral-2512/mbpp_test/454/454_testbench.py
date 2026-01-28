import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 200

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

def to_ascii(s):
    return [ord(c) for c in s]

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_text_match_wordz(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ("pythonz.", True, "Test 1: 'pythonz.' contains 'z' in word"),
        ("xyz.", True, "Test 2: 'xyz.' contains 'z' in word"),
        ("  lang  .", False, "Test 3: '  lang  .' no 'z' in word")
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write string to DUT
            chars = to_ascii(test_str)
            length = len(chars)
            
            # Clamp and write each character to array
            for j in range(ARRAY_SIZE):
                if j < length:
                    val = clamp_to_width(chars[j], DATA_WIDTH)
                    dut.str[j].value = val
                else:
                    dut.str[j].value = 0
            
            # Set length
            dut.len.value = clamp_to_width(length, 5)
            
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != (1 if expected else 0):
                raise TestFailure(f"Expected result={1 if expected else 0}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Result={result}")
            
            # Small delay between tests
            await Timer(10, units='ns')
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Check for any X/Z values in critical signals
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    # Additional edge case: empty string
    cocotb.log.info("Test 4: Empty string")
    try:
        for j in range(ARRAY_SIZE):
            dut.str[j].value = 0
        dut.len.value = 0
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        if is_value_defined(dut.result.value) and int(dut.result.value) != 0:
            raise TestFailure(f"Empty string should return 0, got {int(dut.result.value)}")
        passed += 1
        cocotb.log.info("  PASS: Empty string handled")
    except TestFailure as e:
        cocotb.log.error(f"  FAIL: {e}")
        failed += 1
    
    if failed:
        raise TestFailure(f"Total {failed} tests failed")
    cocotb.log.info(f"All {passed} tests passed")