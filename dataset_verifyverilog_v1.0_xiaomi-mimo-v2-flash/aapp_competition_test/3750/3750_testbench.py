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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=20):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def clamp_32(v):
    return v & 0xFFFFFFFF

def is_negative_32(v):
    return (v & 0x80000000) != 0

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_table_tennis(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (k, a, b, expected_result)
    # Note: -1 is represented as 32'hFFFFFFFF
    test_cases = [
        (11, 11, 5, 1),     # Example 1
        (11, 2, 3, -1),     # Example 2
        (1, 5, 9, 14),
        (2, 3, 3, 2),
        (1, 1000000000, 1000000000, 2000000000),
        (2, 3, 5, 3),
        (1000000000, 1000000000, 1000000000, 2),
        (1, 0, 1, 1),
        (101, 99, 97, -1),
        (1000000000, 0, 1, -1),
        (137, 137, 136, 1),
        (255, 255, 255, 2),
        (1, 0, 1000000000, 1000000000),
        (123, 456, 789, 9),
        (666666, 6666666, 666665, -1),
    ]
    
    passed = 0
    failed = 0
    
    for i, (k, a, b, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: k={k}, a={a}, b={b}")
        
        # Drive inputs
        dut.k.value = k
        dut.a.value = a
        dut.b.value = b
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
                
            result_val = int(dut.result.value)
            
            # Check if result matches expected
            if expected == -1:
                # Check for 32-bit -1 (0xFFFFFFFF)
                if result_val != 0xFFFFFFFF:
                    raise TestFailure(f"Expected -1 (0xFFFFFFFF), got {result_val:#x}")
            else:
                if result_val != expected:
                    raise TestFailure(f"Expected {expected}, got {result_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
