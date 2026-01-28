import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Constants for fixed-point arithmetic
Q32_32 = 32  # Fractional bits for Q32.32
Q16_16 = 16  # Fractional bits for wind coordinates
SCALE_COORD = 1 << 16  # Scale factor for coordinate differences
SCALE_TIME = 1 << 32   # Scale factor for time (Q32.32)

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def clamp_to_width(v, bits):
    mask = (1 << bits) - 1
    if v < 0:
        v = (1 << bits) + v
    return v & mask

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return (1 << bits) + val
    return val

# Python reference implementation
def python_solve(x1, y1, x2, y2, vmax, t, vx, vy, wx, wy):
    # Scale inputs
    delta_x = (x2 - x1) * SCALE_COORD
    delta_y = (y2 - y1) * SCALE_COORD
    vmax_scaled = vmax * SCALE_TIME
    t_scaled = t * SCALE_COORD
    vx_scaled = vx * SCALE_COORD
    vy_scaled = vy * SCALE_COORD
    wx_scaled = wx * SCALE_COORD
    wy_scaled = wy * SCALE_COORD
    
    # Binary search
    low = 0
    high = (10**9) * SCALE_TIME  # Upper bound ~1e9 seconds
    
    for _ in range(1000):
        mid = (low + high) >> 1
        
        # Compute wind effect
        if mid <= t_scaled:
            wind_x = (vx_scaled * mid) >> Q16_16
            wind_y = (vy_scaled * mid) >> Q16_16
        else:
            wind_x = ((vx_scaled * t_scaled) >> Q16_16) + ((wx_scaled * (mid - t_scaled)) >> Q16_16)
            wind_y = ((vy_scaled * t_scaled) >> Q16_16) + ((wy_scaled * (mid - t_scaled)) >> Q16_16)
        
        # Remaining distance
        rem_x = delta_x - wind_x
        rem_y = delta_y - wind_y
        dist_sq = (rem_x * rem_x) >> 32  # Scale back to Q32.32
        
        # Max reachable distance
        max_dist = (vmax_scaled * mid) >> 32
        reach_sq = max_dist * max_dist
        
        if reach_sq >= dist_sq:
            high = mid
        else:
            low = mid
    
    return high

@cocotb.test(timeout_time=20000, timeout_unit='ms')
async def test_rescue_dirigible(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        # (x1, y1, x2, y2, vmax, t, vx, vy, wx, wy, expected_time)
        (0, 0, 5, 5, 3, 2, -1, -1, -1, 0, 3.729935587093555327),
        (0, 0, 0, 1000, 100, 1000, -50, 0, 50, 0, 11.547005383792516398),
        (0, 0, 0, 1000, 100, 5, 0, -50, 0, 50, 10.0),
        (0, 1000, 0, 0, 50, 10, -49, 0, 49, 0, 20.0),
        (0, 1000, 0, 0, 50, 10, 0, -48, 0, -49, 10.202020202020200657),
        (0, 0, 0, -5000, 100, 20, -50, 0, 50, 0, 50.262613427796381416),
        (0, 0, 0, -350, 55, 5, 0, -50, 0, 50, 3.3333333333333330373),
        (0, -1000, 0, 0, 11, 10, -10, 0, 10, 0, 146.8240957550254393),
        (0, -1000, 0, 0, 22, 10, 0, -12, 0, -10, 85.0),
        (0, 7834, -1, 902, 432, 43, 22, 22, -22, -22, 16.930588983107490719),
    ]
    
    passed = 0
    failed = 0
    
    for i, (x1, y1, x2, y2, vmax, t, vx, vy, wx, wy, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Expected {expected:.10f}")
        
        try:
            # Calculate reference
            expected_scaled = int(expected * SCALE_TIME)
            reference = python_solve(x1, y1, x2, y2, vmax, t, vx, vy, wx, wy)
            
            # Scale inputs
            inputs = [
                x1 * SCALE_COORD, y1 * SCALE_COORD,
                x2 * SCALE_COORD, y2 * SCALE_COORD,
                vmax * SCALE_TIME, t * SCALE_COORD,
                vx * SCALE_COORD, vy * SCALE_COORD,
                wx * SCALE_COORD, wy * SCALE_COORD
            ]
            
            # Write inputs
            if has_signal(dut, 'x1'):
                dut.x1.value = clamp_to_width(inputs[0], 16)
                dut.y1.value = clamp_to_width(inputs[1], 16)
                dut.x2.value = clamp_to_width(inputs[2], 16)
                dut.y2.value = clamp_to_width(inputs[3], 16)
                dut.vmax.value = clamp_to_width(inputs[4], 16)
                dut.t.value = clamp_to_width(inputs[5], 16)
                dut.vx.value = clamp_to_width(inputs[6], 16)
                dut.vy.value = clamp_to_width(inputs[7], 16)
                dut.wx.value = clamp_to_width(inputs[8], 16)
                dut.wy.value = clamp_to_width(inputs[9], 16)
            else:
                for idx, val in enumerate(inputs):
                    port_name = f'input_{idx}' if has_signal(dut, f'input_{idx}') else None
                    if port_name:
                        getattr(dut, port_name).value = clamp_to_width(val, 16)
            
            # Trigger calculation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                max_cycles = 11000
                done = False
                for cycle in range(max_cycles):
                    await RisingEdge(dut.clk)
                    if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                        if int(dut.done.value) == 1:
                            done = True
                            break
                
                if not done:
                    raise TestFailure(f"Timeout waiting for done signal")
                
                # Read result
                if has_signal(dut, 'result'):
                    result_raw = int(dut.result.value)
                    result = to_signed(result_raw, 64)
                    result_time = result / SCALE_TIME
                else:
                    # Try to read from multiple output ports
                    result = 0
                    for j in range(64):
                        port_name = f'result_{j}'
                        if has_signal(dut, port_name):
                            bit = int(getattr(dut, port_name).value)
                            if bit:
                                result |= (1 << j)
                    result_time = to_signed(result, 64) / SCALE_TIME
            else:
                # Combinational - just wait for propagation
                await Timer(1000, units='ns')
                if has_signal(dut, 'result'):
                    result_raw = int(dut.result.value)
                    result = to_signed(result_raw, 64)
                    result_time = result / SCALE_TIME
                else:
                    raise TestFailure("No result signal found")
            
            # Compare with tolerance
            abs_error = abs(result_time - expected)
            rel_error = abs_error / max(1.0, expected)
            
            if rel_error > 1e-6 and abs_error > 1e-6:
                raise TestFailure(f"Expected {expected:.10f}, got {result_time:.10f}, rel_error={rel_error:.2e}")
            
            passed += 1
            cocotb.log.info(f"Test {i+1} PASSED: {result_time:.10f}")
            
        except Exception as e:
            cocotb.log.error(f"Test {i+1} FAILED: {str(e)}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
    
    cocotb.log.info(f"All {passed} tests passed!")

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_edge_cases(dut):
    # Test edge case: destination at origin
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test case: already at destination
    inputs = [
        0, 0, 0, 0,  # Same coordinates
        1000 * SCALE_TIME,  # vmax
        1 * SCALE_COORD,   # t
        0, 0, 0, 0        # No wind
    ]
    
    if has_signal(dut, 'x1'):
        dut.x1.value = clamp_to_width(inputs[0], 16)
        dut.y1.value = clamp_to_width(inputs[1], 16)
        dut.x2.value = clamp_to_width(inputs[2], 16)
        dut.y2.value = clamp_to_width(inputs[3], 16)
        dut.vmax.value = clamp_to_width(inputs[4], 16)
        dut.t.value = clamp_to_width(inputs[5], 16)
        dut.vx.value = clamp_to_width(inputs[6], 16)
        dut.vy.value = clamp_to_width(inputs[7], 16)
        dut.wx.value = clamp_to_width(inputs[8], 16)
        dut.wy.value = clamp_to_width(inputs[9], 16)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        max_cycles = 11000
        done = False
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                if int(dut.done.value) == 1:
                    done = True
                    break
        
        if not done:
            raise TestFailure("Timeout for edge case")
        
        if has_signal(dut, 'result'):
            result_raw = int(dut.result.value)
            result = to_signed(result_raw, 64)
            result_time = result / SCALE_TIME
            
            # For zero distance, time should be very close to 0
            if result_time > 1.0:
                raise TestFailure(f"Zero distance case: expected near 0, got {result_time}")
    
    cocotb.log.info("Edge case test passed")
