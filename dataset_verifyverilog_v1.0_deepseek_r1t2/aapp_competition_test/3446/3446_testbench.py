import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# HELPER FUNCTIONS
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

DATA_WIDTH = 8
STRING_MAX_LEN = 10
SYMBOL_COUNT = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100000

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_optimal_assembly(dut):
    """Test the optimal_assembly module with the first example."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Parse the input test case
    # Example: 
    # 2
    # a b
    # 3-b 5-b
    # 6-a 2-b
    # 2
    # aba
    # bba
    # 0
    
    # We'll hardcode the values for this test case
    k = 2
    symbols = ['a', 'b']  # This is the order: a first, then b
    # Map symbols to indices: a->0, b->1
    symbol_map = {'a':0, 'b':1}
    
    # Assembly table: row i, column j corresponds to (symbol_i, symbol_j)
    # time_table[i][j] and result_table[i][j]
    time_table = [
        [3, 5],   # for (a,a) and (a,b)
        [6, 2]    # for (b,a) and (b,b)
    ]
    result_table = [
        ['b', 'b'],   # for (a,a)->b, (a,b)->b
        ['a', 'b']    # for (b,a)->a, (b,b)->b
    ]
    # Convert result_table to indices
    result_table_idx = [
        [symbol_map['b'], symbol_map['b']],
        [symbol_map['a'], symbol_map['b']]
    ]
    
    # Query strings
    queries = ['aba', 'bba']
    expected_outputs = ['9-b', '8-a']
    
    # Configuration: set symbol_in, time_table_in, result_table_in
    # symbol_in: 8 symbols, each 8 bits. We'll set the first k symbols, rest to 0.
    for i in range(8):
        if i < k:
            dut.symbol_in[i].value = ord(symbols[i])
        else:
            dut.symbol_in[i].value = 0
    
    # time_table_in: 8x8, each 32 bits
    for i in range(8):
        for j in range(8):
            if i < k and j < k:
                dut.time_table_in[i][j].value = time_table[i][j]
            else:
                dut.time_table_in[i][j].value = 0
    
    # result_table_in: 8x8, each 8 bits (index)
    for i in range(8):
        for j in range(8):
            if i < k and j < k:
                dut.result_table_in[i][j].value = result_table_idx[i][j]
            else:
                dut.result_table_in[i][j].value = 0
    
    # Now process each query
    for query_idx, (query_str, expected) in enumerate(zip(queries, expected_outputs)):
        dut._log.info(f"Testing query: {query_str}")
        
        # Reset DUT for each query
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Set configuration inputs again (since reset cleared them)
        for i in range(8):
            if i < k:
                dut.symbol_in[i].value = ord(symbols[i])
            else:
                dut.symbol_in[i].value = 0
        for i in range(8):
            for j in range(8):
                if i < k and j < k:
                    dut.time_table_in[i][j].value = time_table[i][j]
                else:
                    dut.time_table_in[i][j].value = 0
        for i in range(8):
            for j in range(8):
                if i < k and j < k:
                    dut.result_table_in[i][j].value = result_table_idx[i][j]
                else:
                    dut.result_table_in[i][j].value = 0
        
        # Convert query string to indices
        query_indices = [symbol_map[c] for c in query_str]
        length = len(query_str)
        
        # Set string_in: 10 elements
        for i in range(10):
            if i < length:
                dut.string_in[i].value = query_indices[i]
            else:
                dut.string_in[i].value = 0
        
        # Set length_in
        dut.length_in.value = length
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Read results
        if not is_value_defined(dut.result_time.value) or not is_value_defined(dut.result_symbol.value):
            raise TestFailure(f"Result is undefined")
        
        result_time = int(dut.result_time.value)
        result_symbol = chr(int(dut.result_symbol.value))
        
        # Format output
        output_str = f"{result_time}-{result_symbol}"
        
        # Compare with expected
        if output_str != expected:
            raise TestFailure(f"Query {query_str}: expected {expected}, got {output_str}")
        
        dut._log.info(f"Query {query_str}: {output_str} [PASS]")
    
    dut._log.info("All tests passed!")