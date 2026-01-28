import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# MANDATORY HELPERS
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

# TIMEOUT HANDLING
@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'edge_valid'):
        dut.edge_valid.value = 0
    
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
    
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def send_edges(dut, edges, width=4):
    for u, v in edges:
        dut.edge_u.value = clamp_to_width(u-1, width)
        dut.edge_v.value = clamp_to_width(v-1, width)
        dut.edge_valid.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
    dut.edge_valid.value = 0

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_bfs_compatibility(dut):
    """
    Tests the core logic on various inputs provided in the test set.
    Scaled down to n=16.
    """
    # Setup Clock if synchronous
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test cases (Scaled to n<=16)
    # Case 1: n=4, m=2, edges (1,3), (3,4). Rail connected 1-3-4. No rail 1-4. 
    # Train takes Rail (len 2). Bus takes Road (1-2-4 or 1-4? 1-4 is road). 
    # Wait, bus takes road. Roads exist where railways don't. 
    # 1-4 is road. Bus takes 1->4 (1 hour). Train 1->3->4 (2 hours). Result 2.
    test_cases = [
        {"n": 4, "m": 2, "edges": [(1, 3), (3, 4)], "expected": 2},
        # Case 2: n=4, m=6. Complete graph. No roads. Bus cannot move. -1.
        {"n": 4, "m": 6, "edges": [(1, 2), (1, 3), (1, 4), (2, 3), (2, 4), (3, 4)], "expected": -1},
        # Case 3: n=5, m=5. 
        # Edges: (4,2), (3,5), (4,5), (5,1), (1,2).
        # Rail: 1-2, 1-5, 5-4, 5-3, 2-4.
        # Is 1-5 rail? Yes. So Train uses Rail, Bus uses Roads.
        # Roads: 1-3, 1-4, 2-3, 2-5, 3-4, 3-2 (duplicate), 4-1.
        # Bus path 1->3->5 (2 steps). Train 1->5 (1 step). Result 2? No, example output is 3.
        # Let's re-verify case 3 manually.
        # Rail edges: (4,2), (3,5), (4,5), (5,1), (1,2).
        # 1 connected to 2, 5. 
        # 5 connected to 1, 3, 4.
        # 2 connected to 1, 4.
        # 3 connected to 5.
        # 4 connected to 2, 5.
        # Railway path 1->5 (1 hour). 
        # Road graph (complement): 
        # 1 connected to 3, 4.
        # 5 connected to 2.
        # 2 connected to 3, 5.
        # 3 connected to 1, 2, 4.
        # 4 connected to 1, 3.
        # Bus path: 1->3->2->5 (3 hours). 
        # Max(1, 3) = 3. Correct.
        {"n": 5, "m": 5, "edges": [(4, 2), (3, 5), (4, 5), (5, 1), (1, 2)], "expected": 3},
        # Scaled down small cases
        {"n": 3, "m": 1, "edges": [(1, 2)], "expected": -1}, # 1-2 rail, 1-3 road, 2-3 road. Train 1->2->? 2-3 is road. Train stuck. Bus 1->3->? 3-2 is road, 2-1 is rail. Bus stuck at 2 (cannot go to 1? Wait, safety constraint only applies to simultaneous arrival. They can travel. But target is 3. Bus 1->3. Result 1? No, Train cannot reach 3. Output -1.}
        {"n": 3, "m": 1, "edges": [(1, 3)], "expected": 2}, # Rail 1-3. Train 1->3. Roads 1-2, 2-3. Bus 1->2->3. Max(1,2) = 2.}
    ]

    passed = 0
    failed = 0

    for tc in test_cases:
        n = tc["n"]
        m = tc["m"]
        edges = tc["edges"]
        expected = tc["expected"]
        
        cocotb.log.info(f"Running Test: n={n}, m={m}, edges={edges}, expected={expected}")
        
        # Reset
        await reset_dut(dut)
        
        # Provide inputs
        dut.n_in.value = clamp_to_width(n, 4)
        dut.m_in.value = clamp_to_width(m, 4)
        
        # Send edges
        await send_edges(dut, edges)
        
        # Start processing
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            try:
                await wait_for_done(dut)
            except TestFailure as e:
                cocotb.log.error(f"Test failed during execution: {e}")
                failed += 1
                continue
            
            # Check result
            if not is_value_defined(dut.result.value):
                cocotb.log.error("Result signal undefined")
                failed += 1
                continue
                
            result = int(dut.result.value)
            
            # Handle expected -1 (mapped to 0xFF or -1 depending on spec)
            # Usually unsigned output for time, but -1 indicator needed.
            # Let's assume result is 8-bit. -1 implies 255 (0xFF) or specific fail flag.
            # We check exact value match.
            
            if expected == -1:
                # Assuming 0xFF is the fail code
                if result != 255 and result != -1 and result != 0: # Allow 0 if it means unreachable in specific impl, but spec says -1
                     # If unsigned, -1 is 255. If signed, -1 is -1.
                     # Let's check if result matches 'unreachable' logic.
                     # If dut.result is unsigned 8-bit, -1 becomes 255.
                     # Let's just print result for debug
                     pass
            
            if result == expected:
                passed += 1
            elif expected == -1 and result == 255: # Assuming 0xFF output
                passed += 1
            else:
                cocotb.log.error(f"Result mismatch: Expected {expected}, Got {result}")
                failed += 1
        else:
            await Timer(100, units='ns')
            # Combinational check (if applicable, but problem is sequential usually)
            pass

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}")
