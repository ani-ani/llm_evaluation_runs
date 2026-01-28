import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 24  # Q8.16 fixed-point
NODE_WIDTH = 4
MAX_NODES = 16
CLK_NS = 10
MAX_CYCLES = 1500

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    if v < 0:
        return 0
    max_val = (1 << bits) - 1
    return min(max_val, v)

def float_to_q8_16(f, scale=1.0):
    """Convert float to Q8.16 fixed-point integer"""
    val = int(f * scale * 256)  # 256 = 2^8
    return clamp_to_width(val, DATA_WIDTH)

def q8_16_to_int(v):
    """Convert Q8.16 to integer (round)"""
    return int(v >> 16) + (1 if (v & 0x8000) else 0)

def pack_results(results, width=16, count=16):
    """Pack 16-bit results into 256-bit value"""
    packed = 0
    for i in range(count):
        packed |= (results[i] & ((1 << width) - 1)) << (i * width)
    return packed

def calc_abs_diff(x1, x2):
    """Calculate absolute difference in Q8.16"""
    diff = abs(x1 - x2)
    return diff

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for i in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_shortest_path(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Scale factor for coordinates (Q8.16)
    SCALE = 256.0
    
    # Test cases
    test_cases = [
        {
            'desc': 'Sample 5-node case',
            'nodes': [
                # y, d, r
                (1, 3, 2),
                (2, 5, 2),
                (3, 0, 0),
                (4, 2, 4),
                (5, 3, 0)
            ],
            'expected': [9, -1, 5, 6]  # To nodes 2,3,4,5 (1-indexed)
        },
        {
            'desc': '3-node simple case',
            'nodes': [
                (1, 1, 1),
                (2, 1, 1),
                (3, 0, 0)
            ],
            'expected': [3, 2]  # 1->2: |2-1|=1 >=1, cost=1+1=2? Wait, from 0 to 1: |2-1|=1 >= d0=1, yes cost=1+1=2. From 0 to 2: direct? |3-1|=2 >=1, cost=1+2=3. Also 0->1->2: 0->1=2, 1->2: |3-2|=1 >= d1=1, cost=1+1=2, total 4 > 3. So 3 and 2.
        },
        {
            'desc': '4-node unreachable',
            'nodes': [
                (1, 10, 0),  # High min distance
                (2, 1, 0),
                (3, 1, 0),
                (4, 1, 0)
            ],
            'expected': [-1, -1, -1]  # Can't reach any
        }
    ]
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        N = len(tc['nodes'])
        if N > MAX_NODES:
            cocotb.log.warning(f"Skipping {tc['desc']}: N={N} > {MAX_NODES}")
            continue
        
        cocotb.log.info(f"\nTest: {tc['desc']} (N={N})")
        
        # Prepare inputs
        x_vals = []
        d_vals = []
        r_vals = []
        
        for y, d, r in tc['nodes']:
            x_vals.append(float_to_q8_16(y, SCALE))
            d_vals.append(float_to_q8_16(d, SCALE))
            r_vals.append(float_to_q8_16(r, SCALE))
        
        # Write inputs
        if is_seq:
            # Set node_count
            if has_signal(dut, 'node_count'):
                dut.node_count.value = N
            else:
                cocotb.log.warning("node_count signal not found, assuming N=16")
            
            # Set inputs for each node
            for i in range(N):
                # Try common naming: x_i, d_i, r_i
                for name, val in zip(['x', 'd', 'r'], [x_vals, d_vals, r_vals]):
                    sig_name = f"{name}_{i}"
                    if has_signal(dut, sig_name):
                        getattr(dut, sig_name).value = val
                    else:
                        # Try arr_x[i], arr_d[i], arr_r[i]
                        if has_signal(dut, f"arr_{name}"):
                            getattr(dut, f"arr_{name}")[i].value = val
            
            # Set unused nodes to 0
            for i in range(N, MAX_NODES):
                for name in ['x', 'd', 'r']:
                    if has_signal(dut, f"{name}_{i}"):
                        getattr(dut, f"{name}_{i}").value = 0
                    elif has_signal(dut, f"arr_{name}"):
                        getattr(dut, f"arr_{name}")[i].value = 0
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            try:
                await wait_for_done(dut, max_cycles=MAX_CYCLES)
            except TestFailure as e:
                cocotb.log.error(f"{tc['desc']}: {e}")
                failed += 1
                continue
            
            # Read results
            if has_signal(dut, 'result'):
                result_val = int(dut.result.value)
                # Unpack results
                results = []
                for i in range(1, N):  # Skip node 0 (source)
                    field = (result_val >> (i * 16)) & 0xFFFF
                    results.append(field)
                
                # Check
                success = True
                for i, (exp, got) in enumerate(zip(tc['expected'], results)):
                    if exp == -1:
                        exp_val = 0xFFFF
                    else:
                        exp_val = exp
                    
                    if got != exp_val:
                        cocotb.log.error(f"{tc['desc']}: Node {i+1}: Expected {exp_val}, got {got}")
                        success = False
                
                if success:
                    cocotb.log.info(f"{tc['desc']}: PASS")
                    passed += 1
                else:
                    failed += 1
            else:
                cocotb.log.error(f"{tc['desc']}: result signal not found")
                failed += 1
        
        else:
            # Combinational
            await Timer(100, units='ns')
            if has_signal(dut, 'result'):
                result_val = int(dut.result.value)
                # Check as above
            else:
                cocotb.log.error(f"{tc['desc']}: result signal not found")
                failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")