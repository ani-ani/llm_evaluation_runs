import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
FIXED_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_truncate_number(dut):
    # Check if it's a sequential module
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (3.5, "3.5 decimal part should be ~0.5"),
        (1.33, "1.33 decimal part should be ~0.33"),
        (123.456, "123.456 decimal part should be ~0.456")
    ]
    
    passed = 0
    failed = 0
    
    for test_num, (test_float, description) in enumerate(test_cases, 1):
        cocotb.log.info(f"Test {test_num}: {description}")
        
        # Convert float to fixed-point Q16.16
        fixed_input = float_to_fixed(test_float)
        # Expected fractional part (lower 16 bits) scaled by 65536
        expected = int((test_float - int(test_float)) * 65536) & 0xFFFF
        
        try:
            # Set inputs
            if is_seq:
                dut.fixed_in.value = fixed_input
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
            else:
                # Combinational
                dut.fixed_in.value = fixed_input
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # Check result within tolerance
            diff = abs(result - expected)
            if diff > 1:  # Allow 1 unit rounding difference
                raise TestFailure(f"Expected {expected} (0x{expected:04X}), got {result} (0x{result:04X})")
            
            cocotb.log.info(f"  Result: {result} (0x{result:04X}), Expected: {expected} (0x{expected:04X})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {test_num} - {e}")
            failed += 1
    
    # Additional test: verify integer part is ignored
    # For 3.5, output should be fractional part only, not 3
    if failed == 0:
        cocotb.log.info("All tests passed!")
    else:
        raise TestFailure(f"{failed} tests failed")