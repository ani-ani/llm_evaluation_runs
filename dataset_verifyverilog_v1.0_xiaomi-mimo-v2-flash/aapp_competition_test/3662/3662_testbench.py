import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 14  # Max 10000 fits in 14 bits
N_WIDTH = 5
MAX_N = 32
CLK_NS = 10
MAX_CYCLES = 10000

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
    # Ensure positive for masking, handle negative if needed by caller
    return v & ((1 << bits) - 1)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_tree_avenue(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational logic
        await Timer(10, units='ns')

    # Helper to write array
    def write_arr(dut, vals):
        for i, v in enumerate(vals):
            # Ensure v fits in DATA_WIDTH
            v_clamped = v & ((1 << DATA_WIDTH) - 1)
            if has_signal(dut, f'pos_{i}'):
                getattr(dut, f'pos_{i}').value = v_clamped
            elif hasattr(dut, 'pos') and hasattr(dut.pos, 'value'):
                 # This is likely a packed array or structure, handling specific implementation
                 pass
            else:
                # Try to access as list of signals
                try:
                    dut.pos[i].value = v_clamped
                except Exception:
                    pass

    # Test Cases
    # Case 1: N=4, L=10, W=1, positions [1, 0, 10, 10]
    # Sorted: [0, 1, 10, 10]
    # Pairs: (0, 1) and (2, 3)
    # Tx[0] = 0, Tx[1] = 10
    # Pair 0 (Tx=0): trees 0,1. Option A: 0->Left(0), 1->Right(0). Costs: |0-0| + sqrt((1-0)^2+1) = 0 + sqrt(2) = 1.414
    # Option B: 1->Left(0), 0->Right(0). Costs: |1-0| + sqrt((0-0)^2+1) = 1 + 1 = 2. 
    # Min 1.414
    # Pair 1 (Tx=10): trees 2,3. Option A: 2->Left(10), 3->Right(10). Costs: |10-10| + sqrt((10-10)^2+1) = 0 + 1 = 1
    # Option B: 3->Left(10), 2->Right(10). Costs: |10-10| + 1 = 1
    # Min 1
    # Total = 1.414 + 1 = 2.414
    # Scaled by 4: 2.414 * 4 = 9.656 -> Integer 9 (or 10 if rounded? The problem asks for float, Verilog output is scaled int).
    # We will check if Verilog result is close to 9 or 10. 
    # Actually, sqrt(2) is irrational. Integer sqrt( (1^2 + 1^2) * 16 ) = sqrt(32) = 5.656 -> int 5 (binary search truncates?) 
    # Wait, binary search finds integer root. 
    # We should check `val * 16`.
    # sqrt( (1^2 + 1^2) * 16 ) = sqrt(32) = 5.65.
    # So cost for pair 0 = 5 (straight) + 5 (dist) = 10? No.
    # Straight cost: |p - Tx|. Scale 4. |0-0| * 4 = 0. |1-0| * 4 = 4.
    # Dist cost: sqrt( (1^2 + 1^2) * 16 ) = sqrt(32) = 5 (int).
    # Option A: 0 + 5 = 5.
    # Option B: 4 + sqrt(1*16) = 4 + 4 = 8.
    # Pair 0 min = 5.
    # Pair 1: Tx=10. p=10, 10. 
    # Straight: 0. Dist: sqrt(1*16) = 4.
    # Cost = 4.
    # Total = 9.
    # Python output 2.414. 2.414 * 4 = 9.656. 
    # Verilog output 9. 
    # This is the expected behavior for fixed-point integer arithmetic.

    test_cases = [
        {
            "N": 4, "L": 10, "W": 1, 
            "pos": [1, 0, 10, 10],
            "expected_scaled": 9  # 2.414 * 4 = 9.656 -> truncated to 9
        },
        {
            "N": 6, "L": 10, "W": 1, 
            "pos": [0, 9, 3, 5, 5, 6],
            # Sorted: 0, 3, 5, 5, 6, 9
            # M=3. Tx[0]=0, Tx[1]=5, Tx[2]=10
            # Pair 0 (Tx=0): trees 0, 3. 
            #   A: 0->L, 3->R. Cost: 0 + sqrt(3^2+1) = sqrt(10) -> sqrt(160) = 12.64 -> 12
            #   B: 3->L, 0->R. Cost: 3 + sqrt(1) = 3 + 4 = 7. (Scale 4)
            #   Min 7.
            # Pair 1 (Tx=5): trees 5, 5.
            #   A: 5->L, 5->R. Cost: 0 + sqrt(1) = 4.
            #   B: Same. Cost 4.
            #   Min 4.
            # Pair 2 (Tx=10): trees 6, 9.
            #   A: 6->L, 9->R. Cost: |6-10|=4, sqrt(1)=4. Total 8.
            #   B: 9->L, 6->R. Cost: |9-10|=1, sqrt(16+1)=sqrt(17)=4.12->4. Total 5.
            #   Min 5.
            # Total = 7 + 4 + 5 = 16.
            # Python output 9.285. 9.285 * 4 = 37.14.
            # My manual calc above is wrong because I didn't scale correctly or the logic is different.
            # Let's re-read logic. 
            # Wait, for pair 2 (Tx=10), trees 6, 9.
            # Option A: 6->Left(10). Dist = |6-10| = 4. 
            #           9->Right(10). Dist = sqrt((9-10)^2 + 1^2) = sqrt(2) = 1.414.
            #           Total = 5.414. Scale 4 -> 21.656.
            # Option B: 9->Left(10). Dist = |9-10| = 1.
            #           6->Right(10). Dist = sqrt((6-10)^2 + 1^2) = sqrt(17) = 4.123.
            #           Total = 5.123. Scale 4 -> 20.492.
            # Min 5.123. Scaled ~20.
            # Pair 0 (Tx=0): trees 0, 3.
            #   A: 0->L (0), 3->R (sqrt(9+1)=3.16). Total 3.16. Scale 12.
            #   B: 3->L (3), 0->R (sqrt(1)=1). Total 4. Scale 16.
            # Min 3.16. Scaled ~12.
            # Pair 1 (Tx=5): trees 5, 5.
            #   A: 5->L (0), 5->R (1). Total 1. Scale 4.
            # Min 1. Scaled 4.
            # Total = 3.16 + 1 + 5.123 = 9.285.
            # Scaled 9.285 * 4 = 37.14.
            # So expected scale result is 37.
            "expected_scaled": 37
        }
    ]

    for tc in test_cases:
        dut._log.info(f"Running test: N={tc['N']}, L={tc['L']}, W={tc['W']}")
        
        # Write Inputs
        if has_signal(dut, 'N'):
            dut.N.value = tc['N']
        if has_signal(dut, 'L'):
            dut.L.value = tc['L']
        if has_signal(dut, 'W'):
            dut.W.value = tc['W']
        
        # Write Array
        # Check for flattened ports pos_0, pos_1...
        array_written = False
        for i in range(tc['N']):
            if has_signal(dut, f'pos_{i}'):
                getattr(dut, f'pos_{i}').value = tc['pos'][i]
                array_written = True
        if not array_written:
            # Assume indexable
            for i in range(tc['N']):
                try:
                    dut.pos[i].value = tc['pos'][i]
                except Exception:
                    dut._log.error(f"Could not write pos[{i}]")
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure("Timeout waiting for done")
        else:
            # Combinational
            await Timer(100, units='ns')

        # Read Result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
        
        result = int(dut.result.value)
        expected = tc['expected_scaled']
        
        # Allow small tolerance due to integer truncation vs rounding
        if abs(result - expected) > 2:
             raise TestFailure(f"Result mismatch. Expected {expected}, got {result}")
        
        dut._log.info(f"Test Passed. Result: {result} (Expected ~{expected})")
