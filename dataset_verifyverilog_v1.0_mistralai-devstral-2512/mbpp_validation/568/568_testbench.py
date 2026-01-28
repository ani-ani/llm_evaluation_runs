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

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_empty_list(dut):
    # Setup
    CLK_NS = 10
    MAX_CYCLES = 200
    
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        (5, 5, "length=5"),
        (6, 6, "length=6"),
        (7, 7, "length=7")
    ]
    
    for i, (length, exp_len, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Set input
        if has_signal(dut, 'length'):
            dut.length.value = clamp_to_width(length, 4)
        
        # Start
        if has_signal(dut, 'clk'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done with timeout
            done_found = False
            for cycle in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                    if int(dut.done.value) == 1:
                        done_found = True
                        break
            
            if not done_found:
                raise TestFailure(f"Timeout waiting for done, length={length}")
        else:
            await Timer(100, units='ns')
        
        # Check results
        if not has_signal(dut, 'result'):
            raise TestFailure("result signal not found")
        
        # Check each expected empty dict (should be 0)
        errors = []
        for idx in range(exp_len):
            if has_signal(dut, f'result_{idx}'):
                val = int(getattr(dut, f'result_{idx}').value)
                if val != 0:
                    errors.append(f"result[{idx}] = {val} expected 0")
            elif has_signal(dut, 'result'):
                # For array, we need to access via indexing
                # Since cocotb doesn't support array indexing directly in all simulators,
                # we check if result exists as array
                try:
                    val = int(dut.result[idx].value)
                    if val != 0:
                        errors.append(f"result[{idx}] = {val} expected 0")
                except (IndexError, AttributeError):
                    pass
        
        if errors:
            raise TestFailure(f"Length {length}: " + ", ".join(errors))
        
        # Additional check: entries beyond length should be 0
        for idx in range(exp_len, 16):
            if has_signal(dut, f'result_{idx}'):
                val = int(getattr(dut, f'result_{idx}').value)
                if val != 0:
                    errors.append(f"result[{idx}] (extra) = {val} expected 0")
            elif has_signal(dut, 'result'):
                try:
                    val = int(dut.result[idx].value)
                    if val != 0:
                        errors.append(f"result[{idx}] (extra) = {val} expected 0")
                except (IndexError, AttributeError):
                    pass
        
        if errors:
            raise TestFailure(f"Length {length} extra entries: " + ", ".join(errors))
        
        cocotb.log.info(f"Test {i+1}: PASS")
