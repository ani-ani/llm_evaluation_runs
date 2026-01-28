import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Include helpers
import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_file_deletion(dut):
    """
    Test the file deletion minimization module.
    """
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    
    # Helper to set icon data
    def set_icon(slot_idx, r, c, icon_type, valid=1):
        # Input is upper left. Center is r+7, c+4.
        # We assume module handles center calculation or we pass upper left.
        # Spec says: "Each pair r c specify upper left corner"
        # Module should take r, c (upper left) and type.
        # r/c are 16-bit.
        if has_signal(dut, f'icon_r_{slot_idx}'):
            dut.__getattr__(f'icon_r_{slot_idx}').value = clamp_to_width(r, 16)
            dut.__getattr__(f'icon_c_{slot_idx}').value = clamp_to_width(c, 16)
            dut.__getattr__(f'icon_t_{slot_idx}').value = icon_type
            dut.__getattr__(f'icon_v_{slot_idx}').value = valid
        elif has_signal(dut, 'icon_r'):
            # Packed array approach is harder in cocotb without VPI, so assume vector of structs or separate ports
            # If it's a single port array, we can't easily index if it's packed.
            # We'll assume separate ports for simplicity of testbench generation, 
            # or we use the helper logic for arrays.
            # Let's assume the prompt specified a standard interface.
            # If the module uses 'icon_valid' array:
            if has_signal(dut, 'icon_valid'):
                dut.icon_valid[slot_idx].value = valid
                dut.icon_r[slot_idx].value = clamp_to_width(r, 16)
                dut.icon_c[slot_idx].value = clamp_to_width(c, 16)
                dut.icon_t[slot_idx].value = icon_type
            else:
                # Fallback for scalars
                pass

    # Test Cases
    test_inputs = [
        {
            "screen": (80, 50),
            "delete": [(75, 5), (25, 20), (50, 35)],
            "keep": [(50, 5), (25, 35)],
            "expected": 2
        },
        {
            "screen": (100, 100),
            "delete": [(50, 50)],
            "keep": [(80, 80)],
            "expected": 0
        }
    ]

    for case in test_inputs:
        dut._log.info(f"Running test case: {case['delete']} vs {case['keep']}")
        
        # Reset inputs
        for i in range(16):
            set_icon(i, 0, 0, 0, 0)
        
        # Load inputs
        idx = 0
        for r, c in case['delete']:
            set_icon(idx, r, c, 1, 1)
            idx += 1
        for r, c in case['keep']:
            set_icon(idx, r, c, 0, 1)
            idx += 1
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            # Combinational
            await Timer(100, units='ns')
        
        # Wait for done
        max_cycles = 500000  # 2M cycles might take time, but cocotb timeout is 2s
        found = False
        for _ in range(max_cycles):
            if has_signal(dut, 'done'):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    found = True
                    break
            else:
                break
        
        if not found and has_signal(dut, 'done'):
             raise TestFailure("Timeout waiting for done")
             
        # Read result
        if has_signal(dut, 'min_moves'):
            res = int(dut.min_moves.value)
            dut._log.info(f"Result: {res}, Expected: {case['expected']}")
            if res != case['expected']:
                raise TestFailure(f"Mismatch: got {res}, expected {case['expected']}")
        
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)