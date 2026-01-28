import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# --- Helpers ---
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
    return min((1 << bits) - 1, max(0, v))

# --- Main Test ---
@cocotb.test(timeout_time=10000, timeout_unit='ms')
async def test_exploding_kittens(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        await Timer(100, units='ns')
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    
    # Test cases scaled for 16-bit limits (max pos ~65000)
    test_cases = [
        # Case 1: Simple 2 player, 4K, 3D. Output 0.
        {
            'N': 2, 'E': 4, 'D': 3,
            'e_locs': [3, 4, 5, 7],
            'd_locs': [1, 2, 10],
            'exp': 0
        },
        # Case 2: 3 players, 5K, 2D. Output 2.
        {
            'N': 3, 'E': 5, 'D': 2,
            'e_locs': [1, 4, 7, 9, 11],
            'd_locs': [2, 3],
            'exp': 2
        },
        # Case 3: 3 players, 3K, 2D. Output -1 (31).
        {
            'N': 3, 'E': 3, 'D': 2,
            'e_locs': [1, 4, 7],
            'd_locs': [2, 3],
            'exp': 31 # -1 mapped to 31
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"--- Running Test Case {i+1} ---")
        
        # Write Inputs
        dut.start.value = 1
        dut.N.value = tc['N']
        dut.E.value = tc['E']
        dut.D.value = tc['D']
        
        # Write Arrays (Individual Elements)
        # Assuming ports are indexed or unpacked. 
        # If packed, we would pack, but usually HDL simulators handle unpacked arrays naturally.
        # We'll check for 'e_locs_0' style or 'e_locs[0]' style.
        
        # Helper to set array
        def set_array(name, vals, width=16):
            for idx, val in enumerate(vals):
                # Try unpacked port name style first (e.g., e_locs_0)
                if has_signal(dut, f"{name}_{idx}"):
                    getattr(dut, f"{name}_{idx}").value = clamp_to_width(val, width)
                # Try packed array index style
                elif has_signal(dut, name):
                    try:
                        dut.__getattr__(name)[idx].value = clamp_to_width(val, width)
                    except (AttributeError, IndexError):
                        pass

        set_array('e_locs', tc['e_locs'])
        set_array('d_locs', tc['d_locs'])
        
        # Edge: If arrays are static inputs, we might need to toggle clock to latch
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        
        dut.start.value = 0
        
        # Wait for done
        if has_signal(dut, 'done'):
            max_cycles = 2048
            found = False
            for _ in range(max_cycles):
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                else:
                    await Timer(100, units='ns')
                
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    found = True
                    break
            
            if not found:
                raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        else:
            # Combinational logic fallback
            await Timer(500, units='ns')

        # Check Result
        if is_value_defined(dut.result.value):
            res = int(dut.result.value)
            # Allow 31 for -1 or exact match
            if res == tc['exp'] or (tc['exp'] == -1 and res == 31):
                cocotb.log.info(f"Test {i+1}: PASS (Result={res})")
            else:
                raise TestFailure(f"Test {i+1}: FAIL. Expected {tc['exp']}, got {res}")
        else:
            raise TestFailure(f"Test {i+1}: Result signal undefined")

    cocotb.log.info("All tests passed!")
