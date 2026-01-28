import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 6
MAX_N = 16
CLK_NS = 10
MAX_CYCLES = 500
MOD = 1000000007

# Helper functions from specification
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_box_pile(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        (3, [2,6,8], 2),
        (5, [2,3,4,9,12], 4),
        (4, [5,7,2,9], 1)
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (n, vals, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: n={n}, vals={vals}")
        
        try:
            # Reset for each test
            await reset_dut(dut)
            
            # Check ready signal
            if has_signal(dut, 'ready'):
                if not is_value_defined(dut.ready.value) or int(dut.ready.value) != 1:
                    raise TestFailure("Module not ready after reset")
            
            # Input phase: write n and values
            if has_signal(dut, 'n'):
                dut.n.value = n
            
            # Write array values (simplified interface - write all at once for simulation)
            # In hardware: write one value per cycle with addr
            for i, val in enumerate(vals):
                if has_signal(dut, 'data') and has_signal(dut, 'addr'):
                    dut.data.value = clamp_to_width(val, DATA_WIDTH)
                    dut.addr.value = i
                    await RisingEdge(dut.clk)
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value) % MOD
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")