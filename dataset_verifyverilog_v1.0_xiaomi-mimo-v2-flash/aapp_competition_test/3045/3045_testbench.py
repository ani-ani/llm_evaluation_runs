import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 24
MAX_CYCLES = 20000  # Deep wait for search loops
CLK_NS = 10

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
    # Handle signed/unsigned carefully; assume unsigned for storage here
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.beacon_valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_beacon(dut, x, y, d):
    """Feed one beacon into the DUT while it accepts input."""
    # In a real hardware module, this would depend on a specific ready/valid handshake.
    # Here we assume a simple interface where we set values and pulse valid.
    dut.beacon_x.value = clamp_to_width(x, DATA_WIDTH)
    dut.beacon_y.value = clamp_to_width(y, DATA_WIDTH)
    dut.beacon_d.value = clamp_to_width(d, DATA_WIDTH)
    dut.beacon_valid.value = 1
    await RisingEdge(dut.clk)
    dut.beacon_valid.value = 0
    # Allow DUT to process/internal buffer the data
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_mps_module(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic test
        await Timer(100, units='ns')

    # Helper to run a test case
    async def run_test_case(beacons, expected_status, expected_x=None, expected_y=None, desc=""):
        cocotb.log.info(f"Running test: {desc}")
        
        # Reset state
        if has_signal(dut, 'rst_n'):
            await reset_dut(dut)
        
        # Load Beacons
        dut.beacon_valid.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Feed data (Assumption: DUT accepts data sequentially until 'start' goes low or 'done' goes high)
        # Or we might need to handle a ready signal. 
        # Let's assume a simple valid handshake where we just dump data.
        for (bx, by, bd) in beacons:
            await load_beacon(dut, bx, by, bd)
            
        # Wait for done
        await wait_for_done(dut)
        
        # Check Results
        status = int(dut.status.value)
        result_x = int(dut.result_x.value)
        result_y = int(dut.result_y.value)
        
        # Interpret status (00=No, 01=Unique, 10=Uncertain, 11=Error)
        if status == 0:
            if expected_status != "impossible":
                raise TestFailure(f"{desc}: Expected {expected_status}, got 'impossible' (status 0)")
        elif status == 1:
            if expected_status != "unique":
                raise TestFailure(f"{desc}: Expected {expected_status}, got 'unique' (status 1)")
            if expected_x is not None and result_x != expected_x:
                raise TestFailure(f"{desc}: X mismatch. Exp {expected_x}, got {result_x}")
            if expected_y is not None and result_y != expected_y:
                raise TestFailure(f"{desc}: Y mismatch. Exp {expected_y}, got {result_y}")
        elif status == 2:
            if expected_status != "uncertain":
                raise TestFailure(f"{desc}: Expected {expected_status}, got 'uncertain' (status 2)")
        else:
            raise TestFailure(f"{desc}: Invalid status code {status}")

    # Test Case 1: From Example (Truncated range for hardware)
    # Hardware scale: Use smaller numbers but same logic
    # Input: 3 beacons
    # B1: (10, 0, 5) -> Dist 5
    # B2: (10, 2, 3) -> Dist 3
    # B3: (12, 1, 1) -> Dist 1
    # Solution should be (11, 1)
    # Check: |11-10| + |1-0| = 1+1=2 != 5. Bad example.
    # Let's use the logic from the problem description with smaller numbers.
    # Sample 1 reduced: 
    # Beacon 1: (100, 10, 5)
    # Beacon 2: (102, 12, 1) -> Diff 1. Target (101, 11)
    # |101-100|+|11-10| = 1+1=2. Need D=2 for B1. |101-102|+|11-12|=1+1=2. Need D=2 for B2.
    await run_test_case(
        [(100, 10, 2), (102, 12, 2)],
        "unique", 101, 11,
        "Simple unique solution"
    )

    # Test Case 2: Impossible
    # B1: (0,0,0) -> Must be (0,0)
    # B2: (10,0,5) -> Cannot be (0,0) as dist is 10
    await run_test_case(
        [(0, 0, 0), (10, 0, 5)],
        "impossible",
        desc="Impossible intersection"
    )

    # Test Case 3: Uncertain
    # B1: (0,0,1) -> Could be (1,0), (0,1), (-1,0), (0,-1)
    # B2: (3,0,2) -> Could be (1,0), (2,0), (3,1) etc.
    # Intersection of (1,0) works: |1-0|+|0-0|=1, |1-3|+|0-0|=2.
    # Intersection of (1,1) works: |1-0|+|1-0|=2 != 1. No.
    # Let's make it clearly uncertain.
    # B1: (0,0,5) -> Range X[-5,5] Y[-5,5]
    # B2: (10,0,5) -> Range X[5,15] Y[-5,5]
    # Intersection: X=5, Y in [-5,5]. Multiple integer Y positions.
    await run_test_case(
        [(0, 0, 5), (10, 0, 5)],
        "uncertain",
        desc="Uncertain vertical line"
    )
    
    # Test Case 4: Impossible (From Sample 3)
    # B1: (100, 0, 100)
    # B2: (0, 200, 199)
    # If R=(x,y), |x-100|+|y| = 100
    # |x| + |y-200| = 199
    # Try (0,0): 100 != 100 (OK), 200 != 199 (FAIL)
    # Try (0, 199): | -100 | + 199 = 299 != 100
    # It is indeed impossible. Use scaled down version.
    # B1: (50, 0, 50)
    # B2: (0, 100, 99)
    await run_test_case(
        [(50, 0, 50), (0, 100, 99)],
        "impossible",
        desc="Impossible scaled"
    )

    cocotb.log.info("All tests passed!")