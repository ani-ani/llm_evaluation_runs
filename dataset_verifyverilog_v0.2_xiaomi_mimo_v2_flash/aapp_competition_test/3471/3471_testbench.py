import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

# Helper to compute sequence in Python for verification
def compute_xorbonacci(K, initial, max_n):
    seq = list(initial)
    if max_n <= K:
        return seq[:max_n]
    for i in range(K, max_n):
        val = 0
        for j in range(1, K+1):
            val ^= seq[i-j]
        seq.append(val)
    return seq

def get_xor_sum(seq, l, r):
    # Indices are 1-based
    if l < 1: l = 1
    if r > len(seq): r = len(seq)
    if l > r: return 0
    res = 0
    for i in range(l-1, r):
        res ^= seq[i]
    return res

@cocotb.test()
async def test_xorbonacci_basic(dut):
    """Test basic XOR-bonacci sequence generation and querying"""
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.K.value = 0
    for i in range(8):
        setattr(dut, f'initial_values_{i}', 0)
    dut.l.value = 0
    dut.r.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Sample Input 1
    # K=4, values: 1, 3, 5, 7
    # Queries: (2,2), (2,5), (1,5)
    
    K = 4
    initial = [1, 3, 5, 7]
    
    # Compute expected sequence for a small window (say up to index 10) to verify
    # Sequence: 1, 3, 5, 7, 1^3^5^7=0, 3^5^7^0=1, 5^7^0^1=3, ...
    # 1, 3, 5, 7, 0, 1, 3, 7, ...
    full_seq = compute_xorbonacci(K, initial, 10)
    dut._log.info(f"Expected Sequence: {full_seq}")
    
    # Query 1: l=2, r=2 -> result 3
    expected_1 = get_xor_sum(full_seq, 2, 2)
    
    # Load inputs
    dut.K.value = K
    for i in range(K):
        getattr(dut, f'initial_values_{i}').value = initial[i]
    
    # For the simplified hardware, we assume it runs for a fixed number of cycles to find period
    # or computes a specific window. Since the prompt specified a complex FSM with a limit,
    # we will let it run for a reasonable number of clock cycles.
    
    dut.l.value = 2
    dut.r.value = 2
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while not dut.done.value and cycles < 500:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if dut.done.value:
        result = dut.result.value
        dut._log.info(f"Query (2,2): Got {result}, Expected {expected_1}")
        if int(result) != expected_1:
            raise TestFailure(f"Result mismatch for (2,2). Got {result}, expected {expected_1}")
    else:
        raise TestFailure("Module did not finish in time")

    # Reset for next query
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Query 2: l=2, r=5 -> result 1
    expected_2 = get_xor_sum(full_seq, 2, 5)
    dut.l.value = 2
    dut.r.value = 5
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 500:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.done.value:
        result = dut.result.value
        dut._log.info(f"Query (2,5): Got {result}, Expected {expected_2}")
        if int(result) != expected_2:
            raise TestFailure(f"Result mismatch for (2,5). Got {result}, expected {expected_2}")
    else:
        raise TestFailure("Module did not finish in time")

    # Reset for next query
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Query 3: l=1, r=5 -> result 0
    expected_3 = get_xor_sum(full_seq, 1, 5)
    dut.l.value = 1
    dut.r.value = 5
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 500:
        await RisingEdge(dut.clk)
        cycles += 1
        
    if dut.done.value:
        result = dut.result.value
        dut._log.info(f"Query (1,5): Got {result}, Expected {expected_3}")
        if int(result) != expected_3:
            raise TestFailure(f"Result mismatch for (1,5). Got {result}, expected {expected_3}")
    else:
        raise TestFailure("Module did not finish in time")

    dut._log.info("All tests passed!")
