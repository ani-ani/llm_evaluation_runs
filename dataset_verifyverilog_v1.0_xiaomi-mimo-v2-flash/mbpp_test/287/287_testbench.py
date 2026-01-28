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

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_square_sum(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_n, expected_result)
    test_cases = [
        (2, 20),
        (3, 56),
        (4, 120),
        (10, 1540),  # Additional case
        (63, 342016) # Max case
    ]
    
    for i, (n_in, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running test case {i+1}: n={n_in}, expected={expected}")
        
        # Set input n
        dut.n.value = clamp_to_width(n_in, 6)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result signal is undefined")
            
        result_val = int(dut.result.value)
        if result_val != expected:
            raise TestFailure(f"Test {i+1} failed: n={n_in}. Expected {expected}, got {result_val}")
        
        cocotb.log.info(f"Pass: n={n_in}, result={result_val}")
        
        # Wait one cycle to ensure done de-asserts (optional check)
        await RisingEdge(dut.clk)
        if int(dut.done.value) != 0:
            cocotb.log.warning(f"Test {i+1}: done signal remained high for more than 1 cycle")
    
    # Test Reset behavior during operation
    cocotb.log.info("Testing Reset interruption")
    dut.n.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk) # Let it run a bit
    await reset_dut(dut)
    if int(dut.done.value) != 0 or int(dut.result.value) != 0:
        raise TestFailure("Reset failed to clear done/result signals")
