import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 64
CLK_NS = 10
MAX_CYCLES = 1200

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    if v < 0:
        v = (1 << bits) + v
    return v & ((1 << bits) - 1)

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_fixed(v, bits=32):
    return int(v * (1 << bits))

def from_fixed(v, bits=32):
    return v / (1 << bits)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cooking_time(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Helper to write 64-bit values
    async def write_input(name, value):
        if has_signal(dut, name):
            getattr(dut, name).value = clamp_to_width(value, DATA_WIDTH)
        else:
            # Assume split into high/low if not direct 64-bit
            if has_signal(dut, f"{name}_high"):
                getattr(dut, f"{name}_high").value = (value >> 32) & 0xFFFFFFFF
                getattr(dut, f"{name}_low").value = value & 0xFFFFFFFF

    # Test cases: (k, d, t)
    # Python reference function using Q32.32
    def reference(k, d, t):
        SCALE = 1 << 32
        # Period calculation
        if k % d == 0:
            P = k
        else:
            P = ((k + d - 1) // d) * d
        
        # Units per period (scaled)
        U = k * SCALE + ((P - k) * SCALE) // 2
        
        # Binary search bounds
        # Upper bound: P * ceil(t / (U/SCALE)) is safe. Or simple 2*t + P.
        low = 0
        high = (2 * t + P) * SCALE  # High bound in fixed-point
        
        # We want to find T such that cooked(T) >= t
        # Scaled target
        target = t * SCALE
        
        # Perform binary search for 100 iterations for precision
        for _ in range(100):
            mid = (low + high) // 2
            # Calculate cooked for mid (in fixed point)
            full_periods = mid // (P * SCALE)
            remainder_time = mid % (P * SCALE)
            
            cooked = full_periods * U
            
            if remainder_time <= k * SCALE:
                cooked += remainder_time
            else:
                cooked += k * SCALE + (remainder_time - k * SCALE) // 2
            
            if cooked >= target:
                high = mid
            else:
                low = mid
        
        return high

    test_vectors = [
        (3, 2, 6),       # Example 1
        (4, 2, 20),      # Example 2
        (8, 10, 9),      # Simple
        (1000, 1000, 1000), # Always on
        (2, 5, 18),      # Mixed
        (1, 2, 1000000000000000000), # Large numbers
    ]

    for i, (k, d, t) in enumerate(test_vectors):
        cocotb.log.info(f"Test Case {i+1}: k={k}, d={d}, t={t}")
        
        # Write inputs
        await write_input('k', k)
        await write_input('d', d)
        await write_input('t', t)
        
        # Trigger computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done or timeout
            done_found = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_found = True
                    break
            
            if not done_found:
                raise TestFailure(f"Timeout in test {i+1}")
        else:
            # Combinational or single cycle
            await Timer(100, units='ns')

        # Read result
        if has_signal(dut, 'result_high'):
            res_high = safe_int(dut.result_high.value)
            res_low = safe_int(dut.result_low.value)
            result = (res_high << 32) | res_low
        else:
            result = safe_int(dut.result.value)
        
        # Compute expected
        expected = reference(k, d, t)
        
        # Check with tolerance (1 unit error allowed due to binary search steps)
        diff = abs(result - expected)
        # Tolerance: 10 cycles * 1 unit precision roughly, or small margin
        if diff > 10000:  # 10000 / 2^32 ~ 2e-6, generous
            raise TestFailure(f"Mismatch: Got {result} (approx {from_fixed(result)}), Expected {expected} (approx {from_fixed(expected)})")
        
        cocotb.log.info(f"Result: {result} ({from_fixed(result):.10f})")
