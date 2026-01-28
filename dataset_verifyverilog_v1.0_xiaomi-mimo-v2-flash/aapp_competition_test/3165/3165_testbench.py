import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants matching Verilog spec
MAX_N = 64
MAX_K = 16
MAX_P = 16
DATA_WIDTH = 6  # Power and Index width
ADDR_WIDTH = 6
RESULT_WIDTH = 16

# Helpers

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    if v < 0: return 0
    max_val = (1 << bits) - 1
    return min(max_val, v)

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'rook_r'): dut.rook_r.value = 0
    if has_signal(dut, 'rook_c'): dut.rook_c.value = 0
    if has_signal(dut, 'rook_x'): dut.rook_x.value = 0
    if has_signal(dut, 'move_r1'): dut.move_r1.value = 0
    if has_signal(dut, 'move_c1'): dut.move_c1.value = 0
    if has_signal(dut, 'move_r2'): dut.move_r2.value = 0
    if has_signal(dut, 'move_c2'): dut.move_c2.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done")

async def wait_for_ready(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.ready.value) and int(dut.ready.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for ready")

# Python Simulation for verification
def simulate_rook_attack(N, rooks, moves):
    row_xors = {}
    col_xors = {}
    # Initial setup
    for r, c, x in rooks:
        row_xors[r] = row_xors.get(r, 0) ^ x
        col_xors[c] = col_xors.get(c, 0) ^ x
    
    def calc_attacked():
        zr = 0
        for i in range(1, N + 1):
            if row_xors.get(i, 0) == 0:
                zr += 1
        zc = 0
        for i in range(1, N + 1):
            if col_xors.get(i, 0) == 0:
                zc += 1
        return N * (zr + zc) - 2 * zr * zc

    results = []
    results.append(calc_attacked())
    
    # We need to track rook positions to know what to remove
    # In the problem, we are given (r1,c1) which is the source of the move
    # The rook at (r1,c1) is moved to (r2,c2)
    # We need to know the power of the rook at (r1,c1)
    # The input format in the problem gives R,C,X for initial rooks, but moves only give coords.
    # Wait, the problem input for moves is (R1, C1, R2, C2). 
    # It does NOT provide the power. This implies the power is associated with the rook.
    # In the hardware spec, we assumed we pass power with the move? No, the problem says "rook has moved from (R1,C1) to (R2,C2)".
    # We need to track rook powers by position.
    rook_pos = {} # (r,c) -> x
    for r, c, x in rooks:
        rook_pos[(r,c)] = x
        
    for r1, c1, r2, c2 in moves:
        if (r1, c1) not in rook_pos:
            # Should not happen per problem statement
            continue
        x = rook_pos.pop((r1, c1))
        
        # Update XORs
        row_xors[r1] ^= x
        col_xors[c1] ^= x
        if row_xors.get(r1, 0) == 0 and r1 in row_xors: del row_xors[r1]
        if col_xors.get(c1, 0) == 0 and c1 in col_xors: del col_xors[c1]
        
        row_xors[r2] = row_xors.get(r2, 0) ^ x
        col_xors[c2] = col_xors.get(c2, 0) ^ x
        if row_xors.get(r2, 0) == 0 and r2 in row_xors: del row_xors[r2]
        if col_xors.get(c2, 0) == 0 and c2 in col_xors: del col_xors[c2]
        
        rook_pos[(r2, c2)] = x
        results.append(calc_attacked())
        
    return results

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rook_attacker_hardware(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test Case 1
    N = 2
    K = 2
    P = 2
    rooks = [(1, 1, 1), (2, 2, 1)]
    moves = [(2, 2, 2, 1), (1, 1, 1, 2)]
    
    # Run simulation for expected values
    exp_results = simulate_rook_attack(N, rooks, moves)
    
    # Start sequence
    if has_signal(dut, 'start'):
        dut.start.value = 1
        dut.N.value = N
        dut.K.value = K
        dut.P.value = P
        await RisingEdge(dut.clk)
        dut.start.value = 0
    else:
        # If no start, assume always ready
        pass
    
    # Load Rooks
    for r, c, x in rooks:
        await wait_for_ready(dut)
        dut.rook_r.value = r
        dut.rook_c.value = c
        dut.rook_x.value = x
        await RisingEdge(dut.clk)
    
    # Wait for initial result
    await wait_for_done(dut)
    res0 = int(dut.result.value)
    if res0 != exp_results[0]:
        raise TestFailure(f"Init result mismatch. Exp {exp_results[0]}, Got {res0}")
        
    # Process Moves
    for i, (r1, c1, r2, c2) in enumerate(moves):
        await wait_for_ready(dut)
        dut.move_r1.value = r1
        dut.move_c1.value = c1
        dut.move_r2.value = r2
        dut.move_c2.value = c2
        await RisingEdge(dut.clk)
        
        await wait_for_done(dut)
        res = int(dut.result.value)
        exp = exp_results[i+1]
        if res != exp:
            raise TestFailure(f"Move {i+1} result mismatch. Exp {exp}, Got {res}")
            
    # Test Case 2
    await reset_dut(dut)
    N = 2
    K = 2
    P = 2
    rooks = [(1, 1, 1), (2, 2, 2)]
    moves = [(2, 2, 2, 1), (1, 1, 1, 2)]
    exp_results = simulate_rook_attack(N, rooks, moves)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        dut.N.value = N
        dut.K.value = K
        dut.P.value = P
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
    for r, c, x in rooks:
        await wait_for_ready(dut)
        dut.rook_r.value = r
        dut.rook_c.value = c
        dut.rook_x.value = x
        await RisingEdge(dut.clk)
        
    await wait_for_done(dut)
    res0 = int(dut.result.value)
    if res0 != exp_results[0]:
        raise TestFailure(f"TC2 Init result mismatch. Exp {exp_results[0]}, Got {res0}")
        
    for i, (r1, c1, r2, c2) in enumerate(moves):
        await wait_for_ready(dut)
        dut.move_r1.value = r1
        dut.move_c1.value = c1
        dut.move_r2.value = r2
        dut.move_c2.value = c2
        await RisingEdge(dut.clk)
        
        await wait_for_done(dut)
        res = int(dut.result.value)
        exp = exp_results[i+1]
        if res != exp:
            raise TestFailure(f"TC2 Move {i+1} result mismatch. Exp {exp}, Got {res}")