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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_polite_number(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases: (N, Expected_Polite_Number, Description)
    test_cases = [
        (0, 1, "First polite number (N=0)"),
        (4, 7, "N=4, binary 100 -> 101 (7)"),
        (7, 7, "N=7, binary 111 -> 111 (7)"),
        (9, 11, "N=9, binary 1001 -> 1011 (11)"),
        (10, 11, "N=10, binary 1010 -> 1011 (11)"),
        (100, 101, "N=100, binary 1100100 -> 1100101 (101)"),
        (255, 255, "N=255, binary 11111111 -> 11111111 (255)"),
        (256, 257, "N=256, binary 100000000 -> 100000001 (257)")
    ]

    passed = 0
    failed = 0

    for n_val, expected, desc in test_cases:
        cocotb.log.info(f"Testing {desc}: N={n_val}, Expected={expected}")
        
        # Clamp N to 12 bits just in case
        dut.n.value = clamp_to_width(n_val, 12)
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (or max cycles)
        found_done = False
        for _ in range(5): # Should be done in 1 cycle + latency
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                found_done = True
                break
            await RisingEdge(dut.clk)
        
        if not found_done:
            cocotb.log.error(f"FAIL: Done signal not asserted for N={n_val}")
            failed += 1
            # Reset for next test
            await RisingEdge(dut.clk)
            continue

        # Check result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"FAIL: Result undefined for N={n_val}")
            failed += 1
            continue

        result = int(dut.result.value)
        if result != expected:
            cocotb.log.error(f"FAIL: N={n_val}, Expected {expected}, Got {result}")
            failed += 1
        else:
            passed += 1
        
        # Small wait between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

    if failed > 0:
        raise TestFailure(f"{failed}/{passed + failed} tests failed.")
    else:
        cocotb.log.info(f"All {passed} tests passed.")
