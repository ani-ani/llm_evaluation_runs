import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def wait_for_done_condition(dut, max_cycles=100):
    for _ in range(max_cycles):
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sum_to_n(dut):
    # Setup
    CLK_NS = 10
    MAX_CYCLES = 100
    
    # Check for required signals
    signals = ['clk', 'rst_n', 'start', 'n_in', 'result', 'done']
    for sig in signals:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing required signal: {sig}")
    
    # Start clock
    clock = Clock(dut.clk, CLK_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    # Test cases: (n, expected_sum)
    test_cases = [
        (1, 1),
        (5, 15),
        (6, 21),
        (10, 55),
        (11, 66),
        (30, 465),
        (100, 5050)
    ]
    
    # Helper to reset DUT
    async def reset_dut(dut):
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Reset initially
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for n, exp in test_cases:
        cocotb.log.info(f"Test: n={n}, expected sum={exp}")
        try:
            # Set n_in (8-bit)
            dut.n_in.value = clamp_to_width(n, 8)
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done with timeout
            if not wait_for_done_condition(dut, MAX_CYCLES):
                raise TestFailure(f"Done signal not asserted within {MAX_CYCLES} cycles")
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: n={n}, result={result}")
            
            # Wait for done to go low (optional, but good for next test)
            await RisingEdge(dut.clk)
            if int(dut.done.value) != 0:
                cocotb.log.warning("Done signal did not deassert after 1 cycle")
                # Give it another cycle
                await RisingEdge(dut.clk)
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed.")
    
    cocotb.log.info(f"All {passed} tests passed.")
