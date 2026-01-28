import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Precompute expected values for N=1 to 8 in Q16.16 format
def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

EXPECTED = {
    1: float_to_fixed(1.0),
    2: float_to_fixed(2.666666666667),
    3: float_to_fixed(4.444444444444),
    4: float_to_fixed(6.296296296296),
    5: float_to_fixed(8.204940711462),
    6: float_to_fixed(10.156721462401),
    7: float_to_fixed(12.144404406112),
    8: float_to_fixed(14.156721462401)
}

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    dut.clk.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_memory_expected(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    passed = 0
    failed = 0

    # Test cases for N = 1 to 8
    test_values = list(range(1, 9))

    for n in test_values:
        cocotb.log.info(f"Testing N={n}")
        try:
            # Set input
            dut.n.value = n
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0

            # Wait for done
            timeout_cycles = 200
            found_done = False
            for _ in range(timeout_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    found_done = True
                    break
            
            if not found_done:
                raise TestFailure(f"Timeout waiting for done signal for N={n}")

            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            expected = EXPECTED[n]
            
            # Allow small error for fixed-point calculation
            error = abs(result - expected)
            if error > 10: # tolerance
                res_float = result / 65536.0
                exp_float = expected / 65536.0
                raise TestFailure(f"N={n}: Expected {exp_float:.6f}, got {res_float:.6f}")
            
            passed += 1
            cocotb.log.info(f"PASS: N={n} Result={result} (Expected={expected})")

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)

    if failed:
        raise TestFailure(f"{failed} tests failed")