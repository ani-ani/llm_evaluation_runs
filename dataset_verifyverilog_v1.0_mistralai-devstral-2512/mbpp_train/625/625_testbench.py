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

# Global constants
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    dut.arr[0].value = 0  # Just initialize one to ensure structure
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done signal")

@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_swap_list(dut):
    # Setup clock
    if not has_signal(dut, 'clk'):
        # Combinational only
        cocotb.log.info("Module appears combinational, skipping clock/reset")
        is_sequential = False
    else:
        is_sequential = True
        clock = Clock(dut.clk, CLK_NS, units='ns')
        cocotb.start_soon(clock.start())
        await reset_dut(dut)

    # Test cases: (input_list, expected_list, description)
    test_cases = [
        ([1, 2, 3], [3, 2, 1], "Simple 3 elements"),
        ([1, 2, 3, 4, 4], [4, 2, 3, 4, 1], "5 elements with duplicate"),
        ([4, 5, 6], [6, 5, 4], "Another 3 elements"),
        ([10], [10], "Single element (len=1)"),
        ([1, 2, 3, 4, 5, 6, 7, 8], [8, 2, 3, 4, 5, 6, 7, 1], "Max 8 elements")
    ]

    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: {desc}")
        
        # Write input array to DUT
        # Assuming dut.arr is a list of logic vectors or similar
        for idx in range(ARRAY_SIZE):
            val = inp[idx] if idx < len(inp) else 0
            dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
        
        # Write length
        if has_signal(dut, 'len'):
            dut.len.value = len(inp)
        
        if is_sequential:
            # Start operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            try:
                await wait_for_done(dut)
            except TestFailure as e:
                cocotb.log.error(f"Test {i+1} failed: {e}")
                raise TestFailure(f"Test {i+1} failed")
        else:
            # Combinational: add small delay for propagation
            await Timer(10, units='ns')
        
        # Read result array
        result = []
        for idx in range(ARRAY_SIZE):
            val_str = str(dut.result[idx].value)
            if val_str.startswith('x') or val_str.startswith('z'):
                raise TestFailure(f"Result[{idx}] is undefined")
            result.append(int(dut.result[idx].value))
        
        # Verify
        # Only check indices that were part of the original input
        # but the result array might be padded with zeros if we check the whole thing.
        # We'll check the whole array against expected (which pads zeros for indices beyond len if we defined them that way)
        # For this test, let's generate expected full array matching input length.
        full_exp = exp + [0] * (ARRAY_SIZE - len(exp))
        
        for idx in range(ARRAY_SIZE):
            if result[idx] != full_exp[idx]:
                raise TestFailure(f"Test {i+1} failed: result[{idx}] = {result[idx]}, expected {full_exp[idx]}")
        
        cocotb.log.info(f"Test {i+1} passed")
