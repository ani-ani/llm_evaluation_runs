import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# --- Helpers ---
def is_value_defined(v):
    try:
        int(v); return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
    except AttributeError:
        return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# --- Testbench Constants ---
MAX_N = 8
MAX_M = 8
MAX_K = 4
PRICE_WIDTH = 32
SHOP_ADDR_WIDTH = 3
MAX_COST = 2**32 - 1

# --- Input Generation Helpers ---
def generate_scaled_input(raw_input):
    """Scales a large input to fit HDL constraints (n=8, m=8, k=4)."""
    lines = raw_input.strip().split('\n')
    n, m, k = map(int, lines[0].split())
    
    # Scale k (cap at 4)
    scaled_k = min(k, MAX_K)
    
    # Scale n (take first 8 items)
    items = []
    for i in range(1, min(n, MAX_N) + 1):
        a, p, b, q = map(int, lines[i].split())
        # Scale shops: map original 1..m to 0..7 (cap at 7)
        # Simple modulo or clamp for demo purposes
        scaled_a = (a - 1) % MAX_M
        scaled_b = (b - 1) % MAX_M
        # Cap prices to 32-bit max
        scaled_p = p if p < (1<<31) else (1<<31) - 1
        scaled_q = q if q < (1<<31) else (1<<31) - 1
        items.append((scaled_a, scaled_p, scaled_b, scaled_q))
    
    # Pad if n < 8
    while len(items) < MAX_N:
        items.append((0, 0, 0, 0))
        
    return scaled_k, items

# --- Wait for Done ---
async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done) and int(dut.done) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# --- Reset ---
async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_antique_shopping(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test Cases
    test_inputs = [
        "3 3 2\n1 30 2 50\n2 70 3 10\n3 20 1 80\n", # Expected: 60
        "3 3 1\n1 30 2 50\n2 70 3 10\n3 20 1 80\n", # Expected: -1
        "1 2 1\n1 10 2 20\n"                              # Expected: 10
    ]
    
    expected_results = [60, MAX_COST, 10]
    
    for idx, (raw_input, exp_res) in enumerate(zip(test_inputs, expected_results)):
        cocotb.log.info(f"Running Test Case {idx+1}")
        
        # Scale Input
        k_scaled, items = generate_scaled_input(raw_input)
        
        # Drive Inputs
        dut.k_limit.value = k_scaled
        
        # Write Arrays
        for i in range(MAX_N):
            a, p, b, q = items[i]
            # Access array elements dut.antique_a[i]
            # Assuming ports are indexed: antique_a_0, antique_a_1...
            # OR array: dut.antique_a[i]
            
            # Using standard array access for robustness
            try:
                dut.antique_a[i].value = a
                dut.antique_p[i].value = p
                dut.antique_b[i].value = b
                dut.antique_q[i].value = q
            except AttributeError:
                # Fallback for flattened ports: antique_a_0
                if has_signal(dut, f'antique_a_{i}'):
                    getattr(dut, f'antique_a_{i}').value = a
                    getattr(dut, f'antique_p_{i}').value = p
                    getattr(dut, f'antique_b_{i}').value = b
                    getattr(dut, f'antique_q_{i}').value = q
                else:
                    raise TestFailure(f"Array ports not found for index {i}")

        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait
        await wait_for_done(dut)
        
        # Check Result
        if not is_value_defined(dut.result):
             raise TestFailure("Result signal undefined")
             
        res_val = int(dut.result)
        
        # If result is -1 (0xFFFFFFFF), map to MAX_COST for comparison if needed
        # But usually verilog outputs exactly -1 if signed, or 0xFFFFFFFF if unsigned.
        # Let's handle both.
        if res_val == MAX_COST and exp_res == MAX_COST:
            cocotb.log.info(f"Test {idx+1} Passed: Got -1 as expected")
        elif res_val == exp_res:
            cocotb.log.info(f"Test {idx+1} Passed: Got {res_val}")
        else:
            raise TestFailure(f"Test {idx+1} Failed: Expected {exp_res}, Got {res_val}")
