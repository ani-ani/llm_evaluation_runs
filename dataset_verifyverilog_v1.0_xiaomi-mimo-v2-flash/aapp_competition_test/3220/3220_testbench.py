import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 4  # p_i width
N = 8           # Fixed N for verilog
CLK_NS = 10
MAX_CYCLES = 2000

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

# Python reference solver
def solve_python(p_list):
    n = len(p_list)
    best_str = None
    
    # Iterate all 2^N combinations
    # mask bit 0 -> wizard 0, bit 1 -> wizard 1...
    # 0 -> L, 1 -> R
    for mask in range(1 << n):
        positions = set()
        valid = True
        current_str_chars = []
        
        for i in range(n):
            # Calculate position
            if (mask >> i) & 1:
                # R: clockwise
                pos = (i + p_list[i]) % n
                current_str_chars.append('R')
            else:
                # L: counter-clockwise
                # Note: Python % handles negatives correctly
                pos = (i - p_list[i]) % n
                current_str_chars.append('L')
            
            if pos in positions:
                valid = False
                break
            positions.add(pos)
        
        if valid:
            s = "".join(current_str_chars)
            if best_str is None or s < best_str:
                best_str = s
    
    return best_str

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_circle_dance(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    # Case 1: N=3, 1 1 1 -> LLL (All L: 0,0,0 is valid?)
    # W0: 0-1=-1=2, W1:1-1=0, W2:2-1=1. Pos 2,0,1 -> unique. Yes.
    # LLL is mask 0. Valid.
    # Case 2: 5 1 2 2 1 2 -> LLRLR
    # Case 3: 4 1 2 1 2 -> No dance
    
    test_cases = [
        ([1, 1, 1, 0, 0, 0, 0, 0], "LLL", "Simple 3 LLL"),
        ([1, 2, 2, 1, 2, 0, 0, 0], "LLRLR", "Example 2"),
        ([1, 2, 1, 2, 0, 0, 0, 0], None, "No dance 4")
    ]
    
    passed = 0
    failed = 0
    
    for i, (p_vals, expected_prefix, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running test {i+1}: {desc}")
        
        try:
            # Send inputs
            # Assuming inputs are p_0 to p_7
            for j in range(N):
                signal_name = f'p_{j}'
                val = p_vals[j] if j < len(p_vals) else 0
                if has_signal(dut, signal_name):
                    getattr(dut, signal_name).value = clamp_to_width(val, DATA_WIDTH)
            
            # Trigger
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational or simple timing
                await Timer(100, units='ns')
            
            # Check result
            if has_signal(dut, 'result'):
                res_val = int(dut.result.value)
                # Decode 64-bit packed ASCII
                # Result is 8 bytes, little-endian usually in Verilog packed arrays
                # or just bitwise. 
                # We expect 8 chars.
                decoded_chars = []
                for k in range(N):
                    # Extract byte k. Verilog packed [63:0] usually [63:56] is byte 7 or 0?
                    # Standard logic: data[7:0] is byte 0.
                    # We'll assume byte 0 is char 0 (Wizard 0).
                    byte = (res_val >> (k * 8)) & 0xFF
                    decoded_chars.append(chr(byte))
                
                result_str = "".join(decoded_chars)
                
                # Validate
                has_valid = has_signal(dut, 'valid')
                is_valid_signal = True
                if has_valid:
                    is_valid_signal = int(dut.valid.value) == 1
                    
                if expected_prefix is None:
                    if is_valid_signal:
                         raise TestFailure(f"Expected no dance, but found valid solution: {result_str}")
                else:
                    if not is_valid_signal:
                         raise TestFailure(f"Expected solution starting with {expected_prefix}, but got no dance")
                    
                    # Check if matches prefix (since exact lex check depends on N=8 logic)
                    # The python solver solves for N=8 with padded zeros.
                    python_sol = solve_python(p_vals + [0]*(8-len(p_vals)))
                    if python_sol is None:
                        python_sol = "no dance"
                    
                    if result_str != python_sol:
                        raise TestFailure(f"Mismatch. Expected {python_sol}, got {result_str}")
                
                passed += 1
            else:
                raise TestFailure("Signal 'result' not found")
                
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
        
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
