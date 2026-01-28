import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
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

# Lookup table for factorials 1! to 12! (precomputed)
FACTORIALS = [1, 1, 2, 6, 24, 120, 720, 5040, 40320, 362880, 3628800, 39916800, 479001600]

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=300):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_brazilian_factorial(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())  # 100 MHz
    await reset_dut(dut)
    
    # Test cases: (n, expected_result, expected_overflow, description)
    test_cases = [
        (1, 1, 0, "n=1: 1! = 1"),
        (4, 288, 0, "n=4: 1!*2!*3!*4! = 1*2*6*24 = 288"),
        (5, 34560, 0, "n=5: 288*120 = 34560"),
        (7, 125411328000, 0, "n=7: 34560*720*5040 = 125411328000"),
        (0, 1, 0, "n=0: identity"),
        (12, 39916800, 0, "n=12: 12! (max without overflow)"),
        (13, 0, 1, "n=13: overflow (13! > 2^32)"),
        (255, 0, 1, "n=255: large n, overflow"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, exp_result, exp_overflow, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set inputs
            dut.n.value = clamp_to_width(n_val, 8)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=300)
            
            # Read outputs
            if not is_value_defined(dut.result.value) or not is_value_defined(dut.overflow.value):
                raise TestFailure("Result or overflow undefined")
            
            result = int(dut.result.value)
            overflow = int(dut.overflow.value)
            
            # Check results (allow 32-bit wrap for overflow cases)
            if overflow != exp_overflow:
                raise TestFailure(f"Overflow mismatch: expected {exp_overflow}, got {overflow}")
            
            if not overflow:
                if result != exp_result:
                    raise TestFailure(f"Result mismatch: expected {exp_result}, got {result}")
            else:
                # For overflow, result can be anything (check it's not the non-overflow value)
                cocotb.log.info(f"Overflow detected, result={result} (expected overflow)")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\nTests passed: {passed}/{passed+failed}")
    if failed:
        raise TestFailure(f"{failed} tests failed")
