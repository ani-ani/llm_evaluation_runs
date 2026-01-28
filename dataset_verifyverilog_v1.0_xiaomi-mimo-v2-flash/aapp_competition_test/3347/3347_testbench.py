import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python solution reference for verification
def solve_python(stores):
    # stores = list of (t, h)
    # Filter invalid: t > h
    valid_stores = [(t, h) for t, h in stores if t <= h]
    # Sort by altitude h
    valid_stores.sort(key=lambda x: x[1])
    # dp[i] = min time to visit i stores
    # Initialize with large number
    dp = [float('inf')] * (len(valid_stores) + 1)
    dp[0] = 0
    
    for t, h in valid_stores:
        # Iterate backwards to avoid using same store twice
        for j in range(len(valid_stores) - 1, -1, -1):
            if dp[j] + t <= h:
                dp[j+1] = min(dp[j+1], dp[j] + t)
    
    # Find max i where dp[i] is not inf
    for i in range(len(dp), -1, -1):
        if dp[i] != float('inf'):
            return i
    return 0

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_scheduling_module(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test parameters
    MAX_N = 16
    MAX_VAL = 255
    
    test_cases = [
        [(5, 8), (5, 6), (3, 4), (5, 13), (6, 10)],
        [(5, 10), (6, 15), (2, 7), (3, 3), (4, 11)],
        [(1, 1)] * 16, # Extreme case: 16 stores all valid
        [(100, 50)] * 5 # All invalid
    ]
    
    for stores in test_cases:
        n = len(stores)
        # Clamp values to fit hardware constraints
        clamped_stores = [(min(t, MAX_VAL), min(h, MAX_VAL)) for t, h in stores]
        
        expected = solve_python(clamped_stores)
        
        # 1. Input Phase
        # Host sets n
        dut.n.value = n
        await RisingEdge(dut.clk)
        
        # Host inputs stores one by one
        # We assume the DUT has an input interface like:
        # addr (4 bit), t_i (8 bit), h_i (8 bit), we_latch (1 bit)
        # Or simpler: The testbench drives signals while start is handled elsewhere.
        
        # Let's assume the interface described in the prompt:
        # The prompt implies a loading phase before start.
        # We will drive t_i, h_i, addr, and assume the DUT latches them when appropriate.
        # If the DUT is purely sequential processing during 'start', we need to queue inputs.
        # Let's assume the prompt means: Start initiates the process, and inputs are consumed sequentially by the DUT if valid, 
        # OR we load them into a buffer before start.
        
        # CORRECTION: The prompt says 'start' initiates calculation. 
        # This implies data must be loaded *before* start, or 'start' is held high while loading.
        # Given the complexity of streaming 16 items in 200 cycles, we can load them in a pre-amble.
        
        # Let's simulate a loading register interface if it exists, otherwise assume inputs are valid during start.
        # For this testbench, I will assume a standard synchronous RAM-like interface or a shift register interface.
        # To be safe and generic, I will use the signals: `t_i`, `h_i`, `addr`, `we` (write enable).
        
        if has_signal(dut, 'we'):
            for i, (t, h) in enumerate(clamped_stores):
                dut.addr.value = i
                dut.t_i.value = t
                dut.h_i.value = h
                dut.we.value = 1
                await RisingEdge(dut.clk)
                dut.we.value = 0
                await RisingEdge(dut.clk)
        else:
            # If no write enable, perhaps inputs are sampled when start is asserted.
            # This is tricky for a vector of inputs.
            # We will assume a shift-in interface for simplicity if not RAM-like.
            # Or, we drive inputs during the start process.
            # Given the prompt 'start: 1-cycle pulse to initiate calculation', 
            # we might need to feed data serially or have it pre-loaded.
            # Let's assume a pre-loaded buffer for simplicity in testing:
            # We will just assert inputs for one cycle and hope the DUT latches them in a loop.
            # Actually, let's look at the prompt again: `start` initiates. 
            # If the DUT is a pure FSM, it might read `n` and then read `n` pairs.
            pass
            
        # 2. Execution Phase
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f"Test failed for case {stores}: {e}")
            raise
            
        # 3. Check Result
        result = int(dut.result.value)
        cocotb.log.info(f"Input: {stores}, Expected: {expected}, Got: {result}")
        
        if result != expected:
            raise TestFailure(f"Mismatch for {stores}: Expected {expected}, got {result}")
            
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
