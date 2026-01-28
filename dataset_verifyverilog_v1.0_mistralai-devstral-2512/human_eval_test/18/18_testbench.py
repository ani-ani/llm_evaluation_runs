import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_LEN = 16
MAX_BITS = 128
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Pack string into 128-bit value (16 chars × 8 bits)
def pack_string(s, max_len=16):
    s = s[:max_len]
    packed = 0
    for i, char in enumerate(s):
        packed |= (ord(char) & 0xFF) << (i * 8)
    return packed

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_how_many_times(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ('', 'x', 0, "empty string"),
        ('xyxyxyx', 'x', 4, "single char repeated"),
        ('cacacacac', 'cac', 4, "multi-char substring"),
        ('john doe', 'john', 1, "word match"),
        ('aaa', 'a', 3, "three chars"),
        ('aaaa', 'aa', 3, "overlapping two-char"),
        ('ababab', 'aba', 2, "overlapping three-char"),
        ('aaaaaa', 'aaa', 4, "longer substring"),
        ('abcabcabc', 'abc', 3, "exact repeats"),
        ('a', 'aa', 0, "shorter than substring"),
        ('', '', 0, "both empty"),
        ('hello world', 'l', 3, "hello world test"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (string, substring, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description} - '{string}' / '{substring}'")
        
        try:
            # Prepare inputs
            string_len = len(string)
            substring_len = len(substring)
            
            if string_len > 16 or substring_len > 16:
                cocotb.log.warning(f"Skipping test {i+1}: length exceeds limit")
                continue
            
            string_packed = pack_string(string, MAX_LEN)
            substring_packed = pack_string(substring, MAX_LEN)
            
            # Assign inputs
            dut.string_data.value = string_packed
            dut.substring_data.value = substring_packed
            dut.string_len.value = string_len
            dut.substring_len.value = substring_len
            
            # Start operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result undefined for test {i+1}")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(
                    f"Test {i+1} failed: expected {expected}, got {result}"
                )
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(10, units='ns')
        
        # Reset for next test
        await reset_dut(dut)
    
    cocotb.log.info(f"\n=== Test Summary ===")
    cocotb.log.info(f"Passed: {passed}/{passed+failed}")
    cocotb.log.info(f"Failed: {failed}/{passed+failed}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info("All tests passed!")
