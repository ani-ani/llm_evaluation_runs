import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
N = 8
COST_W = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100000

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

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
    if value < 0:
        max_signed = (1 << (bits-1)) - 1
        min_signed = -(1 << (bits-1))
        clamped = max(min_signed, min(max_signed, value))
        return from_signed(clamped, bits)
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=30000, timeout_unit="ms")
async def test_make_impossible(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (seq_str, k, costs, expected)
    # ? means Barry cannot win (Bruce always can)
    test_cases = [
        ("((()", 1, [480, 617, -570, 928], 480),
        (")()(", 3, [-532, 870, 617, 905], "?"),
    ]
    
    passed = 0
    for i, (seq_str, k, costs, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: seq='{seq_str}', k={k}")
        
        try:
            # Convert sequence to bits
            seq_bits = [0 if c == '(' else 1 for c in seq_str]
            actual_n = len(seq_str)
            
            # Assign sequence
            if has_signal(dut, 'seq_0'):
                for idx in range(N):
                    if idx < actual_n:
                        getattr(dut, f'seq_{idx}').value = seq_bits[idx]
                    else:
                        getattr(dut, f'seq_{idx}').value = 0
            elif has_signal(dut, 'seq'):
                packed = 0
                for idx, bit in enumerate(seq_bits):
                    packed |= bit << idx
                dut.seq.value = packed
            else:
                raise TestFailure("No seq signal found")
            
            # Assign k
            dut.k.value = clamp_to_width(k, 4)
            
            # Assign costs
            for idx, cost_val in enumerate(costs):
                port_name = f'cost_{idx}'
                if has_signal(dut, port_name):
                    clamped = clamp_to_width(cost_val, COST_W)
                    getattr(dut, port_name).value = clamped
                else:
                    raise TestFailure(f"No cost_{idx} signal")
            
            # Compute
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Check results
            if not is_value_defined(dut.success.value):
                raise TestFailure("Success signal undefined")
            
            success = int(dut.success.value)
            
            if expected == "?":
                if success != 0:
                    raise TestFailure(f"Expected Bruce always wins, got success={success}")
                dut._log.info("  PASS: Bruce always wins")
            else:
                if success != 1:
                    raise TestFailure(f"Expected Barry can win, got success={success}")
                
                if not is_value_defined(dut.min_cost.value):
                    raise TestFailure("Min_cost undefined")
                
                min_cost = to_signed(int(dut.min_cost.value), COST_W)
                if min_cost != int(expected):
                    raise TestFailure(f"Expected {expected}, got {min_cost}")
                
                dut._log.info(f"  PASS: min_cost = {min_cost}")
            
            passed += 1
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            raise
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"All {passed} tests passed")