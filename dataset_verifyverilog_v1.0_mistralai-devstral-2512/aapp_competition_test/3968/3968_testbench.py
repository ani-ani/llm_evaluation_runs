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

# Fixed-point helpers (Q16.16)
def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_virus_spread(dut):
    # Clock setup if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(10, units='ns')

    # Test cases
    # Case 1: Sample 1
    # N=9, D=1, initial infected: 1
    # Times: [(5,10), (1,3), (11,14), (5,5), (10,10), (3,6), (6,12), (7,7), (4,11)]
    # Expected: 1 4 5 6 7 8 9
    test_cases = [
        {
            'N': 9, 'D': 1, 'init_count': 1, 'init_indices': [1],
            's': [5, 1, 11, 5, 10, 3, 6, 7, 4],
            't': [10, 3, 14, 5, 10, 6, 12, 7, 11],
            'expected': [1, 4, 5, 6, 7, 8, 9]
        },
        # Case 2: Sample 2
        # N=5, D=1, initial infected: 1
        # Times: [(3,3), (2,3), (1,2), (3,4), (4,5)]
        # Expected: 1 2 4
        {
            'N': 5, 'D': 1, 'init_count': 1, 'init_indices': [1],
            's': [3, 2, 1, 3, 4],
            't': [3, 3, 2, 4, 5],
            'expected': [1, 2, 4]
        },
        # Case 3: Sample 3
        # N=5, D=1, initial infected: 1
        # Times: [(3,3), (3,3), (4,4), (4,4), (5,5)]
        # Expected: 1 2
        {
            'N': 5, 'D': 1, 'init_count': 1, 'init_indices': [1],
            's': [3, 3, 4, 4, 5],
            't': [3, 3, 4, 4, 5],
            'expected': [1, 2]
        },
        # Case 4: Single person
        {
            'N': 1, 'D': 1, 'init_count': 1, 'init_indices': [1],
            's': [0],
            't': [1000000000],
            'expected': [1]
        }
    ]

    for tc_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Test Case {tc_idx+1}: N={tc['N']}, D={tc['D']}")
        
        # Set inputs
        if has_signal(dut, 'start'):
            dut.start.value = 1
        
        # N
        if has_signal(dut, 'N'):
            dut.N.value = tc['N']
        
        # D
        if has_signal(dut, 'D'):
            dut.D.value = tc['D']
        
        # Initial infected count
        if has_signal(dut, 'initial_infected_count'):
            dut.initial_infected_count.value = tc['init_count']
        
        # Initial infected mask
        init_mask = 0
        for idx in tc['init_indices']:
            init_mask |= (1 << (idx - 1))  # 0-indexed bit
        if has_signal(dut, 'initial_infected_idx'):
            dut.initial_infected_idx.value = init_mask
        
        # Times (Q16.16)
        frac = 16
        max_s = 0
        max_t = 0
        if has_signal(dut, 's_arr'):
            # Array of signals
            for i in range(tc['N']):
                val = float_to_fixed(tc['s'][i], frac)
                dut.s_arr[i].value = val
                if val > max_s: max_s = val
        elif has_signal(dut, 's_arr_0'):
            # Individual ports
            for i in range(tc['N']):
                val = float_to_fixed(tc['s'][i], frac)
                getattr(dut, f's_arr_{i}').value = val
                if val > max_s: max_s = val
        
        if has_signal(dut, 't_arr'):
            for i in range(tc['N']):
                val = float_to_fixed(tc['t'][i], frac)
                dut.t_arr[i].value = val
                if val > max_t: max_t = val
        elif has_signal(dut, 't_arr_0'):
            for i in range(tc['N']):
                val = float_to_fixed(tc['t'][i], frac)
                getattr(dut, f't_arr_{i}').value = val
                if val > max_t: max_t = val
        
        if is_seq:
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(1000, units='ns')
        
        # Check result
        if not is_value_defined(dut.result_mask.value):
            raise TestFailure(f"Result mask undefined for test {tc_idx+1}")
        
        result_mask = int(dut.result_mask.value)
        
        # Verify expected
        expected_mask = 0
        for idx in tc['expected']:
            expected_mask |= (1 << (idx - 1))
        
        if result_mask != expected_mask:
            # Decode for debug
            got_indices = [i+1 for i in range(tc['N']) if (result_mask >> i) & 1]
            exp_indices = tc['expected']
            raise TestFailure(f"Test {tc_idx+1} failed: Expected {exp_indices}, got {got_indices}")
        
        cocotb.log.info(f"Test {tc_idx+1} passed")

    # Additional stress test: N=16, D=1
    # Create overlapping intervals
    # Just a simple case where all overlap
    cocotb.log.info("Stress Test: N=16, D=1, all overlap")
    if has_signal(dut, 'start'):
        dut.start.value = 1
    if has_signal(dut, 'N'):
        dut.N.value = 16
    if has_signal(dut, 'D'):
        dut.D.value = 1
    if has_signal(dut, 'initial_infected_count'):
        dut.initial_infected_count.value = 1
    if has_signal(dut, 'initial_infected_idx'):
        dut.initial_infected_idx.value = 1  # Index 1
    
    # All intervals [0, 100]
    for i in range(16):
        val = float_to_fixed(0, 16)
        if has_signal(dut, 's_arr'):
            dut.s_arr[i].value = val
        elif has_signal(dut, f's_arr_{i}'):
            getattr(dut, f's_arr_{i}').value = val
        
        val = float_to_fixed(100, 16)
        if has_signal(dut, 't_arr'):
            dut.t_arr[i].value = val
        elif has_signal(dut, f't_arr_{i}'):
            getattr(dut, f't_arr_{i}').value = val
    
    if is_seq:
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(1000, units='ns')
    
    if is_value_defined(dut.result_mask.value):
        result = int(dut.result_mask.value)
        expected = (1 << 16) - 1  # All 16 infected
        if result != expected:
            raise TestFailure(f"Stress test failed: Expected all 16 bits set, got {result}")
        cocotb.log.info("Stress test passed")
    else:
        raise TestFailure("Stress test result undefined")
