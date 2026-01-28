import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 16, 8, 10, 2000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_string(s, max_len=8):
    packed = 0
    for i, c in enumerate(s[:max_len]):
        if c == '(':
            packed |= (1 << i)
    return packed

def analyze_piece(s):
    balance = 0
    min_balance = 0
    for c in s:
        if c == '(':
            balance += 1
        else:
            balance -= 1
        min_balance = min(min_balance, balance)
    net = balance
    max_prefix = len(s)
    if min_balance < 0:
        balance = 0
        for i, c in enumerate(s):
            if c == '(':
                balance += 1
            else:
                balance -= 1
            if balance < 0:
                max_prefix = i
                break
    return len(s), net, max_prefix

def solve_case(strings):
    n = len(strings)
    pieces = []
    for s in strings:
        length, net, max_prefix = analyze_piece(s)
        pieces.append((length, net, max_prefix, pack_string(s)))
    pos = [p for p in pieces if p[1] >= 0]
    neg = [p for p in pieces if p[1] < 0]
    pos.sort(key=lambda x: (-x[2], -x[1]))
    neg.sort(key=lambda x: (x[1], -x[2]))
    sorted_pieces = pos + neg
    m = len(sorted_pieces)
    MAX_BAL = 8
    dp = [[-1] * (2*MAX_BAL+1) for _ in range(1<<m)]
    dp[0][MAX_BAL] = 0
    for mask in range(1<<m):
        for b in range(2*MAX_BAL+1):
            if dp[mask][b] < 0:
                continue
            balance = b - MAX_BAL
            for i in range(m):
                if not (mask & (1<<i)):
                    length, net, max_prefix, _ = sorted_pieces[i]
                    new_balance = balance + net
                    if new_balance < -MAX_BAL or new_balance > MAX_BAL:
                        continue
                    if balance + max_prefix < 0:
                        continue
                    new_b = new_balance + MAX_BAL
                    new_mask = mask | (1<<i)
                    new_val = dp[mask][b] + length
                    if new_val > dp[new_mask][new_b]:
                        dp[new_mask][new_b] = new_val
    best = 0
    for mask in range(1<<m):
        if dp[mask][MAX_BAL] > best:
            best = dp[mask][MAX_BAL]
    return best

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_balanced_parentheses(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (["())", "((()", ")()"], 10),
        ([")))))", ")", "((", "))((", "("], 2),
        (["()"], 2),
        (["(", ")"], 2),
        (["(", "("], 0)
    ]
    passed = 0
    failed = 0
    
    for i, (strings, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input strings: {strings}")
        try:
            if is_seq:
                n = len(strings)
                if n > 8:
                    raise TestFailure(f"Input n={n} exceeds max pieces 8")
                for j in range(8):
                    if j < n:
                        packed = pack_string(strings[j], 8)
                        length = len(strings[j])
                        getattr(dut, f'pieces_{j}').value = packed
                        getattr(dut, f'piece_len_{j}').value = length
                    else:
                        getattr(dut, f'pieces_{j}').value = 0
                        getattr(dut, f'piece_len_{j}').value = 0
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}"); failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
