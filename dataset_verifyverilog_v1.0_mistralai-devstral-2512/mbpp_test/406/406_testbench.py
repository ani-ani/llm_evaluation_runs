import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 100

# Helpers
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def compute_python_parity(x):
    y = x ^ (x >> 1)
    y = y ^ (y >> 2)
    y = y ^ (y >> 4)
    y = y ^ (y >> 8)
    y = y ^ (y >> 16)
    return y & 1

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=50):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_parity_checker(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_num, expected_parity, description)
    test_cases = [
        (12, 0, "12 (1100) - even parity"),
        (7, 1, "7 (0111) - odd parity"),
        (10, 0, "10 (1010) - even parity"),
        (0, 0, "0 - even parity"),
        (65535, 0, "0xFFFF - 16 ones, even parity"),
        (1, 1, "1 (0001) - odd parity"),
        (255, 0, "0xFF - 8 ones, even parity"),
        (256, 1, "0x100 - odd parity")
    ]
    
    passed = 0
    failed = 0
    
    for i, (num, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Compute expected in Python
            expected_calc = compute_python_parity(num)
            if expected != expected_calc:
                cocotb.log.warning(f"Test {i+1}: Expected mismatch - using Python calc")
                expected = expected_calc
            
            # Setup inputs
            dut.start.value = 1
            dut.num.value = clamp_to_width(num, DATA_WIDTH)
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.parity.value):
                raise TestFailure("Parity value undefined")
            
            result = int(dut.parity.value)
            if result != expected:
                raise TestFailure(f"Expected parity {expected}, got {result} for num={num}")
            
            passed += 1
            cocotb.log.info(f"  PASS: num={num}, parity={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Additional test: ensure done pulses only once
    cocotb.log.info("Test: Verify done pulse behavior")
    try:
        dut.start.value = 1
        dut.num.value = 12
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done becomes 1
        await wait_for_done(dut)
        
        # Check done is only high for 1 cycle
        if int(dut.done.value) != 1:
            raise TestFailure("Done not high")
        
        await RisingEdge(dut.clk)
        if int(dut.done.value) == 1:
            raise TestFailure("Done remained high for more than 1 cycle")
            
        passed += 1
        cocotb.log.info("  PASS: done pulse timing")
        
    except TestFailure as e:
        cocotb.log.error(f"  FAIL: {e}")
        failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {len(test_cases)+1} total")