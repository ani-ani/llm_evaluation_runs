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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Q16.16 conversion
def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Reference calculation
def reference_polar_rect(polar_mag, polar_phi):
    # Convert fixed to float
    r = fixed_to_float(polar_mag, 16)
    phi = fixed_to_float(polar_phi, 16)  # phi in radians
    
    # Compute x = r * cos(phi), y = r * sin(phi)
    x = r * math.cos(phi)
    y = r * math.sin(phi)
    
    # Convert back to fixed
    return float_to_fixed(x, 16), float_to_fixed(y, 16)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_polar_to_rect(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (r, phi, desc)
        (5.0, 0.9273, "Test 1: (3,4) -> (5, 0.9273)"),
        (8.0623, 1.0517, "Test 2: (4,7) -> (8.0623, 1.0517)"),
        (22.6716, 0.8478, "Test 3: (15,17) -> (22.6716, 0.8478)"),
        (1.0, 0.0, "Test 4: Unit radius, angle 0"),
        (10.0, math.pi/2, "Test 5: Unit radius, angle π/2"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (r_f, phi_f, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Convert to fixed-point
            polar_mag = float_to_fixed(r_f, 16)
            polar_phi = float_to_fixed(phi_f, 16)
            
            # Expected outputs
            exp_x, exp_y = reference_polar_rect(polar_mag, polar_phi)
            
            # Write inputs
            if has_signal(dut, 'polar_mag'):
                dut.polar_mag.value = clamp_to_width(polar_mag, 16)
            else:
                # Try individual signals
                for bit in range(16):
                    if hasattr(dut, f'polar_mag_{bit}'):
                        dut.__setattr__(f'polar_mag_{bit}').value = (polar_mag >> bit) & 1
            
            if has_signal(dut, 'polar_phi'):
                dut.polar_phi.value = clamp_to_width(polar_phi, 16)
            else:
                for bit in range(16):
                    if hasattr(dut, f'polar_phi_{bit}'):
                        dut.__setattr__(f'polar_phi_{bit}').value = (polar_phi >> bit) & 1
            
            # Trigger conversion
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done = False
            for _ in range(50):  # Max 50 cycles
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure(f"Timeout waiting for done signal")
            
            # Read outputs
            if has_signal(dut, 'rect_x'):
                act_x = int(dut.rect_x.value)
            else:
                # Try packed signals
                act_x = 0
                for bit in range(16):
                    if hasattr(dut, f'rect_x_{bit}'):
                        act_x |= int(dut.__getattr__(f'rect_x_{bit}').value) << bit
            
            if has_signal(dut, 'rect_y'):
                act_y = int(dut.rect_y.value)
            else:
                act_y = 0
                for bit in range(16):
                    if hasattr(dut, f'rect_y_{bit}'):
                        act_y |= int(dut.__getattr__(f'rect_y_{bit}').value) << bit
            
            # Convert back to float for comparison
            act_x_f = fixed_to_float(act_x, 16)
            act_y_f = fixed_to_float(act_y, 16)
            exp_x_f = fixed_to_float(exp_x, 16)
            exp_y_f = fixed_to_float(exp_y, 16)
            
            # Check with tolerance
            tol = 0.01  # 1% tolerance
            if abs(act_x_f - exp_x_f) / (abs(exp_x_f) + 1e-6) > tol:
                raise TestFailure(f"X mismatch: expected {exp_x_f:.4f}, got {act_x_f:.4f}")
            if abs(act_y_f - exp_y_f) / (abs(exp_y_f) + 1e-6) > tol:
                raise TestFailure(f"Y mismatch: expected {exp_y_f:.4f}, got {act_y_f:.4f}")
            
            cocotb.log.info(f"  Result: ({act_x_f:.4f}, {act_y_f:.4f})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    cocotb.log.info(f"All {passed} tests passed")