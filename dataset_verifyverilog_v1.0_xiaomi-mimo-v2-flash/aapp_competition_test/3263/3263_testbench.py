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
    if has_signal(dut, 'clk'):
        for _ in range(cycles): await RisingEdge(dut.clk)
    else:
        await Timer(10 * cycles, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    if has_signal(dut, 'done'):
        for _ in range(max_cycles):
            if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
            else: await Timer(10, units='ns')
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
        raise TestFailure(f"Timeout after {max_cycles} cycles")
    else:
        # Combinational or fixed latency
        await Timer(500, units='ns')
        return True

# Test Case Data
test_cases = [
    {
        "desc": "Sample 1: 4 customers",
        "N": 4, "M": 4,
        "P": [10, 20, 30, 0],
        "R": [5, 5, 10, 0],
        "C": [2, 1, 1, 3],  # Types 1-indexed
        "T": [20, 30, 32, 120],
        "exp": 3
    },
    {
        "desc": "Sample 2: 3 customers, same type",
        "N": 3, "M": 4,
        "P": [10, 0, 0, 0],
        "R": [10, 0, 0, 0],
        "C": [1, 1, 1],
        "T": [10, 10, 10],
        "exp": 3
    },
    {
        "desc": "Sample 3: 10 customers mixed",
        "N": 10, "M": 4,
        "P": [10, 30, 60, 0],
        "R": [5, 30, 30, 0],
        "C": [1, 2, 1, 2, 2, 3, 3, 3, 1, 1],
        "T": [10, 12, 15, 20, 30, 90, 90, 100, 105, 140],
        "exp": 6
    }
]

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_fluttershy(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
    
    for tc in test_cases:
        cocotb.log.info(f"Running Test: {tc['desc']}")
        await reset_dut(dut)
        
        # 1. Configure P and R arrays
        if has_signal(dut, 'P_i'):
            # Check if it's a bus or array of ports
            try:
                dut.P_i.value = tc['P']  # Try direct assignment (may be reg array)
            except Exception:
                pass
            
            # Try individual ports
            for i in range(tc['M']):
                if hasattr(dut, f'P_{i+1}'):
                    getattr(dut, f'P_{i+1}').value = clamp_to_width(tc['P'][i], 16)
                elif hasattr(dut, f'P_i') and hasattr(dut.P_i, '__getitem__'):
                    try:
                        dut.P_i[i].value = clamp_to_width(tc['P'][i], 16)
                    except Exception:
                        pass
        
        if has_signal(dut, 'R_i'):
            for i in range(tc['M']):
                if hasattr(dut, f'R_{i+1}'):
                    getattr(dut, f'R_{i+1}').value = clamp_to_width(tc['R'][i], 16)
                elif hasattr(dut, 'R_i') and hasattr(dut.R_i, '__getitem__'):
                    try:
                        dut.R_i[i].value = clamp_to_width(tc['R'][i], 16)
                    except Exception:
                        pass

        # 2. Configure Customers
        if has_signal(dut, 'num_cust'):
            dut.num_cust.value = tc['N']
        
        # Assign cust_type and cust_time
        for i in range(tc['N']):
            # Type
            if hasattr(dut, f'cust_type_{i}'):
                getattr(dut, f'cust_type_{i}').value = tc['C'][i]
            elif hasattr(dut, 'cust_type') and hasattr(dut.cust_type, '__getitem__'):
                dut.cust_type[i].value = tc['C'][i]
            
            # Time
            if hasattr(dut, f'cust_time_{i}'):
                getattr(dut, f'cust_time_{i}').value = clamp_to_width(tc['T'][i], 16)
            elif hasattr(dut, 'cust_time') and hasattr(dut.cust_time, '__getitem__'):
                dut.cust_time[i].value = clamp_to_width(tc['T'][i], 16)

        # 3. Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            # Combinational logic might need some time
            await Timer(50, units='ns')

        # 4. Wait for Done
        await wait_for_done(dut)

        # 5. Check Result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result signal undefined for {tc['desc']}")
        
        result = int(dut.result.value)
        expected = tc['exp']
        
        cocotb.log.info(f"Expected: {expected}, Got: {result}")
        if result != expected:
            raise TestFailure(f"Result mismatch! Expected {expected}, got {result}")

        # Small delay between tests
        await Timer(100, units='ns')
