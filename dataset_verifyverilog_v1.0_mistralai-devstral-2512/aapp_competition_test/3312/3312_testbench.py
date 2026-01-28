import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
MAX_CANS = 8
MAX_TIME = 32
GRID_SIZE = 16
MAX_ENERGY = 8
DATA_WIDTH = 8
CLK_NS = 10

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'can_write'): dut.can_write.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_johnny5(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational, assume it settles in 100ns
        await Timer(100, units='ns')

    # Test cases: (N, E, Sx, Sy, C, cans, expected_score)
    # cans: list of (X, Y, CT)
    test_cases = [
        (3, 1, 0, 0, 2, [(1, 2, 2), (1, 1, 1)], 0),
        (3, 1, 1, 1, 8, [(0, 1, 1), (1, 0, 1), (2, 1, 1), (1, 2, 1), (1, 2, 2), (2, 2, 3), (0, 2, 5), (1, 2, 6)], 4),
        (3, 1, 0, 0, 1, [(1, 0, 100)], 1)
    ]

    passed = 0
    failed = 0

    for i, (N, E, Sx, Sy, C, cans, exp_score) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={N}, E={E}, Start=({Sx},{Sy}), C={C}")
        try:
            if is_seq:
                await reset_dut(dut)
                # Load parameters
                dut.grid_size.value = N
                dut.start_energy.value = E
                dut.start_x.value = Sx
                dut.start_y.value = Sy
                dut.can_count.value = C
                await RisingEdge(dut.clk)

                # Load cans
                for idx, (cx, cy, ct) in enumerate(cans):
                    dut.can_x_in.value = cx
                    dut.can_y_in.value = cy
                    dut.can_time_in.value = ct
                    dut.can_write.value = 1
                    await RisingEdge(dut.clk)
                dut.can_write.value = 0

                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                await wait_for_done(dut)
                
                result = int(dut.result.value)
            else:
                # Combinational logic (simplified for this example)
                # Setting inputs
                dut.grid_size.value = N
                dut.start_energy.value = E
                dut.start_x.value = Sx
                dut.start_y.value = Sy
                dut.can_count.value = C
                
                # Note: For strictly comb, we might need to handle can array differently
                # Assuming a packed interface or similar for test simplicity
                # For this specific problem, sequential is expected for DP
                raise TestFailure("Testbench optimized for sequential DP logic")

            if result != exp_score:
                raise TestFailure(f"Expected {exp_score}, got {result}")
            passed += 1
            cocotb.log.info(f"PASS: Score {result}")

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")
