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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    # Handle negative for signed if needed, here assuming unsigned logic or python int
    # Python ints are unbounded, just mask
    mask = (1 << bits) - 1
    return v & mask

# Fixed point helpers
Q8_8_FRAC = 8
Q16_16_FRAC = 16

def float_to_q8_8(f):
    return int(f * (1 << Q8_8_FRAC))

def float_to_q16_16(f):
    return int(f * (1 << Q16_16_FRAC))

def q16_16_to_float(v):
    # Handle signed
    if v & (1 << 31):
        v = v - (1 << 32)
    return v / (1 << Q16_16_FRAC)

def pack_2d_array(vals, rows, cols, width):
    # Flattens a 2D list into a single integer or list of integers depending on Verilog mapping
    # Assuming Verilog expects a flattened index or packed array
    # For simplicity in cocotb, we might need to set individual signals or a packed integer
    # If the HDL uses a packed array [N*M-1:0], we do this:
    r = 0
    for i in range(rows):
        for j in range(cols):
            idx = i * cols + j
            r |= (clamp_to_width(vals[i][j], width) << (idx * width))
    return r

def pack_1d_array(vals, width):
    r = 0
    for i, v in enumerate(vals):
        r |= (clamp_to_width(v, width) << (i * width))
    return r

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_sand_art(dut):
    # Setup
    CLK_NS = 10
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        await Timer(2 * CLK_NS, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test Case 1 from prompt
    n, m = 2, 2
    w, h = 5.0, 5.0
    volumes = [2.0, 2.0]
    dividers = [4.0] # n-1 dividers
    min_amount = [[1.0, 0.0], [0.0, 1.0]]
    max_amount = [[1.0, 0.0], [0.0, 2.0]]
    expected = 0.75

    # Convert to fixed point
    w_q = float_to_q8_8(w)
    h_q = float_to_q8_8(h)
    vol_q = [float_to_q16_16(v) for v in volumes]
    
    # Build divider array (pad with 0 and w)
    # The spec says divider_x_in is length N+1 (0, x1, x2, ..., w)
    div_x_q = [0] + [float_to_q8_8(x) for x in dividers] + [w_q]
    
    min_q = [[float_to_q16_16(val) for val in row] for row in min_amount]
    max_q = [[float_to_q16_16(val) for val in row] for row in max_amount]
    
    # Assign inputs based on signal names
    # We assume the module has specific signals for scalars and packed arrays for matrices
    # Or individual signals. Let's try individual signals first for clarity, or packed if specified.
    
    # Handle scalar inputs
    if has_signal(dut, 'w_in'): dut.w_in.value = w_q
    if has_signal(dut, 'h_in'): dut.h_in.value = h_q
    
    # Handle array inputs
    # Volumes (1D array)
    if has_signal(dut, 'volume_in'):
        # Check if it's an array of signals
        if hasattr(dut.volume_in, '__iter__'):
            for i in range(len(vol_q)):
                dut.volume_in[i].value = vol_q[i]
        else:
            # Packed signal
            dut.volume_in.value = pack_1d_array(vol_q, 32)
            
    # Dividers (1D array)
    if has_signal(dut, 'divider_x_in'):
        if hasattr(dut.divider_x_in, '__iter__'):
            # Assumes N+1 elements (0 to N)
            for i in range(len(div_x_q)):
                dut.divider_x_in[i].value = div_x_q[i]
        else:
            dut.divider_x_in.value = pack_1d_array(div_x_q, 16)

    # Min/Max (2D arrays)
    # If the module expects flattened inputs or individual signals
    # We'll check for specific naming conventions like min_in_0_0 or packed min_in
    
    # Try to find generic 2D array access or specific port names
    # Since we don't have the exact module code, we'll try a flexible approach
    
    # Check for packed signals
    if has_signal(dut, 'min_in'):
        if hasattr(dut.min_in, '__iter__'):
            # 2D packed logic if needed or nested array
            # Assuming flat array access for simplicity if not standard
            pass
        else:
            # Packed 2D array: [N*M-1:0]
            # Flatten min_q (n rows, m cols)
            packed_min = 0
            for i in range(n):
                for j in range(m):
                    idx = i * m + j
                    packed_min |= (min_q[i][j] << (idx * 32))
            dut.min_in.value = packed_min
    
    if has_signal(dut, 'max_in'):
        if not hasattr(dut.max_in, '__iter__'):
            packed_max = 0
            for i in range(n):
                for j in range(m):
                    idx = i * m + j
                    packed_max |= (max_q[i][j] << (idx * 32))
            dut.max_in.value = packed_max

    # Handle individual signals for min/max if they exist (e.g., min_in_0_0)
    for i in range(n):
        for j in range(m):
            sig_name = f'min_in_{i}_{j}'
            if has_signal(dut, sig_name):
                getattr(dut, sig_name).value = min_q[i][j]
            
            sig_name = f'max_in_{i}_{j}'
            if has_signal(dut, sig_name):
                getattr(dut, sig_name).value = max_q[i][j]

    # Start calculation
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    # Wait for done
    done_found = False
    for _ in range(5000): # Max cycles
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                done_found = True
                break
    
    if not done_found:
        raise TestFailure("Timeout waiting for done signal")

    # Read result
    if has_signal(dut, 'result'):
        res_val = int(dut.result.value)
        res_float = q16_16_to_float(res_val)
        
        # Allow small tolerance for fixed point errors
        if abs(res_float - expected) > 0.01:
             raise TestFailure(f"Expected {expected}, got {res_float}")
    else:
        raise TestFailure("Result signal not found")

    # Test Case 2
    dut.rst_n.value = 0
    await Timer(2 * CLK_NS, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    n, m = 2, 2
    w, h = 5.0, 5.0
    volumes = [2.0, 2.0]
    dividers = [4.0]
    min_amount = [[1.0, 0.0], [0.0, 1.0]]
    max_amount = [[1.5, 0.0], [0.0, 2.0]]
    expected = 0.625

    w_q = float_to_q8_8(w)
    h_q = float_to_q8_8(h)
    vol_q = [float_to_q16_16(v) for v in volumes]
    div_x_q = [0] + [float_to_q8_8(x) for x in dividers] + [w_q]
    min_q = [[float_to_q16_16(val) for val in row] for row in min_amount]
    max_q = [[float_to_q16_16(val) for val in row] for row in max_amount]

    if has_signal(dut, 'w_in'): dut.w_in.value = w_q
    if has_signal(dut, 'h_in'): dut.h_in.value = h_q
    if has_signal(dut, 'volume_in'):
        if hasattr(dut.volume_in, '__iter__'):
            for i in range(len(vol_q)): dut.volume_in[i].value = vol_q[i]
        else: dut.volume_in.value = pack_1d_array(vol_q, 32)
    if has_signal(dut, 'divider_x_in'):
        if hasattr(dut.divider_x_in, '__iter__'):
            for i in range(len(div_x_q)): dut.divider_x_in[i].value = div_x_q[i]
        else: dut.divider_x_in.value = pack_1d_array(div_x_q, 16)
    
    if has_signal(dut, 'min_in') and not hasattr(dut.min_in, '__iter__'):
        packed_min = 0
        for i in range(n):
            for j in range(m):
                packed_min |= (min_q[i][j] << ((i * m + j) * 32))
        dut.min_in.value = packed_min
    if has_signal(dut, 'max_in') and not hasattr(dut.max_in, '__iter__'):
        packed_max = 0
        for i in range(n):
            for j in range(m):
                packed_max |= (max_q[i][j] << ((i * m + j) * 32))
        dut.max_in.value = packed_max

    for i in range(n):
        for j in range(m):
            sig_name = f'min_in_{i}_{j}'
            if has_signal(dut, sig_name): getattr(dut, sig_name).value = min_q[i][j]
            sig_name = f'max_in_{i}_{j}'
            if has_signal(dut, sig_name): getattr(dut, sig_name).value = max_q[i][j]

    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

    done_found = False
    for _ in range(5000):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                done_found = True
                break
    
    if not done_found: raise TestFailure("Timeout")

    if has_signal(dut, 'result'):
        res_val = int(dut.result.value)
        res_float = q16_16_to_float(res_val)
        if abs(res_float - expected) > 0.01:
             raise TestFailure(f"Expected {expected}, got {res_float}")
