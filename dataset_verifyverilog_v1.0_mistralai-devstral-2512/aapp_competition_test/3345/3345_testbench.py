import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def float_to_q8_8(f):
    return int(f * 256) & 0xFFFF  # 16-bit signed

def q8_8_to_float(v):
    if v & 0x8000:  # negative
        return (v - 0x10000) / 256.0
    return v / 256.0

def float_to_q16_16(f):
    return int(f * 65536) & 0xFFFFFFFF

def q16_16_to_float(v):
    if v & 0x80000000:
        return (v - 0x100000000) / 65536.0
    return v / 65536.0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_dog_walks(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')

    test_cases = [
        (
            [(0.0, 0.0), (10.0, 0.0)],
            [(30.0, 0.0), (15.0, 0.0)],
            10.0
        ),
        (
            [(10.0, 0.0), (10.0, 8.0), (2.0, 8.0), (2.0, 0.0), (10.0, 0.0)],
            [(0.0, 8.0), (4.0, 8.0), (4.0, 12.0), (0.0, 12.0), (0.0, 8.0), (4.0, 8.0), (4.0, 12.0), (0.0, 12.0), (0.0, 8.0)],
            math.sqrt(2)
        )
    ]

    passed = 0
    failed = 0

    for idx, (walk_a, walk_b, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: Walk A {len(walk_a)} points, Walk B {len(walk_b)} points")
        try:
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            len_a = len(walk_a)
            len_b = len(walk_b)
            
            if is_seq:
                dut.len_a.value = len_a
                dut.len_b.value = len_b
                for i in range(16):
                    if i < len_a:
                        dut.__getattr__(f'a_x_{i}').value = float_to_q8_8(walk_a[i][0])
                        dut.__getattr__(f'a_y_{i}').value = float_to_q8_8(walk_a[i][1])
                    else:
                        dut.__getattr__(f'a_x_{i}').value = 0
                        dut.__getattr__(f'a_y_{i}').value = 0
                    if i < len_b:
                        dut.__getattr__(f'b_x_{i}').value = float_to_q8_8(walk_b[i][0])
                        dut.__getattr__(f'b_y_{i}').value = float_to_q8_8(walk_b[i][1])
                    else:
                        dut.__getattr__(f'b_x_{i}').value = 0
                        dut.__getattr__(f'b_y_{i}').value = 0
            
            # Wait for done
            max_cycles = 200000
            found_done = False
            for _ in range(max_cycles):
                if is_seq:
                    await RisingEdge(dut.clk)
                else:
                    await Timer(100, units='ns')
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    found_done = True
                    break
            
            if not found_done:
                raise TestFailure(f"Did not finish within {max_cycles} cycles")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_val = q16_16_to_float(int(dut.result.value))
            
            if not math.isclose(result_val, expected, rel_tol=1e-4, abs_tol=1e-4):
                raise TestFailure(f"Expected {expected}, got {result_val}")
            
            passed += 1
            cocotb.log.info(f"Test {idx+1} passed")
            
        except TestFailure as e:
            cocotb.log.error(f"Test {idx+1} failed: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")