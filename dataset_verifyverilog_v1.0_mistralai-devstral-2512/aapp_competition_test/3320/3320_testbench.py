import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 1000

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'config_valid'): dut.config_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def configure_edge(dut, u, v, w, cycle):
    """Configure a single edge with valid flag for one cycle"""
    if has_signal(dut, 'edge_u'):
        dut.edge_u.value = clamp_to_width(u, 4)
    if has_signal(dut, 'edge_v'):
        dut.edge_v.value = clamp_to_width(v, 4)
    if has_signal(dut, 'edge_w'):
        dut.edge_w.value = clamp_to_width(w, 8)
    if has_signal(dut, 'config_valid'):
        dut.config_valid.value = 1
    await RisingEdge(dut.clk)
    if has_signal(dut, 'config_valid'):
        dut.config_valid.value = 0

async def set_query(dut, src, dst):
    """Set source and destination for query"""
    if has_signal(dut, 'src'):
        dut.src.value = clamp_to_width(src, 3)
    if has_signal(dut, 'dst'):
        dut.dst.value = clamp_to_width(dst, 3)
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_magical_island(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - just run test
        pass
    
    # Test Case 1: Sample Input from problem
    # 4 cities, edges: 1-2(1), 1-2(3), 1-3(2), 1-4(1), 2-3(4), 2-4(4), 3-4(4)
    # Expected queries: 1->2=1, 1->3=2, 3->4=3
    # Scaled: cities 0-3, edges with weights 1,3,2,1,4,4,4
    
    test_cases = [
        {
            "desc": "Sample Graph 1",
            "edges": [
                (0, 1, 1),  # 1-2 weight 1
                (0, 1, 3),  # 1-2 weight 3
                (0, 2, 2),  # 1-3 weight 2
                (0, 3, 1),  # 1-4 weight 1
                (1, 2, 4),  # 2-3 weight 4
                (1, 3, 4),  # 2-4 weight 4
                (2, 3, 4),  # 3-4 weight 4
            ],
            "queries": [
                (0, 1, 1),  # 1->2 = 1
                (0, 2, 2),  # 1->3 = 2
                (2, 3, 3),  # 3->4 = 3 (path 3-1-4: 2|1 = 3)
            ]
        },
        {
            "desc": "Simple Path",
            "edges": [
                (0, 1, 1),  # 1-2
                (1, 2, 2),  # 2-3
                (2, 3, 4),  # 3-4
                (3, 4, 8),  # 4-5
                (4, 5, 16), # 5-6
                (5, 0, 32), # 6-1
            ],
            "queries": [
                (0, 3, 1|2|4),  # 1->4 = 1|2|4 = 7
                (1, 4, 2|4|8),  # 2->5 = 2|4|8 = 14
                (2, 5, 4|16|32), # 3->6 = 4|16|32 = 52
            ]
        }
    ]
    
    total_passed = 0
    total_failed = 0
    
    for test_idx, test in enumerate(test_cases):
        cocotb.log.info(f"\nRunning Test Case {test_idx+1}: {test['desc']}")
        
        if is_seq:
            await reset_dut(dut)
            
            # Configure edges
            cocotb.log.info(f"Configuring {len(test['edges'])} edges...")
            for u, v, w in test['edges']:
                await configure_edge(dut, u, v, w, 0)
            
            # Additional cycles to ensure all edges processed
            for _ in range(2):
                await RisingEdge(dut.clk)
            
            # Start computation
            cocotb.log.info("Starting computation...")
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for computation to complete
                try:
                    await wait_for_done(dut, MAX_CYCLES)
                    cocotb.log.info("Computation complete")
                except TestFailure as e:
                    cocotb.log.error(f"Computation failed: {e}")
                    total_failed += 1
                    continue
            else:
                # Combinational or single-cycle
                await Timer(100, units='ns')
        else:
            # Combinational module - assume ready
            await Timer(10, units='ns')
        
        # Process queries
        test_passed = True
        for src, dst, expected in test['queries']:
            cocotb.log.info(f"Query: City {src} -> City {dst} (Expected: {expected})")
            
            if is_seq:
                # Set query and wait for result
                if has_signal(dut, 'src') and has_signal(dut, 'dst'):
                    dut.src.value = clamp_to_width(src, 3)
                    dut.dst.value = clamp_to_width(dst, 3)
                    await RisingEdge(dut.clk)
                    await RisingEdge(dut.clk)  # Allow result to propagate
                else:
                    # If no query signals, result might be directly valid
                    await RisingEdge(dut.clk)
            else:
                # Combinational - input directly affects output
                if has_signal(dut, 'src') and has_signal(dut, 'dst'):
                    dut.src.value = clamp_to_width(src, 3)
                    dut.dst.value = clamp_to_width(dst, 3)
                    await Timer(1, units='ns')
            
            # Read result
            if is_value_defined(dut.result.value):
                result = int(dut.result.value)
                if result != expected:
                    cocotb.log.error(f"  FAILED: Got {result}, Expected {expected}")
                    test_passed = False
                    total_failed += 1
                else:
                    cocotb.log.info(f"  PASSED: Got {result}")
                    total_passed += 1
            else:
                cocotb.log.error("Result undefined")
                test_passed = False
                total_failed += 1
    
    # Check signals that should always exist
    if has_signal(dut, 'done'):
        if not is_value_defined(dut.done.value):
            cocotb.log.warning("Done signal undefined")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} out of {total_passed+total_failed} assertions failed")
    else:
        cocotb.log.info(f"\nAll {total_passed} assertions passed!")
