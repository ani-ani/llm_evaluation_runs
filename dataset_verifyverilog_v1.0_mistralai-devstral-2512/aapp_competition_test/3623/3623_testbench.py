import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def float_to_q16(f):
    return int(f * 65536)

def q16_to_float(v):
    return v / 65536.0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sprinklers(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: Inputs are degrees * 1000 (0-90000)
    test_cases = [
        # 45 45 0 0 -> Expected 0.75
        (45000, 45000, 0, 0, 0.75),
        # 30 30 10 45 -> Expected ~0.870444
        (30000, 30000, 10000, 45000, 0.87044439473),
        # All 0 -> Expected 0.0 (assuming walls block spray)
        (0, 0, 0, 0, 0.0),
    ]
    
    for i, (a, b, c, d, expected_prop) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input angles {a} {b} {c} {d}")
        
        # Apply inputs
        dut.angle_a.value = a
        dut.angle_b.value = b
        dut.angle_c.value = c
        dut.angle_d.value = d
        
        # Trigger
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            max_cycles = 1000
            done = False
            for _ in range(max_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure(f"Timeout on test {i+1}")
        else:
            # Combinational path
            await Timer(100, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined on test {i+1}")
            
        result_int = int(dut.result.value)
        # Convert Q16.16 to float
        result_float = q16_to_float(result_int)
        
        # Check tolerance
        if abs(result_float - expected_prop) > 0.001:  # 1e-6 tolerance usually, looser for fixed point approx
            raise TestFailure(f"Expected {expected_prop}, got {result_float} ({result_int:#x})")
        
        cocotb.log.info(f"Result: {result_float:.6f}")
        
        # Prepare for next test
        await RisingEdge(dut.clk)

