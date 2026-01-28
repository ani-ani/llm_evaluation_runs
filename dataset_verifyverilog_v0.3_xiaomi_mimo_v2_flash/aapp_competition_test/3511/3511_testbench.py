import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================
MOD = 1000000007
N = 3                     # Test with N=3
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# PYTHON REFERENCE SIMULATION
# ============================================================================
def compute_expected(queries, N, MOD):
    e_i = [0] * N
    e2_i = [0] * N
    e_ij = [[0] * N for _ in range(N)]
    outputs = []
    for q in queries:
        if q[0] == 1:
            u, v = q[1], q[2]
            L = v - u + 1
            inv_L = pow(L, MOD-2, MOD)  # modular inverse
            p = [inv_L if (i+1) >= u and (i+1) <= v else 0 for i in range(N)]
            # Update e_i
            new_e_i = [(e_i[i] + p[i]) % MOD for i in range(N)]
            # Update e2_i
            new_e2_i = [(e2_i[i] + (2 * p[i] * e_i[i] + p[i])) % MOD for i in range(N)]
            # Update e_ij
            new_e_ij = [[e_ij[i][j] for j in range(N)] for i in range(N)]
            for i in range(N):
                for j in range(N):
                    if i != j:
                        new_e_ij[i][j] = (e_ij[i][j] + p[j] * e_i[i] + p[i] * e_i[j]) % MOD
            # Commit updates
            e_i = new_e_i
            e2_i = new_e2_i
            e_ij = new_e_ij
        else:  # type 2
            ans = sum(e2_i) % MOD
            outputs.append(ans)
    return outputs

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_pokenom_go(dut):
    """Test the PokenomGo module with a sequence of queries."""
    
    # Detect interface type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset sequence
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational module - wait for propagation
        await Timer(100, units='ns')
    
    # Define test queries (type, u, v or type only)
    # This matches the sample input but adapted for N=3
    queries = [
        (1, 1, 3),  # Put stone in box 1..3
        (2,),       # Query E(A)
        (1, 1, 3),  # Another stone
        (2,),       # Query E(A)
    ]
    
    # Compute expected outputs using Python reference
    expected_outputs = compute_expected(queries, N, MOD)
    dut._log.info(f'Expected outputs: {expected_outputs}')
    
    # Process each query
    for query in queries:
        if query[0] == 1:  # Type 1: put stone
            u, v = query[1], query[2]
            dut.u.value = u
            dut.v.value = v
            dut.query_type.value = 0
            
            if is_sequential:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                # Wait one cycle for update to complete
                await RisingEdge(dut.clk)
            else:
                # Combinational: wait for propagation
                await Timer(100, units='ns')
        
        else:  # Type 2: query E(A)
            dut.query_type.value = 1
            
            if is_sequential:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done signal
                if has_signal(dut, 'done'):
                    cycles = 0
                    while cycles < MAX_CYCLES:
                        await RisingEdge(dut.clk)
                        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                            break
                        cycles += 1
                    else:
                        raise TestFailure(f'Timeout: done not asserted after {MAX_CYCLES} cycles')
                else:
                    # No done signal - wait for propagation
                    await Timer(1000, units='ns')
            else:
                # Combinational - wait for propagation
                await Timer(1000, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure('Result is undefined (X/Z)')
            
            result = int(dut.result.value)
            expected = expected_outputs.pop(0)
            
            if result != expected:
                raise TestFailure(f'Test failed: expected {expected}, got {result}')
            
            dut._log.info(f'Type 2 query: result = {result} (expected {expected}) [OK]')
    
    dut._log.info('All tests passed successfully')