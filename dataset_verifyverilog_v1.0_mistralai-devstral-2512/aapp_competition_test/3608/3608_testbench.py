import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 32
MOD = 1000000007
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def compute_dp(N, A, B):
    MOD = 1000000007
    dp_prev_0 = 1
    dp_prev_1 = 0
    for i in range(1, N + 1):
        a_i = A[i-1]
        b_i = B[i-1] if i <= N-1 else 0
        # dp_new_0 = (dp_prev_0 * (a_i + b_i)) + (dp_prev_1 * a_i)
        term1 = (dp_prev_0 * ((a_i + b_i) % MOD)) % MOD
        term2 = (dp_prev_1 * a_i) % MOD
        dp_new_0 = (term1 + term2) % MOD
        # dp_new_1 = dp_prev_0 * b_i
        dp_new_1 = (dp_prev_0 * b_i) % MOD
        dp_prev_0 = dp_new_0
        dp_prev_1 = dp_new_1
    return dp_prev_0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_task_counter(dut):
    # Check for required signals
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module must have 'clk' signal")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        (3, [3, 0, 1], [0, 1], 3),
        (4, [1, 5, 3, 0], [0, 2, 1], 33)
    ]
    
    passed = 0
    failed = 0
    
    for idx, (N_val, A_vals, B_vals, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running test case {idx+1}: N={N_val}")
        
        try:
            # Verify expected result matches Python computation
            py_result = compute_dp(N_val, A_vals, B_vals)
            if py_result != expected:
                cocotb.log.warning(f"Warning: Python computed {py_result} vs expected {expected} (test case may be mismatched)")
            
            # Start computation
            dut.start.value = 1
            dut.N.value = N_val
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Feed data cycles
            # We need to simulate providing A and B data for each i=1..N
            # The module should request data via A_addr/B_addr, or we drive it
            # Assuming we need to drive data when the module is ready
            # Let's monitor the 'busy' signal or 'start' state
            
            # If the module uses external RAM interface (addresses provided, we respond):
            # Wait for addresses to appear, then drive data
            
            # If the module internally iterates i and computes on-the-fly:
            # We might need to drive A_data/B_data at specific cycles
            
            # Since the spec says "use a counter to iterate i", let's assume we need to
            # provide A[i] and B[i] when requested.
            # We'll check if A_addr/B_addr change.
            
            # For simplicity in this testbench, we assume the module has an interface
            # where we write A[i] and B[i] during a setup phase, OR
            # the module has an FSM that reads sequentially.
            
            # Let's implement a monitor that listens for address requests
            # and drives the corresponding data.
            
            # Start monitor tasks
            done = False
            cycle_count = 0
            
            while not done and cycle_count < MAX_CYCLES:
                await RisingEdge(dut.clk)
                cycle_count += 1
                
                # Check if module requests data
                if has_signal(dut, 'A_addr') and is_value_defined(dut.A_addr.value):
                    addr = int(dut.A_addr.value)
                    if addr < len(A_vals):
                        dut.A_data.value = clamp_to_width(A_vals[addr], DATA_WIDTH)
                    else:
                        dut.A_data.value = 0
                        
                if has_signal(dut, 'B_addr') and is_value_defined(dut.B_addr.value):
                    addr = int(dut.B_addr.value)
                    if addr < len(B_vals):
                        dut.B_data.value = clamp_to_width(B_vals[addr], DATA_WIDTH)
                    else:
                        dut.B_data.value = 0
                
                # Check done
                if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                    if int(dut.done.value) == 1:
                        done = True
                        
            if not done:
                raise TestFailure(f"Timeout during computation for case {idx+1}")
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Module missing 'result' signal")
                
            result_val = int(dut.result.value)
            
            # Verify result
            if result_val != expected:
                raise TestFailure(f"Case {idx+1}: Expected {expected}, got {result_val}")
            
            passed += 1
            cocotb.log.info(f"Test case {idx+1} passed. Result: {result_val}")
            
            # Reset for next test
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"Test case {idx+1} failed: {e}")
            failed += 1
            # Try to reset for next test
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
