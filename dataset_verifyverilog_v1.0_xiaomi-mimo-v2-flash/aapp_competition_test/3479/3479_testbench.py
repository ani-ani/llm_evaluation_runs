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
    max_val = (1 << bits) - 1
    if v < 0: return 0
    return max_val if v > max_val else v

# Binary search simulation in Python for expected result
def solve_python(n, k, t):
    t.sort()
    low, high = 0, max(t) * 2  # Upper bound: single driver shuttles all
    ans = high
    while low <= high:
        mid = (low + high) // 2
        capacity = 0
        for i in range(n):
            # Each fast driver can make round trips within mid seconds
            round_trips = mid // (2 * t[i]) if t[i] > 0 else 0
            capacity += 1 + 4 * round_trips
            if capacity >= n:
                break
        if capacity >= n:
            ans = mid
            high = mid - 1
        else:
            low = mid + 1
    return ans

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_transport(dut):
    is_seq = has_signal(dut, 'clk')
    CLK_NS = 10
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    # Test cases scaled to n<=16, k<=16
    test_cases = [
        (11, 2, [12000,9000,4500,10000,12000,11000,12000,18000,10000,9000,12000], 13500),
        (6, 2, [1000,2000,3000,4000,5000,6000], 2000),
        (1, 1, [1000], 1000),
        (5, 1, [1000,2000,3000,4000,5000], 5000),
        (10, 2, [5000]*10, 5000)
    ]
    
    for i, (n, k, t_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, k={k}, t={t_list[:5]}..., exp={expected}")
        
        # Scale down times if too large for 18-bit
        scaled_t = [clamp_to_width(t, 18) for t in t_list]
        # Pad to 16 elements with 0
        while len(scaled_t) < 16:
            scaled_t.append(0)
        
        # Set inputs
        if is_seq:
            dut.n.value = n
            dut.k.value = k
            for j in range(16):
                getattr(dut, f't_{j}').value = scaled_t[j]
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done = False
            for _ in range(256):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            if not done:
                raise TestFailure(f"Test {i+1}: Timeout")
            
            result = int(dut.result.value)
        else:
            # Combinational: set inputs and wait
            dut.n.value = n
            dut.k.value = k
            for j in range(16):
                getattr(dut, f't_{j}').value = scaled_t[j]
            await Timer(100, units='ns')
            result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        # Reset for next test
        if is_seq:
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
        else:
            dut.n.value = 0
            dut.k.value = 0
            for j in range(16):
                getattr(dut, f't_{j}').value = 0
            await Timer(100, units='ns')

    cocotb.log.info(f"All {len(test_cases)} tests passed!")