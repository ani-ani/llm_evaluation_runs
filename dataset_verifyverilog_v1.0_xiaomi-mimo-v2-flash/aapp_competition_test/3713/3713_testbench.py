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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_alt_subseq(dut):
    # Setup clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational path (fallback, though spec says sequential)
        await Timer(10, units='ns')

    # Test cases derived from Python solutions
    # Input format: (n, binary_string, expected_result)
    test_cases = [
        (8, "10000011", 5),
        (2, "01", 2),
        (5, "10101", 5),
        (75, "01" * 37 + "0", 75), # Very long alternating, n=75 -> cap at 75
        (11, "00000000000", 3), # All same, flip ends up 010... or 101...
        (5, "01000", 5),
        (1, "0", 1),
        (1, "1", 1),
        (4, "0101", 4),
        (3, "000", 3),
    ]

    passed = 0
    failed = 0

    for n, s_bin, exp in test_cases:
        cocotb.log.info(f"Testing n={n}, s='{s_bin}', exp={exp}")
        
        # Prepare inputs
        data_val = 0
        for i, char in enumerate(s_bin):
            if char == '1':
                data_val |= (1 << i)
        
        if has_signal(dut, 'clk'):
            # Sequential Logic
            dut.n.value = n
            dut.data.value = data_val
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            found_done = False
            for _ in range(200): # Max cycles tolerance
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    found_done = True
                    break
            
            if not found_done:
                cocotb.log.error(f"Timeout waiting for done on case n={n}")
                failed += 1
                continue
        else:
            # Combinational Logic (if applicable)
            dut.n.value = n
            dut.data.value = data_val
            await Timer(10, units='ns')

        # Check result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Result undefined for n={n}")
            failed += 1
            continue

        result = int(dut.result.value)
        if result != exp:
            cocotb.log.error(f"FAIL: n={n}, s='{s_bin}'. Expected {exp}, got {result}")
            failed += 1
        else:
            passed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
