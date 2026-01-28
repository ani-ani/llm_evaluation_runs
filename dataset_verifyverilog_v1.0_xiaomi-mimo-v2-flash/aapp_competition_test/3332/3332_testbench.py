import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, CLK_NS, MAX_CYCLES = 16, 10, 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def feed_stream(dut, start, end, prio, clk):
    dut.stream_start.value = clamp_to_width(start, 8)
    dut.stream_end.value = clamp_to_width(end, 8)
    dut.stream_prio.value = clamp_to_width(prio, 16)
    dut.stream_valid.value = 1
    await RisingEdge(clk)
    dut.stream_valid.value = 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_optimal_subset(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1: Sample input scaled
    # Original: (1,3,6), (2,5,8), (3,3,5), (5,3,6) -> Max 13
    # Scaled times: stream1: [1,4), stream2: [2,7), stream3: [3,6), stream4: [5,8)
    test_cases = [
        [
            (1, 4, 6),  # s=1, e=1+3
            (2, 7, 8),  # s=2, e=2+5
            (3, 6, 5),  # s=3, e=3+3
            (5, 8, 6)   # s=5, e=5+3
        ],
        [
            (5, 9, 10),   # scaled (5,4,10)
            (3, 7, 6),    # scaled (3,4,6)
            (1, 9, 100),  # scaled (1,8,100)
            (3, 5, 3),    # scaled (3,2,3)
            (4, 6, 4),    # scaled (4,2,4)
            (3, 5, 2)     # scaled (3,2,2)
        ]
    ]
    expected = [13, 115]
    
    for idx, (streams, exp) in enumerate(zip(test_cases, expected)):
        cocotb.log.info(f"Test case {idx+1}: {len(streams)} streams")
        
        # Start processing
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Feed streams
        for s, e, p in streams:
            await feed_stream(dut, s, e, p, dut.clk)
            await RisingEdge(dut.clk)
        
        # Wait for completion
        if is_seq:
            await wait_for_done(dut)
        else:
            await Timer(5000, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
        
        result = int(dut.result.value)
        cocotb.log.info(f"Expected: {exp}, Got: {result}")
        
        if result != exp:
            raise TestFailure(f"Test {idx+1} failed: Expected {exp}, got {result}")
