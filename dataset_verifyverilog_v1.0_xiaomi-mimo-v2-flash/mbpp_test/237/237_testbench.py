import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Pack tuple list into 256-bit input (16 tuples * 16 bits)
def pack_tuples(tuples_list):
    packed = 0
    for i, (a, b) in enumerate(tuples_list):
        # Sort to match hardware logic
        a_s, b_s = (a, b) if a <= b else (b, a)
        # a in bits 15:8, b in 7:0 of the 16-bit segment
        val = (a_s << 8) | b_s
        packed |= (val << (i * 16))
    return packed

async def write_inputs(dut, tuples_list, num_tuples):
    dut.tuples_in.value = clamp_to_width(pack_tuples(tuples_list), 256)
    dut.num_tuples.value = clamp_to_width(num_tuples, 4)

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_tuple_counter(dut):
    if not has_signal(dut, 'clk'):
        return # No sequential logic to test

    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test case 1
    tuples1 = [(3, 1), (1, 3), (2, 5), (5, 2), (6, 3)]
    # Sorted: (1,3), (1,3), (2,5), (2,5), (3,6)
    # Unique: (1,3) count 2, (2,5) count 2, (3,6) count 1
    # Expected output order depends on internal implementation (likely insertion order)
    
    # Expected outputs as dictionary
    expected_counts = {(1,3): 2, (2,5): 2, (3,6): 1}
    
    await write_inputs(dut, tuples1, len(tuples1))
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results = {}
    cycles = 0
    while cycles < 100:
        await RisingEdge(dut.clk)
        cycles += 1
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            tup = (int(dut.result_tuple.value) >> 8, int(dut.result_tuple.value) & 0xFF)
            cnt = int(dut.result_count.value)
            results[tup] = cnt
            cocotb.log.info(f"Found: {tup} : {cnt}")
        
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            cocotb.log.info("Done signal received")
            break
    
    if results != expected_counts:
        raise TestFailure(f"Test 1 Failed: Expected {expected_counts}, got {results}")

    await reset_dut(dut)

    # Test case 2
    tuples2 = [(4, 2), (2, 4), (3, 6), (6, 3), (7, 4)]
    expected_counts2 = {(2,4): 2, (3,6): 2, (4,7): 1}
    
    await write_inputs(dut, tuples2, len(tuples2))
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    results2 = {}
    cycles = 0
    while cycles < 100:
        await RisingEdge(dut.clk)
        cycles += 1
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            tup = (int(dut.result_tuple.value) >> 8, int(dut.result_tuple.value) & 0xFF)
            cnt = int(dut.result_count.value)
            results2[tup] = cnt
            cocotb.log.info(f"Found: {tup} : {cnt}")
        
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            cocotb.log.info("Done signal received")
            break
            
    if results2 != expected_counts2:
        raise TestFailure(f"Test 2 Failed: Expected {expected_counts2}, got {results2}")
