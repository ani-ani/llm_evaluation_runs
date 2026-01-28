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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Fixed-point conversion
def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

def clamp_to_q1616(v):
    """Clamp 32-bit unsigned to Q16.16 range"""
    return clamp_to_width(v, 32)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): 
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        else: await Timer(10, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tetrahedron_area(dut):
    CLK_NS = 10
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (side_float, expected_result_float, description)
    test_cases = [
        (3.0, 15.588457268119894, "side=3"),
        (20.0, 692.8203230275509, "side=20"),
        (10.0, 173.20508075688772, "side=10"),
        (0.0, 0.0, "side=0"),
        (1.0, 1.7320508075688772, "side=1")
    ]
    
    passed = failed = 0
    
    for i, (side_float, exp_float, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Convert to Q16.16
            side_q1616 = float_to_fixed(side_float, 16)
            exp_q1616 = float_to_fixed(exp_float, 16)
            
            # Set inputs
            dut.side.value = clamp_to_q1616(side_q1616)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=100)
            else:
                # Combinational path
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result_q1616 = int(dut.result.value)
            result_float = fixed_to_float(result_q1616, 16)
            exp_float = fixed_to_float(exp_q1616, 16)
            
            # Calculate error tolerance (0.1% for Q16.16)
            tolerance = 0.001
            abs_error = abs(result_float - exp_float)
            rel_error = abs_error / max(1e-9, abs(exp_float))
            
            if rel_error > tolerance:
                raise TestFailure(
                    f"Expected {exp_float:.6f} (0x{exp_q1616:08X}), "
                    f"got {result_float:.6f} (0x{result_q1616:08X}), "
                    f"error={abs_error:.6f}, rel={rel_error:.4f}"
                )
            
            cocotb.log.info(f"  Result: {result_float:.6f} (±{abs_error:.6f})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            if is_seq and has_signal(dut, 'done'):
                # Check if done stuck high
                if int(dut.done.value) != 0:
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    await Timer(100, units='ns')
    
    # Summary
    cocotb.log.info(f"\n=== Summary ===")
    cocotb.log.info(f"Passed: {passed}")
    cocotb.log.info(f"Failed: {failed}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
