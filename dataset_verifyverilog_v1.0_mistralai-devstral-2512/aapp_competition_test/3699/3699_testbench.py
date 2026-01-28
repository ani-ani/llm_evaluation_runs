import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random
import math

# Constants
DATA_WIDTH = 16
COORD_WIDTH = 16
INDEX_WIDTH = 4
RESULT_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 2000

# Helpers

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'bottle_valid'): dut.bottle_valid.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def dist_sq(x1, y1, x2, y2):
    return (x1 - x2)**2 + (y1 - y2)**2

def python_solve(ax, ay, bx, by, tx, ty, bottles):
    # bottles: list of (x, y)
    base_cost = 0
    savings_adil = []
    savings_bera = []
    
    for x, y in bottles:
        db = dist_sq(tx, ty, x, y)
        da = dist_sq(ax, ay, x, y)
        dbb = dist_sq(bx, by, x, y)
        
        base_cost += 2 * db
        # Savings definition: Distance saved by picking bottle vs moving bin->bottle->bin
        # Distance if picked: Adil->Bottle + Bottle->Bin
        # Distance if not picked: Bin->Bottle + Bottle->Bin (2*db)
        # Wait, the problem logic: Adil starts at ax,ay. Bin is at tx,ty.
        # Path: Start -> Bottle -> Bin -> (next?)
        # The total distance minimization usually sums up:
        # Sum(2*Bin->Bottle) - max_savings.
        # Savings if Adil picks bottle i: 2*Bin->Bottle_i - (Adil->Bottle_i + Bottle_i->Bin)
        # Note: Adil->Bottle is the first leg, then Bottle->Bin. 
        # If someone else picks it, cost is 2*Bin->Bottle (start at bin, go to bottle, return).
        # If Adil picks it, cost is Adil->Bottle + Bottle->Bin (he starts at ax,ay).
        # Savings = (2*Bin->Bottle) - (Adil->Bottle + Bottle->Bin)
        # Wait, standard problem logic:
        # Total cost if everyone starts at bin and goes back to bin: Sum(2 * Bin->Bottle)
        # If Adil picks bottle: Cost = Adil->Bottle + Bottle->Bin.
        # Savings = (2*Bin->Bottle) - (Adil->Bottle + Bottle->Bin).
        
        s_a = 2 * db - (da + db)
        s_b = 2 * db - (dbb + db)
        
        savings_adil.append(s_a)
        savings_bera.append(s_b)
        
    # Find best savings
    n = len(bottles)
    
    # Top 2 for A
    top1_a = -10**18
    idx1_a = -1
    top2_a = -10**18
    idx2_a = -1
    
    for i, s in enumerate(savings_adil):
        if s > top1_a:
            top2_a, idx2_a = top1_a, idx1_a
            top1_a, idx1_a = s, i
        elif s > top2_a:
            top2_a, idx2_a = s, i
            
    # Top 2 for B
    top1_b = -10**18
    idx1_b = -1
    top2_b = -10**18
    idx2_b = -1
    
    for i, s in enumerate(savings_bera):
        if s > top1_b:
            top2_b, idx2_b = top1_b, idx1_b
            top1_b, idx1_b = s, i
        elif s > top2_b:
            top2_b, idx2_b = s, i
            
    max_savings = max(top1_a, top1_b)
    
    if idx1_a != idx1_b:
        max_savings = max(max_savings, top1_a + top1_b)
    else:
        max_savings = max(max_savings, top1_a + top2_b, top2_a + top1_b)
        
    return base_cost - max_savings

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_recycling_bin(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Check signals exist
    if not (has_signal(dut, 'start') and has_signal(dut, 'ready') and has_signal(dut, 'done')):
        raise TestFailure("Missing control signals (start, ready, done)")
        
    # Test cases: Random inputs
    num_tests = 5
    for t in range(num_tests):
        cocotb.log.info(f"Running Test Case {t+1}")
        
        # Generate Random Coordinates within 16-bit signed range
        ax = random.randint(-10000, 10000)
        ay = random.randint(-10000, 10000)
        bx = random.randint(-10000, 10000)
        by = random.randint(-10000, 10000)
        tx = random.randint(-10000, 10000)
        ty = random.randint(-10000, 10000)
        
        # Number of bottles (1 to 16)
        n = random.randint(1, 16)
        bottles = []
        for _ in range(n):
            bottles.append((random.randint(-10000, 10000), random.randint(-10000, 10000)))
            
        # Python Reference
        expected = python_solve(ax, ay, bx, by, tx, ty, bottles)
        
        # Feed to DUT
        # Set coordinates
        dut.ax.value = from_signed(ax, COORD_WIDTH)
        dut.ay.value = from_signed(ay, COORD_WIDTH)
        dut.bx.value = from_signed(bx, COORD_WIDTH)
        dut.by.value = from_signed(by, COORD_WIDTH)
        dut.bin_x.value = from_signed(tx, COORD_WIDTH)
        dut.bin_y.value = from_signed(ty, COORD_WIDTH)
        
        # Wait for ready
        timeout = 100
        while not int(dut.ready.value):
            await RisingEdge(dut.clk)
            timeout -= 1
            if timeout == 0:
                raise TestFailure("DUT didn't become ready")
                
        # Feed bottles
        for i, (bx, by) in enumerate(bottles):
            dut.bottle_x.value = from_signed(bx, COORD_WIDTH)
            dut.bottle_y.value = from_signed(by, COORD_WIDTH)
            dut.bottle_index.value = i
            dut.bottle_valid.value = 1
            await RisingEdge(dut.clk)
            
        dut.bottle_valid.value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, 1024)
        
        # Read result
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {t+1} failed: Expected {expected}, Got {result}")
            
        cocotb.log.info(f"Test {t+1} Passed. Result: {result}")
        
        # Small delay between tests
        await Timer(100, units='ns')
