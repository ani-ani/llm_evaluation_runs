import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_bell_number(dut):
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Known Bell numbers for N=0 to 8
    bell_vals = [1, 1, 2, 5, 15, 52, 203, 877, 41402]
    
    passed = 0
    failed = 0
    
    for n in range(9):
        exp = bell_vals[n]
        cocotb.log.info(f"Testing n={n}, expected {exp}")
        
        # Start computation
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        done = False
        for _ in range(500):  # Max cycles based on prompt
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            cocotb.log.error(f"FAIL: n={n} - Timeout waiting for done")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"FAIL: n={n} - Result undefined")
            failed += 1
            continue
            
        result = int(dut.result.value)
        if result != exp:
            cocotb.log.error(f"FAIL: n={n} - Expected {exp}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"PASS: n={n} - Result {result}")
            passed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")