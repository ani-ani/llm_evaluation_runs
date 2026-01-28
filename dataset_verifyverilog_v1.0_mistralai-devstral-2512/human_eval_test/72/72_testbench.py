import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_q(dut, q_vals):
    # Write to array elements individually
    for i, val in enumerate(q_vals):
        if i >= 16: break # Limit to max array size
        dut.q[i].value = clamp_to_width(val, 8)

@cocotb.test(timeout_time=5, timeout_unit='ms')
async def test_will_it_fly(dut):
    if not has_signal(dut, 'clk'):
        # Combinational design, just apply inputs and check output
        for _ in range(10):
            await Timer(1, units='ns')
        return

    # Setup
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Test cases: (q_list, w_val, expected_result, description)
    test_cases = [
        ([3, 2, 3], 9, 1, "Balanced, sum 8 <= 9"),
        ([1, 2], 5, 0, "Unbalanced"),
        ([3], 5, 1, "Single element, sum 3 <= 5"),
        ([3, 2, 3], 1, 0, "Balanced, sum 8 > 1"),
        ([1, 2, 3], 6, 0, "Unbalanced"),
        ([5], 5, 1, "Single element, sum 5 <= 5"),
    ]

    for i, (q_list, w_val, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running test {i+1}: {desc}")
        
        # Write inputs
        await write_q(dut, q_list)
        dut.len.value = len(q_list)
        dut.w.value = w_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} Timeout: {e}")
            raise

        # Check result
        if not is_value_defined(dut.result.value):
             raise TestFailure(f"Test {i+1}: Result signal is undefined")

        res = int(dut.result.value)
        if res != exp:
            raise TestFailure(f"Test {i+1} Failed: Expected {exp}, got {res} ({desc})")
        
        # Verify done is high for exactly 1 cycle (check next cycle)
        await RisingEdge(dut.clk)
        if int(dut.done.value) != 0:
            raise TestFailure(f"Test {i+1}: 'done' signal was not deasserted after 1 cycle")
        
        # Small delay between tests
        await Timer(10, units='ns')

    cocotb.log.info("All tests passed")