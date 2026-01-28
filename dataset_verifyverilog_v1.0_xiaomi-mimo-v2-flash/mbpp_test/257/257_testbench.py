import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_swap_numbers(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    test_cases = [
        (10, 20, 20, 10, "Test 1: swap 10,20"),
        (15, 17, 17, 15, "Test 2: swap 15,17"),
        (100, 200, 200, 100, "Test 3: swap 100,200"),
        (0, 255, 255, 0, "Test 4: swap 0,255"),
        (255, 0, 0, 255, "Test 5: swap 255,0"),
    ]
    
    for i, (a_in, b_in, exp_a, exp_b, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running {desc}")
        
        # Ensure we're in IDLE state
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            await RisingEdge(dut.clk)
        
        # Set inputs (they can be asynchronous, but stable before start)
        dut.a.value = clamp_to_width(a_in, DATA_WIDTH)
        dut.b.value = clamp_to_width(b_in, DATA_WIDTH)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read outputs
        if not is_value_defined(dut.result_a.value):
            raise TestFailure(f"result_a undefined for case {i+1}")
        if not is_value_defined(dut.result_b.value):
            raise TestFailure(f"result_b undefined for case {i+1}")
            
        got_a = int(dut.result_a.value)
        got_b = int(dut.result_b.value)
        
        cocotb.log.info(f"  Input a={a_in}, b={b_in} -> Got result_a={got_a}, result_b={got_b}")
        
        if got_a != exp_a:
            raise TestFailure(f"result_a mismatch for {desc}: expected {exp_a}, got {got_a}")
        if got_b != exp_b:
            raise TestFailure(f"result_b mismatch for {desc}: expected {exp_b}, got {got_b}")
        
        # Verify done pulse is single cycle
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            raise TestFailure(f"Done signal stayed high for more than 1 cycle after case {i+1}")
        
        cocotb.log.info(f"  Passed {desc}")
    
    cocotb.log.info("All swap tests passed!")