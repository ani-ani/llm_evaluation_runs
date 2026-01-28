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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_heap_subset(dut):
    CLK_NS = 10
    MAX_CYCLES = 200
    NODES = 8
    VAL_WIDTH = 8
    IDX_WIDTH = 3
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Define test cases: (val_list, parent_list, expected_result)
    # Test case 1: Sample 1 - All same values (result=1)
    test_cases = [
        ([3, 3, 3, 3, 3, 0, 0, 0], [0, 1, 2, 3, 4, 0, 0, 0], 1),
        ([4, 3, 2, 1, 0, 0, 0, 0], [0, 1, 2, 3, 4, 0, 0, 0], 5),
        ([3, 1, 2, 3, 4, 5, 0, 0], [0, 1, 1, 1, 1, 1, 0, 0], 5),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (vals, parents, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: vals={vals[:6]}, parents={parents[:6]}, expected={expected}")
        
        # Write inputs
        for i in range(NODES):
            if i < len(vals):
                dut.val[i].value = clamp_to_width(vals[i], VAL_WIDTH)
                dut.parent[i].value = clamp_to_width(parents[i], IDX_WIDTH)
            else:
                dut.val[i].value = 0
                dut.parent[i].value = 0
        
        if has_signal(dut, 'clk'):
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done_found = False
            for cycle in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_found = True
                    break
            
            if not done_found:
                cocotb.log.error(f"Timeout waiting for done")
                failed += 1
                continue
            
            # Read result
            if not is_value_defined(dut.result.value):
                cocotb.log.error("Result undefined")
                failed += 1
                continue
            
            result = int(dut.result.value)
            if result != expected:
                cocotb.log.error(f"Expected {expected}, got {result}")
                failed += 1
            else:
                passed += 1
        else:
            await Timer(100, units='ns')
            result = safe_int(dut.result.value, 0)
            if result != expected:
                cocotb.log.error(f"Expected {expected}, got {result}")
                failed += 1
            else:
                passed += 1
    
    cocotb.log.info(f"Passed: {passed}, Failed: {failed}")
    if failed:
        raise TestFailure(f"{failed} tests failed")
