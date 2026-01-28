import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 16
MOD = 1000000007
CLK_NS = 10
MAX_CYCLES = 256
ARRAY_SIZE = 512  # Max array size for DP

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_signed(val, bits):
    if val >= (1 << (bits-1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_coin_ways(dut):
    # Setup clock
    is_sequential = has_signal(dut, 'clk')
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    if is_sequential:
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases from problem
    test_cases = [
        # (n, a_list, b_list, m, expected_result)
        (1, [], [4], 2, 1),
        (2, [1], [4, 4], 2, 3),
        (3, [3, 3], [10, 10, 10], 17, 6),
        (2, [2], [200000, 100000], 34567, 17284),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (n, a_list, b_list, m, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: n={n}, m={m}, expected={expected}")
        
        try:
            # Scale inputs for hardware
            # For simplicity, we'll use scaled values where possible
            # In real hardware, we'd need more sophisticated scaling
            # Here we simulate the algorithm in Python to verify HDL
            
            # Python reference implementation
            p = MOD
            d = [1] * ARRAY_SIZE
            td = [0] * ARRAY_SIZE
            L = b_list[0]
            m_scaled = m  # In actual hardware, this would be pre-scaled
            
            for i in range(1, n):
                if i-1 < len(a_list) and a_list[i-1] != 1:
                    t = m_scaled % a_list[i-1]
                    if L < t:
                        expected_result = 0
                        break
                    m_scaled = m_scaled // a_list[i-1]
                    # Stride operation
                    new_L = (L - t) // a_list[i-1]
                    for j in range(new_L + 1):
                        d[j] = d[t + j * a_list[i-1]]
                    L = new_L
                
                # Prefix sum with sliding window
                k = 0
                new_L = L + b_list[i]
                for j in range(new_L + 1):
                    if j <= L:
                        k = (k + d[j]) % p
                    td[j] = k
                    if j >= b_list[i]:
                        k = (k - d[j - b_list[i]] + p) % p
                
                # Swap
                L = new_L
                d, td = td, d
            
            if m_scaled <= L and m_scaled >= 0:
                expected_result = d[m_scaled]
            else:
                expected_result = 0
            
            # Now test HDL
            # Set inputs
            if is_sequential:
                # Set b array (10 elements max)
                for i in range(min(10, len(b_list))):
                    if has_signal(dut, f'b_{i}'):
                        getattr(dut, f'b_{i}').value = clamp_to_width(b_list[i], 16)
                    elif has_signal(dut, 'b'):
                        # Try array access
                        try:
                            dut.b[i].value = clamp_to_width(b_list[i], 16)
                        except:
                            pass
                
                # Set a array (9 elements max)
                for i in range(min(9, len(a_list))):
                    if has_signal(dut, f'a_{i}'):
                        getattr(dut, f'a_{i}').value = clamp_to_width(a_list[i], 16)
                    elif has_signal(dut, 'a'):
                        try:
                            dut.a[i].value = clamp_to_width(a_list[i], 16)
                        except:
                            pass
                
                # Set m_scaled
                if has_signal(dut, 'm_scaled'):
                    # Clamp to 32-bit signed
                    m_val = m
                    if m_val >= (1 << 31):
                        m_val = (1 << 31) - 1
                    elif m_val < -(1 << 31):
                        m_val = -(1 << 31)
                    dut.m_scaled.value = from_signed(m_val, 32)
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done = False
                for _ in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if has_signal(dut, 'done'):
                        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                            done = True
                            break
                
                if not done:
                    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
                
                # Read result
                if not has_signal(dut, 'result'):
                    raise TestFailure("No result signal found")
                
                result_val = int(dut.result.value)
                # Convert from signed if needed
                if result_val >= (1 << 31):
                    result_val = result_val - (1 << 32)
                
                if result_val < 0:
                    result_val = result_val + MOD
                
                if result_val != expected_result:
                    raise TestFailure(f"Expected {expected_result}, got {result_val}")
            else:
                # Combinational - just wait
                await Timer(100, units='ns')
                # Similar result reading logic
                if not has_signal(dut, 'result'):
                    raise TestFailure("No result signal found")
                result_val = int(dut.result.value)
                if result_val != expected_result:
                    raise TestFailure(f"Expected {expected_result}, got {result_val}")
            
            cocotb.log.info(f"Test {idx+1} passed")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {idx+1} FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")