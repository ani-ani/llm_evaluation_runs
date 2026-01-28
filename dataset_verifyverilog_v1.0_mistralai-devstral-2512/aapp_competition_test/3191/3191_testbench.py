import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def compute_expected(n, r, p):
    """Compute expected result using DP"""
    if n <= 1:
        return 0
    
    T = [0] * (n + 1)
    T[1] = 0
    
    for i in range(2, n + 1):
        min_time = float('inf')
        for k in range(1, i):
            # Split into k and i-k
            time = p + r + max(T[k], T[i - k])
            if time < min_time:
                min_time = time
        T[i] = int(min_time)
    
    return T[n]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_debug_strategies(dut):
    # Setup clock
    dut.rst_n.value = 1
    dut.start.value = 0
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (1, 100, 20, 0, "Single line"),
        (10, 10, 1, 19, "10 lines"),
        (16, 1, 10, 44, "16 lines"),
        (2, 5, 5, 10, "Two lines"),
        (3, 10, 1, 21, "Three lines"),
    ]
    
    passed = failed = 0
    
    for i, (n, r, p, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n}, r={r}, p={p})")
        try:
            # Verify expected result
            expected = compute_expected(n, r, p)
            if expected != exp:
                raise TestFailure(f"Expected calc mismatch: got {expected}, want {exp}")
            
            # Set inputs
            dut.n.value = n
            dut.r.value = r
            dut.p.value = p
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            max_cycles = 5000
            done = False
            for cycle in range(max_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure(f"Timeout after {max_cycles} cycles")
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Passed: result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            # Continue with other tests
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")