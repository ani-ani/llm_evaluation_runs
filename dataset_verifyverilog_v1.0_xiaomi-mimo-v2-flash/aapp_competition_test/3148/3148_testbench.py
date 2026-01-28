import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Configuration
DATA_WIDTH = 8
OUT_WIDTH = 16
MAX_SWIMMERS = 8
CLK_NS = 10
MAX_CYCLES = 500

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0:
        # Handle signed clamping logic or just truncate bits (Python int handles big nums)
        return v & ((1 << bits) - 1)
    return min(max_val, v)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Helper to calculate Manhattan distance
def manhattan(p1, p2):
    return abs(p1[0] - p2[0]) + abs(p1[1] - p2[1])

def verify_solution(swimmers, g1, g2):
    n = len(swimmers)
    count_g2 = 0
    equal_count = 0
    
    d1_list = []
    d2_list = []
    
    for s in swimmers:
        d1 = manhattan(s, g1)
        d2 = manhattan(s, g2)
        d1_list.append(d1)
        d2_list.append(d2)
        if d2 < d1:
            count_g2 += 1
        elif d1 == d2:
            equal_count += 1
            count_g2 += 1  # Counts for both, so technically it's in the group
            
    # Requirement: Both responsible for exact same number, max 1 equal distance
    # If equal_count == 1, it counts for both. 
    # Let count1 = swimmers closer to g1
    # Let count2 = swimmers closer to g2
    # Let count_eq = swimmers equidistant
    # count1 + count2 + count_eq = n
    # count1 + count_eq <= count2 + count_eq (or vice versa for equality)
    # If count_eq == 1, it adds to both sides.
    # We need count1 == count2 (including the shared one in both counts)
    
    # Let's simplify: The shared swimmer counts for both.
    # So if we have S shared swimmers (S <= 1).
    # Group 1: Closer to G1 + Shared
    # Group 2: Closer to G2 + Shared
    # We need: |Closer to G1| + S = |Closer to G2| + S => |Closer to G1| = |Closer to G2|
    
    count_g1_only = 0
    count_g2_only = 0
    
    for i in range(n):
        if d1_list[i] < d2_list[i]:
            count_g1_only += 1
        elif d2_list[i] < d1_list[i]:
            count_g2_only += 1
            
    if count_g1_only == count_g2_only and equal_count <= 1:
        return True
    return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_lifeguards(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test Cases (Reduced size for HDL simulation)
    # Case 1: 5 swimmers (Sample 1)
    test_cases = [
        {
            "swimmers": [(0, 0), (0, 1), (1, 0), (0, -1), (-1, 0)],
            "desc": "5 star shape"
        },
        {
            "swimmers": [(2, 4), (6, -1), (3, 5), (-1, -1)],
            "desc": "4 random points"
        }
    ]

    for tc in test_cases:
        swimmers = tc["swimmers"]
        desc = tc["desc"]
        
        cocotb.log.info(f"Testing: {desc} with {len(swimmers)} swimmers")
        
        # Write inputs
        # Clear unused slots
        for i in range(MAX_SWIMMERS):
            if i < len(swimmers):
                x, y = swimmers[i]
            else:
                x, y = -128, -128 # Default invalid
            
            # Assign to array signals
            # Check if dut has array interface (swimmer_x_0, etc) or unpacked array
            # We assume unpacked array style: dut.swimmer_x[i]
            if has_signal(dut, f'swimmer_x_{i}'):
                getattr(dut, f'swimmer_x_{i}').value = clamp_to_width(x, DATA_WIDTH)
                getattr(dut, f'swimmer_y_{i}').value = clamp_to_width(y, DATA_WIDTH)
            else:
                # Fallback for direct array access if simulator supports it (rarely good for cocotb)
                # But prompt usually implies individual signals or unpacked arrays
                # Let's try the unpacked array access style
                try:
                    dut.swimmer_x[i].value = clamp_to_width(x, DATA_WIDTH)
                    dut.swimmer_y[i].value = clamp_to_width(y, DATA_WIDTH)
                except Exception as e:
                    cocotb.log.error(f"Signal access failed: {e}. Ensure module has swimmer_x[7:0] or swimmer_x_0..7 ports.")

        if has_signal(dut, 'num_swimmers'):
            dut.num_swimmers.value = len(swimmers)
            
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read Results
        if not (is_value_defined(dut.lifeguard1_x.value) and is_value_defined(dut.lifeguard2_x.value)):
            raise TestFailure("Output signals undefined")
            
        g1_x = int(dut.lifeguard1_x.value)
        g1_y = int(dut.lifeguard1_y.value)
        g2_x = int(dut.lifeguard2_x.value)
        g2_y = int(dut.lifeguard2_y.value)
        
        # Convert from unsigned int to signed Python int if necessary
        # Assuming outputs are signed logic in Verilog, cocotb reads them as binary string usually
        # int() handles it correctly if it's an integer object.
        # If it's a binary string (e.g. '111...'), we might need conversion, but usually int() works on the value.
        
        cocotb.log.info(f"Result: Lifeguard 1 at ({g1_x}, {g1_y}), Lifeguard 2 at ({g2_x}, {g2_y})")
        
        # Verification
        if not verify_solution(swimmers, (g1_x, g1_y), (g2_x, g2_y)):
             raise TestFailure(f"Invalid division for {desc}. Counts do not match or too many equidistant.")
             
        cocotb.log.info("Test Passed")
