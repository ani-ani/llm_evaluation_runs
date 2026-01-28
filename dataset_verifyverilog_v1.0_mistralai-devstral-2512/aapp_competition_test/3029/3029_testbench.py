import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 2000
MODULO = 11092019

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

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, values, width):
    for i, v in enumerate(values):
        attr = getattr(dut, name)
        if hasattr(attr, '__len__'):
            attr[i].value = clamp_to_width(v, width)
        else:
            # Single signal, skip
            pass

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tree_dp(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (N, labels, parents, expected_len, expected_count, description)
    test_cases = [
        # Sample 1: All labels 3, chain 1-2-3-4-5
        (5, [3, 3, 3, 3, 3], [0, 1, 2, 3, 4], 5, 1, "All 3, chain"),
        # Sample 2: Decreasing labels, chain
        (5, [4, 3, 2, 1, 0], [0, 1, 2, 3, 4], 1, 5, "Decreasing chain"),
        # Sample 3: Labels 1,5,3,6 with parents 1,2,3
        (4, [1, 5, 3, 6], [0, 1, 2, 3], 3, 2, "Mixed labels"),
        # Sample 4: Linear 1-2-3-4-5-6, labels 1,2,3,4,5,6
        (6, [1, 2, 3, 4, 5, 6], [0, 1, 1, 1, 1, 1], 2, 5, "Linear chain")
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, labels, parents, exp_len, exp_count, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Write inputs
            dut.N.value = N
            
            # Write labels (pad to 16)
            padded_labels = labels + [0] * (16 - N)
            for j in range(16):
                dut.labels[j].value = clamp_to_width(padded_labels[j], 8)
            
            # Write parents (skip index 0, pad to 16)
            padded_parents = parents + [0] * (16 - len(parents))
            for j in range(1, 16):
                dut.parents[j].value = clamp_to_width(padded_parents[j], 4)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            result_len = int(dut.result_len.value)
            result_count = int(dut.result_count.value)
            
            cocotb.log.info(f"Got L={result_len}, M={result_count}")
            
            if result_len != exp_len:
                raise TestFailure(f"Length mismatch: expected {exp_len}, got {result_len}")
            if result_count != exp_count:
                raise TestFailure(f"Count mismatch: expected {exp_count}, got {result_count}")
            
            passed += 1
            cocotb.log.info(f"PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")