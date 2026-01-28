import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Test metadata
CLK_NS = 10
MAX_CYCLES = 2000

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done signal never asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_prime_fib(dut):
    # Check for required signals
    if not has_signal(dut, 'clk'):
        cocotb.log.info("Module is combinatorial (no clk). Running in pure comb mode.")
        is_comb = True
    else:
        is_comb = False
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)

    # Test cases from problem: n -> expected prime_fib(n)
    test_cases = [
        (1, 2),
        (2, 3),
        (3, 5),
        (4, 13),
        (5, 89),
        (6, 233),
        (7, 1597),
        (8, 28657),
        (9, 514229),
        (10, 433494437)
    ]

    passed = 0
    failed = 0

    for i, (n, expected) in enumerate(test_cases):
        desc = f"n={n} -> {expected}"
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Set input n
            if has_signal(dut, 'n'):
                dut.n.value = n
            
            # Trigger calculation
            if not is_comb:
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                else:
                    await RisingEdge(dut.clk) # Just wait for pipeline
                
                await wait_for_done(dut)
            else:
                # Combinatorial: just wait a bit for propagation
                await Timer(100, units='ns')

            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("No 'result' signal found")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined (X)")

            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")

    cocotb.log.info(f"All {passed} tests passed!")