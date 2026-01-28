import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 32
MAX_CYCLES = 200

# Helpers

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def clamp_to_width(v, bits):
    if not isinstance(v, int):
        v = 0
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        if has_signal(dut, 'done'):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
        else:
            # If no done signal, assume combinational after delay
            await Timer(100, units='ns')
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_football_cheer(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(10, units='ns')

    # Test Cases
    # Case 1: n=1, t=31, Opponent: [20,60], [50,90]
    # Opponent active minutes: 20-59 (40 mins), 50-89 (40 mins) -> Union: 20-89 (70 mins)
    # We have 31 minutes. We should cheer to create 5-streaks.
    # Optimal (from python logic): 4 goals for us, 3 for them (Sample Output 4 3)
    
    test_cases = [
        {
            'n': 1,
            't': 31,
            'opp_ranges': [(20, 60), (50, 90)],
            'exp_a': 4,
            'exp_b': 3,
            'desc': 'Sample 1'
        },
        {
            'n': 2,
            't': 5,
            'opp_ranges': [(0, 90), (0, 90), (3, 90)],
            'exp_a': 0,
            'exp_b': 17,
            'desc': 'Sample 2'
        }
    ]

    for tc in test_cases:
        cocotb.log.info(f"Running test: {tc['desc']}")
        
        # Generate opponent bitmask (90 bits)
        opp_mask = [0] * 90
        for (start, end) in tc['opp_ranges']:
            for i in range(start, end):
                if i < 90:
                    opp_mask[i] = 1
        
        # Pack into 32-bit chunks for HDL
        # Input names might be opp_low, opp_mid, opp_high or just opp array
        # We check for specific signal names or generic interface
        
        if has_signal(dut, 'opponent_low'):
            low = 0; mid = 0; high = 0
            for i in range(32):
                if i < 90 and opp_mask[i]: low |= (1 << i)
            for i in range(32):
                if 32+i < 90 and opp_mask[32+i]: mid |= (1 << i)
            for i in range(26): # 64 to 89
                if 64+i < 90 and opp_mask[64+i]: high |= (1 << i)
            
            dut.opponent_low.value = low
            dut.opponent_mid.value = mid
            dut.opponent_high.value = high
        
        elif has_signal(dut, 'opponent'): # Array interface
            for i in range(90):
                dut.opponent[i].value = opp_mask[i]
        
        if has_signal(dut, 'n'):
            dut.n.value = tc['n']
        if has_signal(dut, 't'):
            dut.t.value = tc['t']

        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')

        # Check Results
        try:
            if has_signal(dut, 'sportify_score'):
                score_a = int(dut.sportify_score.value)
            else:
                score_a = -1
                
            if has_signal(dut, 'spoilify_score'):
                score_b = int(dut.spoilify_score.value)
            else:
                score_b = -1

            if score_a != tc['exp_a'] or score_b != tc['exp_b']:
                raise TestFailure(f"Mismatch: Expected ({tc['exp_a']}, {tc['exp_b']}), Got ({score_a}, {score_b})")
            
            cocotb.log.info(f"PASS: {tc['desc']} - Result {score_a} {score_b}")

        except Exception as e:
            cocotb.log.error(f"FAIL: {tc['desc']} - {e}")
            raise
