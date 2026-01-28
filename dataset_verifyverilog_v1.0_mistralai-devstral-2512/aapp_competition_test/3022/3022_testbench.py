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

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cookie_distribution(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)

    # Test cases scaled to 10-bit inputs
    # Original inputs: N, A, B, C
    # Scaled logic: 
    # Case 1: 2 3 3 3 -> S=9, M=3, Rem=6. M <= Rem -> Result=9
    # Case 2: 10 20 0 0 -> S=20, M=20, Rem=0. M > Rem+10? 20 > 10? Yes. Result=0*2+10=10
    # Case 3: 100 20 543 12 -> S=575, M=543, Rem=32. M > Rem+100? 543 > 132? Yes. Result=32*2+100=164
    # Case 4: Large -> scaled down for simulation (e.g., N=1000, A=1000, B=1000, C=1000)

    test_cases = [
        # (N, A, B, C, Expected Result)
        (2, 3, 3, 3, 9),
        (10, 20, 0, 0, 10),
        (100, 20, 543, 12, 164),
        (1000, 1000, 1000, 1000, 3000),
        (10, 5, 5, 0, 10),  # Edge case: M=5, Rem=5, N=10. M <= Rem+N (5 <= 15). Result=10.
        (5, 10, 0, 0, 5),   # Edge case: M=10, Rem=0, N=5. M > Rem+N (10 > 5). Result=5.
    ]

    passed = 0
    failed = 0

    for i, (n, a, b, c, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: N={n}, A={a}, B={b}, C={c}")
        
        try:
            # Write inputs (assuming 10-bit width for A, B, C, N)
            dut.N.value = clamp_to_width(n, 10)
            dut.A.value = clamp_to_width(a, 10)
            dut.B.value = clamp_to_width(b, 10)
            dut.C.value = clamp_to_width(c, 10)

            # Start sequence
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0

            # Wait for done
            await wait_for_done(dut)

            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result = int(dut.result.value)
            
            # Check result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"Test {i+1} Passed")

        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
        
        # Small delay between tests
        await RisingEdge(dut.clk)

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
