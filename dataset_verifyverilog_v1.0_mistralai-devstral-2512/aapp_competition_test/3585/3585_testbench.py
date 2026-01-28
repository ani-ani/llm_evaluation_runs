import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
MOD = 998244353
DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 10000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_max_bags_finder(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational module - just set inputs
        await Timer(100, units='ns')
    
    # Test cases: (m, k, expected_result)
    # (2m+1)^k mod 998244353
    test_cases = [
        (2, 1, (2*2 + 1)**1 % MOD),   # 5^1 = 5
        (2, 2, (2*2 + 1)**2 % MOD),   # 5^2 = 25
        (1, 1, (2*1 + 1)**1 % MOD),   # 3^1 = 3
        (1, 2, (2*1 + 1)**2 % MOD),   # 3^2 = 9
        (3, 1, (2*3 + 1)**1 % MOD),   # 7^1 = 7
        (3, 3, (2*3 + 1)**3 % MOD),   # 7^3 = 343
        (10, 5, pow(21, 5, MOD)),     # (21)^5 mod MOD
    ]
    
    passed = failed = 0
    
    for i, (m_val, k_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: m={m_val}, k={k_val}, expected={expected}")
        try:
            # Set inputs
            if has_signal(dut, 'm_in'):
                dut.m_in.value = m_val
            if has_signal(dut, 'k_in'):
                dut.k_in.value = k_val
            
            if is_seq:
                # Start calculation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                result_signal = dut.result if has_signal(dut, 'result') else None
                if result_signal is None:
                    raise TestFailure("Result signal not found")
                
                result_val = safe_int(result_signal.value, 0)
            else:
                # Combinational - result available immediately
                await Timer(10, units='ns')
                result_val = safe_int(dut.result.value, 0)
            
            if result_val != expected:
                raise TestFailure(f"Expected {expected}, got {result_val}")
            
            cocotb.log.info(f"  PASS: Result = {result_val}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")