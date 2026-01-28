import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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

def to_fixed(val, frac=16):
    return int(val * (1 << frac))

def from_fixed(val, frac=16):
    return val / (1 << frac)

DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 5000

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_cheetah_pack(dut):
    # Setup clock if synchronous
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')

    # Test cases
    # Case 1: 2 cheetahs, same speed, same start
    # t=[1, 1], v=[1, 1]
    # Positions: 1*(T-1), 1*(T-1). Length = 0.
    t1 = [1, 1]
    v1 = [1, 1]
    exp1 = 0.0

    # Case 2: 2 cheetahs
    # t=[1, 99999], v=[99999, 99999]
    # T_start = 99999
    # C1: pos = 99999 * (99999 - 1) = 99999 * 99998
    # C2: pos = 99999 * (99999 - 99999) = 0
    # Length = 99999 * 99998 = 9999700002
    t2 = [1, 99999]
    v2 = [99999, 99999]
    exp2 = 9999700002.0

    # Case 3: 3 cheetahs
    # t=[1, 3, 4], v=[1, 2, 3]
    # C1: p1 = 1*(T-1)
    # C2: p2 = 2*(T-3) = 2T - 6
    # C3: p3 = 3*(T-4) = 3T - 12
    # T_start = 4
    # p1 = 3, p2 = 2, p3 = 0. Length = 3 - 0 = 3.
    # Intersection C1 & C2: 1*(T-1) = 2*(T-3) -> T-1 = 2T-6 -> T=5. p=4. Length = 4 - (3*1=3) = 1.
    # Intersection C2 & C3: 2*(T-3) = 3*(T-4) -> 2T-6 = 3T-12 -> T=6. p=6. Length = 6 - (5*1=5) = 1.
    # Intersection C1 & C3: 1*(T-1) = 3*(T-4) -> T-1 = 3T-12 -> 2T=11 -> T=5.5. p=4.5. Length = 4.5 - (4.5*1? No C2 at 5.5 is 2*2.5=5) -> 5 - 4.5 = 0.5.
    # Min is 0.5.
    t3 = [1, 3, 4]
    v3 = [1, 2, 3]
    exp3 = 0.5

    test_cases = [
        (t1, v1, exp1, "Equal speeds"),
        (t2, v2, exp2, "Delayed start"),
        (t3, v3, exp3, "Intersections")
    ]

    passed = 0
    failed = 0

    for i, (times, velocities, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running test {i+1}: {desc}")
        try:
            N = len(times)
            
            # Set inputs
            if has_signal(dut, 'n_valid'):
                dut.n_valid.value = N
            
            # We need to map inputs. The spec might have arrays or named ports.
            # The prompt suggested arrays t_arr[0:15].
            # We will try to access them.
            for k in range(16):
                if k < N:
                    # Input is integer, no scaling here, module handles it
                    if has_signal(dut, f't_arr_{k}'):
                        getattr(dut, f't_arr_{k}').value = times[k]
                    elif hasattr(dut, 't_arr'):
                        dut.t_arr[k].value = times[k]
                    
                    if has_signal(dut, f'v_arr_{k}'):
                        getattr(dut, f'v_arr_{k}').value = velocities[k]
                    elif hasattr(dut, 'v_arr'):
                        dut.v_arr[k].value = velocities[k]
                else:
                    if has_signal(dut, f't_arr_{k}'):
                        getattr(dut, f't_arr_{k}').value = 0
                    elif hasattr(dut, 't_arr'):
                        dut.t_arr[k].value = 0
                    
                    if has_signal(dut, f'v_arr_{k}'):
                        getattr(dut, f'v_arr_{k}').value = 0
                    elif hasattr(dut, 'v_arr'):
                        dut.v_arr[k].value = 0

            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                max_wait = 2000
                found_done = False
                for _ in range(max_wait):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        found_done = True
                        break
                
                if not found_done:
                    raise TestFailure(f"Timeout waiting for done in test {i+1}")
            else:
                # Combinational or simple flow
                await Timer(100, units='ns')

            # Read result
            if not is_value_defined(dut.min_length.value):
                raise TestFailure(f"Result is undefined for test {i+1}")
            
            result_int = int(dut.min_length.value)
            result_float = from_fixed(result_int, 16)
            
            # Allow tolerance
            if abs(result_float - expected) > 0.02:
                raise TestFailure(f"Expected {expected}, got {result_float} (int: {result_int})")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} - Result {result_float}")

        except Exception as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
            if is_seq:
                # Reset for next test
                dut.rst_n.value = 0
                await RisingEdge(dut.clk)
                dut.rst_n.value = 1
                await RisingEdge(dut.clk)

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")