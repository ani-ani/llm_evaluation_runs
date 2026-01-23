import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Reference implementation
def compute_bulkheads(N, x_coords, y_coords, C):
    """Compute expected M and bulkhead x-coordinates."""
    # Total area
    area_sum = 0
    for i in range(N):
        x1, y1 = x_coords[i], y_coords[i]
        x2, y2 = x_coords[(i+1) % N], y_coords[(i+1) % N]
        area_sum += x1 * y2 - x2 * y1
    total_area = abs(area_sum) / 2
    
    # Compute M
    M = int(total_area // C)
    if M < 1:
        M = 1
    if M > 100:
        M = 100
    
    # Find x_min and x_max
    x_min = min(x_coords)
    x_max = max(x_coords)
    
    # Prepare edges (x1 <= x2)
    edges = []
    for i in range(N):
        x1, y1 = x_coords[i], y_coords[i]
        x2, y2 = x_coords[(i+1) % N], y_coords[(i+1) % N]
        if x1 > x2:
            x1, x2 = x2, x1
            y1, y2 = y2, y1
        edges.append((x1, y1, x2, y2))
    
    # Function to compute cumulative area up to x
    def cumulative_area(x):
        if x <= x_min:
            return 0.0
        if x >= x_max:
            return total_area
        # Use trapezoidal integration over edges
        area = 0.0
        for (x1, y1, x2, y2) in edges:
            if x1 >= x:
                continue
            if x2 <= x_min:
                continue
            # Intersection with vertical line at x
            x_left = max(x1, x_min)
            x_right = min(x2, x)
            if x_right <= x_left:
                continue
            # Interpolate y at x_left and x_right
            if x2 - x1 != 0:
                t_left = (x_left - x1) / (x2 - x1)
                y_left = y1 + t_left * (y2 - y1)
                t_right = (x_right - x1) / (x2 - x1)
                y_right = y1 + t_right * (y2 - y1)
            else:
                y_left = y1
                y_right = y1
            # For upper/lower, we need to know polygon orientation
            # Since vertices are CCW, the upper chain has decreasing y from leftmost to rightmost? 
            # Actually, we can determine by checking the y-values relative to the polygon's center
            # For simplicity, we'll assume the polygon is convex and use the highest y as upper, lowest as lower
            # But we need to sum the area between upper and lower chains
            # This is complex; for the testbench, we'll use a numerical approach
            pass
        # Since this is a testbench reference, we'll use numerical integration
        num_steps = 100
        dx = (x - x_min) / num_steps
        area = 0.0
        for step in range(num_steps):
            xi = x_min + (step + 0.5) * dx
            # Find y_upper and y_lower at xi
            y_upper = -float('inf')
            y_lower = float('inf')
            for (x1, y1, x2, y2) in edges:
                if x1 <= xi <= x2:
                    if x2 - x1 != 0:
                        t = (xi - x1) / (x2 - x1)
                        yi = y1 + t * (y2 - y1)
                    else:
                        yi = y1
                    # For CCW polygon, the upper chain has larger y for a given x
                    if yi > y_upper:
                        y_upper = yi
                    if yi < y_lower:
                        y_lower = yi
            if y_upper > y_lower:
                area += (y_upper - y_lower) * dx
        return area
    
    # Find bulkheads
    bulkheads = []
    for k in range(1, M):
        target = (k * total_area) / M
        # Binary search
        low = x_min
        high = x_max
        for _ in range(16):
            mid = (low + high) / 2.0
            area_mid = cumulative_area(mid)
            if area_mid < target:
                low = mid
            else:
                high = mid
        x_k = (low + high) / 2.0
        bulkheads.append(x_k)
    
    return M, bulkheads

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_bulkheads(dut):
    """Test the bulkheads module."""
    
    # Detect interface
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        (50, 4, [110, 80, 80, 110], [10, 10, 0, 0]),
        (24, 3, [10, 30, 20], [10, 10, 20]),
        (1280, 10, [100, 97, 94, 74, 50, 29, 13, 3, 0, 100], [120, 50, 99, 97, 87, 71, 50, 26, 0, 0]),
    ]
    
    passed = 0
    failed = 0
    
    for i, (C, N, x_coords, y_coords) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: C={C}, N={N}")
        
        # Compute reference
        ref_M, ref_bulkheads = compute_bulkheads(N, x_coords, y_coords, C)
        
        # Set inputs
        dut.N.value = N
        dut.C.value = C
        for j in range(8):
            if j < N:
                if hasattr(dut, f'x_{j}'):
                    getattr(dut, f'x_{j}').value = x_coords[j]
                else:
                    dut.x[j].value = x_coords[j]
                if hasattr(dut, f'y_{j}'):
                    getattr(dut, f'y_{j}').value = y_coords[j]
                else:
                    dut.y[j].value = y_coords[j]
            else:
                if hasattr(dut, f'x_{j}'):
                    getattr(dut, f'x_{j}').value = 0
                else:
                    dut.x[j].value = 0
                if hasattr(dut, f'y_{j}'):
                    getattr(dut, f'y_{j}').value = 0
                else:
                    dut.y[j].value = 0
        
        # Start computation
        if is_sequential:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            # Wait for done
            for cycle in range(10000):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                raise TestFailure(f"Timeout waiting for done in test {i+1}")
        else:
            await Timer(1000, units='ns')
        
        # Read outputs
        if not is_value_defined(dut.M.value):
            raise TestFailure(f"M undefined in test {i+1}")
        M_read = int(dut.M.value)
        
        if M_read != ref_M:
            dut._log.error(f"Test {i+1}: Expected M={ref_M}, got {M_read}")
            failed += 1
            continue
        
        # Read bulkheads
        bulkheads_read = []
        for k in range(M_read - 1):
            if hasattr(dut, f'x_bulk_{k}'):
                val = getattr(dut, f'x_bulk_{k}').value
            else:
                val = dut.x_bulk[k].value
            if is_value_defined(val):
                # Convert Q16.16 to float
                bulkheads_read.append(int(val) / 65536.0)
            else:
                bulkheads_read.append(None)
        
        if len(bulkheads_read) != len(ref_bulkheads):
            dut._log.error(f"Test {i+1}: Expected {len(ref_bulkheads)} bulkheads, got {len(bulkheads_read)}")
            failed += 1
            continue
        
        all_ok = True
        for k, (read_val, exp_val) in enumerate(zip(bulkheads_read, ref_bulkheads)):
            if read_val is None:
                dut._log.error(f"Test {i+1}, bulkhead {k}: undefined value")
                all_ok = False
                break
            # Allow tolerance
            if abs(read_val - exp_val) > 1e-4:
                dut._log.error(f"Test {i+1}, bulkhead {k}: expected {exp_val:.6f}, got {read_val:.6f}")
                all_ok = False
                break
        
        if all_ok:
            dut._log.info(f"Test {i+1}: PASS")
            passed += 1
        else:
            failed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
