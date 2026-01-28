import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Helper to set 2-bit per position arrays
def set_wheel_array(dut, prefix, values, length):
    for i in range(length):
        val = clamp_to_width(values[i], 2)
        attr = f'{prefix}_{i}' if hasattr(dut, f'{prefix}_0') else prefix
        if hasattr(dut, attr) and hasattr(getattr(dut, attr), '__getitem__'):
            getattr(dut, attr)[i].value = val
        else:
            # Individual signals arr_0, arr_1...
            sig = getattr(dut, f'{prefix}_{i}')
            sig.value = val

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_wheel_module(dut):
    is_seq = has_signal(dut, 'clk')
    CLK_NS = 10
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Map letters to 2-bit: A=0, B=1, C=2
    def str_to_vals(s):
        mapping = {'A': 0, 'B': 1, 'C': 2}
        return [mapping[c] for c in s.strip()]
    
    def rotate_list(lst, n, left=True):
        if not lst or n == 0:
            return lst[:]
        n = n % len(lst)
        if left:
            return lst[n:] + lst[:n]
        else:
            return lst[-n:] + lst[:-n]
    
    def compute_min(s1, s2, s3):
        n = len(s1)
        if n < 2 or n > 8:
            return -1
        vals1 = str_to_vals(s1)
        vals2 = str_to_vals(s2)
        vals3 = str_to_vals(s3)
        min_rot = float('inf')
        # Try all rotations: 0 to n-1 for each wheel (left shift)
        for r1 in range(n):
            for r2 in range(n):
                for r3 in range(n):
                    rotated1 = rotate_list(vals1, r1, left=True)
                    rotated2 = rotate_list(vals2, r2, left=True)
                    rotated3 = rotate_list(vals3, r3, left=True)
                    valid = True
                    for c in range(n):
                        if rotated1[c] == rotated2[c] or rotated2[c] == rotated3[c] or rotated1[c] == rotated3[c]:
                            valid = False
                            break
                    if valid:
                        total = r1 + r2 + r3
                        if total < min_rot:
                            min_rot = total
        return min_rot if min_rot != float('inf') else -1
    
    test_cases = [
        ("ABC", "ABC", "ABC", 2),
        ("ABBBAAAA", "BBBCCCBB", "CCCCAAAC", 3),
        ("AABB", "BBCC", "ACAC", -1)
    ]
    
    for i, (s1, s2, s3, expected) in enumerate(test_cases):
        n = len(s1)
        cocotb.log.info(f"Test {i+1}: n={n}, expect={expected}")
        
        vals1 = str_to_vals(s1)
        vals2 = str_to_vals(s2)
        vals3 = str_to_vals(s3)
        
        # Set arrays
        if hasattr(dut, 'wheel0') and hasattr(dut.wheel0, '__getitem__'):
            for k in range(n):
                dut.wheel0[k].value = vals1[k]
                dut.wheel1[k].value = vals2[k]
                dut.wheel2[k].value = vals3[k]
        else:
            for k in range(n):
                getattr(dut, f'wheel0_{k}').value = vals1[k]
                getattr(dut, f'wheel1_{k}').value = vals2[k]
                getattr(dut, f'wheel2_{k}').value = vals3[k]
        
        dut.length.value = n
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done = False
            for _ in range(300):  # Cycle limit
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            if not done:
                raise TestFailure(f"Test {i+1}: Done not signaled")
        else:
            await Timer(100, units='ns')
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result undefined")
        
        result = int(dut.result.value)
        if expected == -1:
            expected_encoded = 15  # -1 in 4 bits
            if result != expected_encoded:
                raise TestFailure(f"Test {i+1}: Expected -1 (15), got {result}")
        else:
            if result != expected:
                raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
