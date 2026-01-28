import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
N = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

def pack_assignments(permutations, N=4):
    """Pack list of permutations into 48-bit integer."""
    result = 0
    for p, perm in enumerate(permutations):
        for b in range(N):
            value = perm[b]
            bits = value & 0b111  # 3 bits
            shift = (p * N + b) * 3
            result |= bits << shift
    return result

# Main test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_maximum_disjoint_matchings(dut):
    """Test the maximum_disjoint_matchings module."""
    
    # Start clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: All Y (16'hFFFF)
    adj_flat1 = 0xFFFF
    k1 = 4
    perms1 = [
        [1,2,3,4],
        [2,3,4,1],
        [3,4,1,2],
        [4,1,2,3]
    ]
    packed1 = pack_assignments(perms1, N)
    
    # Test case 2: Specific matrix (16'h9363)
    # Cycle graph: person0->buttons0,1; person1->buttons1,2; person2->buttons2,3; person3->buttons3,0
    adj_flat2 = 0x9363
    k2 = 2
    perms2 = [
        [1,2,3,4],
        [2,3,4,1]
    ]
    packed2 = pack_assignments(perms2, N)
    
    test_cases = [
        (adj_flat1, k1, packed1, "All Y"),
        (adj_flat2, k2, packed2, "Cycle graph"),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (adj_flat, expected_k, expected_packed, desc) in enumerate(test_cases):
        dut._log.info(f"Test {idx+1}: {desc}")
        
        # Set adjacency matrix
        dut.adj_flat.value = adj_flat
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
            continue
        
        # Read outputs
        if not is_value_defined(dut.k.value):
            dut._log.error("  FAIL: k is undefined (X/Z)")
            failed += 1
            continue
        
        if not is_value_defined(dut.assignments_packed.value):
            dut._log.error("  FAIL: assignments_packed is undefined (X/Z)")
            failed += 1
            continue
        
        k = int(dut.k.value)
        packed = int(dut.assignments_packed.value)
        
        # Compare
        if k != expected_k:
            dut._log.error(f"  FAIL: k mismatch: expected {expected_k}, got {k}")
            failed += 1
            continue
        
        if packed != expected_packed:
            dut._log.error(f"  FAIL: assignments_packed mismatch: expected {expected_packed:012x}, got {packed:012x}")
            failed += 1
            continue
        
        dut._log.info(f"  PASS: k={k}, assignments_packed=0x{packed:012X}")
        passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")