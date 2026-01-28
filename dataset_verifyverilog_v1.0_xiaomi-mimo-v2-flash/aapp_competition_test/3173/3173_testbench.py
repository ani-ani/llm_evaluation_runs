import cocotb
from cocotb.triggers import Timer, RisingEdge, First
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_hunter_exam(dut):
    """
    Testbench for Hunter Exam Solver.
    Assumes DUT has an interface to request grid/score data.
    We will drive the clock and respond to requests.
    """
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.grid_char.value = 0 # ASCII code
    dut.score_val.value = 0
    dut.found_result.value = 0 # Ack for read
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case: Sample 1
    # R=2, C=5, K=2
    # Grid:
    # R . . ? .
    # . X . . .
    # Scores: 100 100 7 100 8
    
    R = 2
    C = 5
    K = 2
    
    grid_data = [
        ['R', '.', '.', '?', '.'],
        ['.', 'X', '.', '.', '.']
    ]
    scores_data = [100, 100, 7, 100, 8]
    
    # Expected Result:
    # Max Score One Part = 8 (Start col 3, move R to 4, fall to score 8)
    # Total = 8 * 2 = 16
    expected_total = 16

    # Start the process
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Memory Access Logic (Slave to DUT)
    # DUT will issue requests (req_read, req_score). We respond.
    # We need to monitor these signals.
    
    # Note: The DUT logic needs to read grid from row R-1 down to 0.
    # Addresses: 0..4 (Row 0), 5..9 (Row 1)
    
    # We loop until we see done signal.
    done = False
    timeout = 20000 # Cycles
    
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        
        # Check for read request
        if has_signal(dut, 'req_read') and int(dut.req_read.value) == 1:
            # Read address
            addr = int(dut.read_addr.value)
            # Decode: Row = addr // C, Col = addr % C
            # Note: DUT might read in reverse or forward. We handle both.
            # Assuming linear mapping: Row * C + Col
            row = addr // C
            col = addr % C
            
            # Sanity check
            if row < 0 or row >= R or col < 0 or col >= C:
                dut.grid_char.value = ord('.') # Safe fallback
            else:
                char = grid_data[row][col]
                dut.grid_char.value = ord(char)
            
            dut.found_result.value = 1
            await RisingEdge(dut.clk)
            dut.found_result.value = 0
        
        # Check for score request
        elif has_signal(dut, 'req_score') and int(dut.req_score.value) == 1:
            col = int(dut.read_col.value)
            if 0 <= col < C:
                dut.score_val.value = scores_data[col]
            else:
                dut.score_val.value = 0
            
            dut.found_result.value = 1
            await RisingEdge(dut.clk)
            dut.found_result.value = 0

        # Check for done
        if has_signal(dut, 'done') and int(dut.done.value) == 1:
            done = True
            break

    if not done:
        raise TestFailure(f"Timeout after {timeout} cycles")

    # Check result
    if has_signal(dut, 'total_score'):
        result = int(dut.total_score.value)
        # Since K=2, MaxPart=8, Result=16
        dut._log.info(f"Result: {result}, Expected: {expected_total}")
        if result != expected_total:
             # Try to handle small variations or logic errors
             # But strictly, it should match.
             # Note: If DUT logic is just simulation, it might differ.
             # The prompt implies finding the MAX.
             # Let's see if result matches.
             pass
             
        # For robust testing, we might not assert strict equality if logic differs,
        # but here we expect 16.
        # If DUT implements Greedy towards max score column, it works.
        # If DUT implements simple simulation, it might fail.
        
        # Let's check the logic assumed:
        # DUT computes MaxScoreOnePart * K.
        # Sample 1: Max score is 8. 8*2 = 16.
        
        if result != 16:
             raise TestFailure(f"Mismatch: {result} != 16")

    # Test Case 2: R=2, C=3, K=1
    # X . .
    # . ? .
    # 10 1000 1
    # Max Part: 10. Total: 10.
    # Reset and run again? 
    # Usually one testbench runs one case or multiple.
    # Let's reset and run 2nd case.
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    R = 2
    C = 3
    K = 1
    grid_data = [
        ['X', '.', '.'],
        ['.', '?', '.']
    ]
    scores_data = [10, 1000, 1]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    done = False
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        
        if has_signal(dut, 'req_read') and int(dut.req_read.value) == 1:
            addr = int(dut.read_addr.value)
            row = addr // C
            col = addr % C
            if row < R and col < C:
                dut.grid_char.value = ord(grid_data[row][col])
            else:
                dut.grid_char.value = ord('.')
            dut.found_result.value = 1
            await RisingEdge(dut.clk)
            dut.found_result.value = 0
            
        elif has_signal(dut, 'req_score') and int(dut.req_score.value) == 1:
            col = int(dut.read_col.value)
            if col < C:
                dut.score_val.value = scores_data[col]
            else:
                dut.score_val.value = 0
            dut.found_result.value = 1
            await RisingEdge(dut.clk)
            dut.found_result.value = 0

        if has_signal(dut, 'done') and int(dut.done.value) == 1:
            done = True
            break

    if not done:
        raise TestFailure("Timeout on test 2")

    if has_signal(dut, 'total_score'):
        result = int(dut.total_score.value)
        dut._log.info(f"Result 2: {result}, Expected: 10")
        if result != 10:
            raise TestFailure(f"Mismatch: {result} != 10")
