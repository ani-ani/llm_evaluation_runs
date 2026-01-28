import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16       # Weight width
NODE_WIDTH = 3        # 8 nodes
NUM_NODES = 8
MAX_EDGES = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TEST CASES (scaled from examples)
# ============================================================================
# Test case 1: nodes 0,3 are critical
test_case_1 = {
    "edges": [(0,1,100), (0,2,100), (1,3,100), (2,3,100)],
    "s": 0, "t": 3,
    "expected_mask": (1 << 0) | (1 << 3)
}
# Test case 2: nodes 0,3,6 are critical
test_case_2 = {
    "edges": [(0,1,100), (0,2,100), (1,3,100), (2,3,100),
               (3,4,100), (3,5,100), (4,6,100), (5,6,100)],
    "s": 0, "t": 6,
    "expected_mask": (1 << 0) | (1 << 3) | (1 << 6)
}

test_cases = [test_case_1, test_case_2]

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_critical_nodes(dut):
    """Test the critical nodes module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: s={tc['s']}, t={tc['t']}, edges={len(tc['edges'])}")
        
        try:
            # Configure graph
            dut.s.value = tc['s']
            dut.t.value = tc['t']
            dut.num_edges.value = len(tc['edges'])
            
            # Write edges to arrays
            for idx in range(MAX_EDGES):
                if idx < len(tc['edges']):
                    u, v, w = tc['edges'][idx]
                    # Handle both array and individual port styles
                    if hasattr(dut, 'u'):
                        dut.u[idx].value = u
                        dut.v[idx].value = v
                        dut.w[idx].value = w
                    else:
                        for port, val in [('u', u), ('v', v), ('w', w)]:
                            port_name = f'{port}{idx}'
                            if has_signal(dut, port_name):
                                getattr(dut, port_name).value = val
                else:
                    # Clear unused entries
                    if hasattr(dut, 'u'):
                        dut.u[idx].value = 0
                        dut.v[idx].value = 0
                        dut.w[idx].value = 0
                    else:
                        for port in ['u', 'v', 'w']:
                            port_name = f'{port}{idx}'
                            if has_signal(dut, port_name):
                                getattr(dut, port_name).value = 0
            
            await Timer(10, units='ns')
            
            # Run computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.mask.value):
                raise TestFailure("Mask is undefined (X/Z)")
            
            result = int(dut.mask.value)
            expected = tc['expected_mask']
            
            if result != expected:
                raise TestFailure(f"Expected mask {expected:08b}, got {result:08b}")
            
            cocotb.log.info(f"  PASS: mask = {result:08b}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")