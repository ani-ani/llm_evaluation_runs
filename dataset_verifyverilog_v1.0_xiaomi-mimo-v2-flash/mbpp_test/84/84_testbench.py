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
async def test_newman_conway(dut):
    # Setup
    CLK_NS = 10
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (n, expected_result)
    test_cases = [
        (1, 1, "n=1"),
        (2, 1, "n=2"),
        (3, 2, "n=3"),
        (4, 2, "n=4"),
        (10, 6, "n=10")
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set inputs
            if is_seq:
                dut.start.value = 1
                dut.n_in.value = n
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result is undefined (X/Z)")
                
                result = int(dut.result.value)
            else:
                # Combinational - set input and wait
                dut.n_in.value = n
                await Timer(100, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result is undefined (X/Z)")
                result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: n={n} -> {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {desc} - {e}")
            failed += 1
    
    # Report
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")