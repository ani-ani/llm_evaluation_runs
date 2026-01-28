import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_card_game(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (d, g, n, k, expected_result)
    test_cases = [
        (2, 10, 3, 2, 4),
        (10, 10, 5, 0, 10),
        (1, 1000, 10, 9, 1)
    ]
    
    for i, (d_init, g_init, n, k, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: d={d_init}, g={g_init}, n={n}, k={k}")
        
        # Set inputs
        dut.d_init.value = clamp_to_width(d_init, 10)
        dut.g_init.value = clamp_to_width(g_init, 10)
        dut.n.value = clamp_to_width(n, 6)
        dut.k.value = clamp_to_width(k, 6)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f"Timeout in test {i+1}: {e}")
            raise
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined in test {i+1}")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {i+1} passed: result={result}")
        
        # Small delay between tests
        await Timer(100, units='ns')
