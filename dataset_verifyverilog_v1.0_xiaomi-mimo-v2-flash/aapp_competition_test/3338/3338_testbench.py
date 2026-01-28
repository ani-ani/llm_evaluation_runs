import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Setup constants
DATA_WIDTH = 16
MAX_N = 16
MAX_K = 4
CLK_NS = 10
MAX_CYCLES = 10000

@cocotb.test(timeout_time=MAX_CYCLES*CLK_NS*2, timeout_unit='ns')
async def test_arcaea_diversity(dut):
    # Check for clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(3):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational
        await Timer(10, units='ns')

    # Test cases
    test_cases = [
        # n=6, k=1
        {
            'n': 6, 'k': 1,
            'partners': [
                (78, 61, 88, 71),
                (80, 80, 90, 90),
                (70, 90, 80, 100),
                (90, 70, 0, 0),
                (80, 67, 0, 0),
                (90, 63, 0, 0)
            ],
            'expected': 5
        },
        # n=5, k=5
        {
            'n': 5, 'k': 5,
            'partners': [
                (50, 70, 80, 80),
                (60, 60, 90, 90),
                (70, 50, 100, 100),
                (50, 50, 70, 70),
                (50, 50, 70, 70)
            ],
            'expected': 4
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: n={tc['n']}, k={tc['k']}")
        
        # Populate inputs
        if has_signal(dut, 'n'):
            dut.n.value = tc['n']
        if has_signal(dut, 'k'):
            dut.k.value = tc['k']

        # Populate array data
        for p_idx in range(MAX_N):
            if p_idx < tc['n']:
                g, p, ga, pa = tc['partners'][p_idx]
            else:
                g, p, ga, pa = 0, 0, 0, 0
            
            # Use getattr for potential 2D array access or indexed ports
            # Assuming flattened interface or indexed ports for simplicity in HDL spec
            # Example: partner_frag_i
            if has_signal(dut, f'partner_frag_{p_idx}'):
                getattr(dut, f'partner_frag_{p_idx}').value = clamp_to_width(g, DATA_WIDTH)
                getattr(dut, f'partner_step_{p_idx}').value = clamp_to_width(p, DATA_WIDTH)
                getattr(dut, f'partner_awake_frag_{p_idx}').value = clamp_to_width(ga, DATA_WIDTH)
                getattr(dut, f'partner_awake_step_{p_idx}').value = clamp_to_width(pa, DATA_WIDTH)
            
            # If 2D array interface (common in Verilog)
            if has_signal(dut, 'partner_frag'):
                try:
                    dut.partner_frag[p_idx].value = clamp_to_width(g, DATA_WIDTH)
                    dut.partner_step[p_idx].value = clamp_to_width(p, DATA_WIDTH)
                    dut.partner_awake_frag[p_idx].value = clamp_to_width(ga, DATA_WIDTH)
                    dut.partner_awake_step[p_idx].value = clamp_to_width(pa, DATA_WIDTH)
                except Exception:
                    pass # Handle bus access if needed

        # Trigger
        if is_seq:
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
                raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        else:
            await Timer(100, units='ns')

        # Check result
        if not has_signal(dut, 'result'):
             raise TestFailure("No result signal found")
             
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined (X or Z)")

        result = int(dut.result.value)
        expected = tc['expected']
        
        if result != expected:
            raise TestFailure(f"Test {i+1} Failed: Expected {expected}, got {result}")
        else:
            cocotb.log.info(f"Test {i+1} Passed: Result {result}")
