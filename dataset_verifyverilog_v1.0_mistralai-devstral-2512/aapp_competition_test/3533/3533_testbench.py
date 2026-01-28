import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 16
NUM_MAX = 16
CLK_NS = 10
MAX_CYCLES = 500

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_min_toll(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test cases: (entrances, exits, expected_result, description)
    test_cases = [
        ([3, 45, 60], [65, 10, 25], 32, "Sample 1"),
        ([5, 6, 8], [7, 8, 5], 5, "Sample 2"),
        ([100, 200], [150, 250], 100, "Two trucks"),
        ([50], [60], 10, "Single truck"),
        ([1, 2, 3, 4], [4, 3, 2, 1], 6, "Reverse pairs")
    ]

    passed = 0
    failed = 0

    for i, (entrances, exits, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            n = len(entrances)
            
            # Clamp values to DATA_WIDTH (16 bits)
            entrances_clamped = [clamp_to_width(e, DATA_WIDTH) for e in entrances]
            exits_clamped = [clamp_to_width(e, DATA_WIDTH) for e in exits]

            # Write inputs: Handle array access correctly
            # Assuming module has inputs: entrance_i[0..15], exit_i[0..15]
            for idx in range(NUM_MAX):
                e_val = entrances_clamped[idx] if idx < n else 0
                x_val = exits_clamped[idx] if idx < n else 0
                
                # Access array elements by name
                dut.entrance_i[idx].value = e_val
                dut.exit_i[idx].value = x_val
            
            # Set num_trucks
            dut.num_trucks.value = n
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
            # Prepare for next test
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1} - {desc}): {e}")
            failed += 1
            await reset_dut(dut)

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
