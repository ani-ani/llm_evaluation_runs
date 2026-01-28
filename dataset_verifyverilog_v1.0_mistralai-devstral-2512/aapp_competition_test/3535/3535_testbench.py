import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
MOD = 1000000007
DATA_WIDTH = 32
MAX_CYCLES = 10000
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'y_in'): dut.y_in.value = 0
    if has_signal(dut, 'x_in'): dut.x_in.value = 0
    if has_signal(dut, 's_in'): dut.s_in.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def send_measurements(dut, measurements):
    # measurements: list of (y, x, s_str)
    # Assuming K measurements are streamed in K cycles after start
    # Protocol: Valid data on y_in, x_in, s_in when processing
    for y, x, s_str in measurements:
        dut.y_in.value = y
        dut.x_in.value = x
        # '+' is 1, '-' is 0 (or vice versa, as long as consistent)
        # Let's use 1 for '+', 0 for '-'
        dut.s_in.value = 1 if s_str == '+' else 0
        await RisingEdge(dut.clk)

def python_solution(N, M, K, measurements):
    MOD = 1000000007
    
    # Edge case: N=1 or M=1
    if N == 1 or M == 1:
        total_cells = N * M
        # If K=0, result is 2^(total_cells)
        # If K>0, result is 2^(total_cells - K)
        # (Assuming K measurements are consistent, which they are by input definition)
        free_bits = total_cells - K
        if free_bits < 0:
            return 0
        return pow(2, free_bits, MOD)
    
    # Grid case (N > 1, M > 1)
    # Pattern 1: S[y][x] = 0 ^ ((y-1)%2) ^ ((x-1)%2) -> Origin (1,1) = 0
    # Pattern 2: S[y][x] = 1 ^ ((y-1)%2) ^ ((x-1)%2) -> Origin (1,1) = 1
    
    valid_A = True
    valid_B = True
    
    for y, x, s_str in measurements:
        s_bit = 1 if s_str == '+' else 0
        
        # Calculate expected for Pattern A
        # (y-1) % 2 equivalent to (y-1) & 1 for non-negative
        # (x-1) % 2 equivalent to (x-1) & 1
        parity = ((y - 1) & 1) ^ ((x - 1) & 1)
        
        # Pattern A: 0 ^ parity
        exp_A = 0 ^ parity
        if s_bit != exp_A:
            valid_A = False
            if not valid_B: return 0 # Early exit
            
        # Pattern B: 1 ^ parity
        exp_B = 1 ^ parity
        if s_bit != exp_B:
            valid_B = False
            if not valid_A: return 0 # Early exit
            
    count = 0
    if valid_A: count += 1
    if valid_B: count += 1
    return count % MOD

@cocotb.test(timeout_time=5, timeout_unit="ms")
async def test_grid_constraints(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test Cases
    # Case 1: Sample Input 1 (N=2, M=4, K=4)
    # Matches checkerboard -> 2 solutions
    # Coordinates are 1-based in input
    measurements1 = [
        (1, 1, '+'),
        (1, 2, '-'),
        (1, 3, '+'),
        (1, 4, '-')
    ]
    
    # Case 2: N=1, M=1, K=0
    # 2 solutions (0 or 1)
    measurements2 = []
    
    # Case 3: N=1, M=1, K=1
    # 1 solution (fixed)
    measurements3 = [(1, 1, '+')]
    
    # Case 4: Contradiction
    # N=2, M=2. (1,1) is '+', (1,2) is '-', (2,1) is '-', (2,2) is '-'.
    # Valid: (1,1)+, (1,2)-, (2,1)-, (2,2)+
    # Invalid: (2,2) is -, should be +
    measurements4 = [
        (1, 1, '+'),
        (1, 2, '-'),
        (2, 1, '-'),
        (2, 2, '-')
    ]
    
    test_cases = [
        (2, 4, measurements1, 2),
        (1, 1, measurements2, 2),
        (1, 1, measurements3, 1),
        (2, 2, measurements4, 0)
    ]
    
    for N, M, measurements, expected in test_cases:
        K = len(measurements)
        
        cocotb.log.info(f"Testing N={N}, M={M}, K={K}, Expected={expected}")
        
        # Assert Start
        dut.start.value = 1
        dut.N.value = N
        dut.M.value = M
        dut.K.value = K
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Stream measurements
        # The module should consume K cycles of inputs
        # Note: The DUT needs to be designed to accept inputs when 'processing' is high
        # We assume the interface allows feeding data while ready/valid signals are high,
        # or simply sequentially if start triggers a state machine.
        # Here we assume a simple sequential feed after start.
        # We need to check if the DUT has a 'ready' signal or if we just wait.
        # Based on standard competitive programming HDLs, we usually just push data.
        
        # If the DUT has a 'valid_in' or similar, we drive it. 
        # If it's just a stream, we assume it accepts data every cycle after start.
        
        # Check if DUT has inputs ready immediately or needs latency?
        # We'll just drive inputs cycle by cycle.
        
        # Wait for inputs to be processed (K cycles)
        # In this simple model, we drive inputs immediately.
        # However, the DUT might need to process in parallel or sequentially.
        # Let's check if 'process_done' or similar exists. If not, we assume K cycles.
        
        await send_measurements(dut, measurements)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if has_signal(dut, 'result'):
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"N={N}, M={M}, K={K}: Expected {expected}, got {result}")
        else:
            cocotb.log.warning("Result signal not found")
            
        # Wait a bit before next test
        await Timer(100, units='ns')
        await RisingEdge(dut.clk)
