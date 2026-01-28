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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_edges(edges):
    """Pack list of (u,v) pairs into 32x10-bit edge array"""
    result = 0
    for i, (u, v) in enumerate(edges):
        u_val = u if u >= 0 else 16
        v_val = v if v >= 0 else 16
        result |= ((u_val << 5) | v_val) << (i * 10)
    return result

async def write_edges(dut, edges):
    """Write edges to module"""
    for i, (u, v) in enumerate(edges):
        # Each edge is packed as 10 bits in the 32x10 array
        edge_idx = i // 2
        edge_word = getattr(dut, 'edges')[edge_idx]
        u_val = u if u >= 0 else 16
        v_val = v if v >= 0 else 16
        if i % 2 == 0:
            edge_word.value = ((u_val << 5) | v_val)
        else:
            edge_word.value |= (((u_val << 5) | v_val) << 5)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_door_security(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # Sample 1: 2 rooms, 3 edges
        {
            "N": 2,
            "edges": [(-1, 0), (-1, 1), (0, 1)],
            "exp": 0,
            "desc": "Two rooms both directly connected to outside"
        },
        # Sample 2: 6 rooms, 8 edges
        {
            "N": 6,
            "edges": [(-1, 0), (-1, 1), (0, 1), (1, 2), (2, 3), (3, 4), (2, 4), (1, 5)],
            "exp": 3,
            "desc": "Protect 3 rooms (2,3,4) by removing (1,2)"
        }
    ]
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        cocotb.log.info(f"Test: {test['desc']}")
        
        # Reset before each test
        await reset_dut(dut)
        
        try:
            # Write inputs
            dut.N.value = clamp_to_width(test['N'], 4)
            dut.valid_edges.value = clamp_to_width(len(test['edges']), 5)
            
            # Write edges - for simplicity, assume edges[0:15] as 16x10-bit array
            # This handles up to 16 edges; adjust if more needed
            for i in range(min(len(test['edges']), 16)):
                u, v = test['edges'][i]
                u_val = u if u >= 0 else 16
                v_val = v if v >= 0 else 16
                edge_val = (u_val << 5) | v_val
                if has_signal(dut, f'edges_{i}'):
                    getattr(dut, f'edges_{i}').value = edge_val
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            result = int(dut.result.value) if is_value_defined(dut.result.value) else -1
            exp = test['exp']
            
            if result == exp:
                cocotb.log.info(f"PASS: Got {result}, expected {exp}")
                passed += 1
            else:
                cocotb.log.error(f"FAIL: Got {result}, expected {exp}")
                failed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_edge_case(dut):
    """Test with single room and single door to outside"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    dut.N.value = 1
    dut.valid_edges.value = 1
    if has_signal(dut, 'edges_0'):
        getattr(dut, 'edges_0').value = (16 << 5) | 0  # outside to room 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = int(dut.result.value) if is_value_defined(dut.result.value) else -1
    if result != 0:
        raise TestFailure(f"Single room should yield 0, got {result}")
    cocotb.log.info("PASS: Edge case handled correctly")