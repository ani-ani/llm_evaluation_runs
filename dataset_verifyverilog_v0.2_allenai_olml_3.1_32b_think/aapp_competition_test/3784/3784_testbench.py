import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

mod = 1000000007

def python_model(n, m):
    if n == 0:
        return 0
    if m == 0:
        return 1 if n == 0 else 0 # Or based on specific definition, usually n>=1 implies cut>=1
        
    f = [[0 for i in range(60)] for j in range(60)]
    g = [[0 for i in range(60)] for j in range(60)]
    s = [[0 for i in range(60)] for j in range(60)]
    inv = [1]
    f[0][0] = s[0][0] = 1

    def pow(x, exp):
        res = 1
        for _ in range(31):
            if exp & 1:
                res = (res * x) % mod
            exp >>= 1
            if exp == 0:
                break
            x = (x * x) % mod
        return res

    for i in range(1, n + 1):
        inv.append(pow(i, mod - 2))

    for node in range(1, n + 1):
        for cut in range(1, n + 1):
            tmp = 0
            for ln in range(node):
                for lc in range(cut - 1, n + 1):
                    if f[ln][lc] == 0:
                        continue
                    if lc == cut - 1:
                        tmp = (tmp + f[ln][lc] * s[node - ln - 1][cut - 1]) % mod
                    else:
                        tmp = (tmp + f[ln][lc] * f[node - ln - 1][cut - 1]) % mod
            cnt = 1
            if tmp != 0:
                cn, cc = 0, 0
                for i in range(1, node + 1):
                    cn += node
                    cc += cut
                    cnt = cnt * (tmp + i - 1) % mod * inv[i] % mod
                    if cn > n or cc > n:
                        break
                    for j in range(n - cn, -1, -1):
                        for k in range(n - cc, -1, -1):
                            if f[j][k] == 0:
                                continue
                            g[j + cn][k + cc] += f[j][k] * cnt
                            g[j + cn][k + cc] %= mod
                for i in range(n + 1):
                    for j in range(n + 1):
                        f[i][j] = (f[i][j] + g[i][j]) % mod
                        g[i][j] = 0

        for cut in range(n, -1, -1):
            s[node][cut] = (s[node][cut + 1] + f[node][cut]) % mod

    return f[n][m - 1]

@cocotb.test()
async def test_world_counter(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases from problem
    test_cases = [
        (3, 2, 6),
        (4, 4, 3),
        (7, 3, 1196),
        (1, 1, 0),
        (2, 2, 2),
        (5, 5, 1),
        (50, 50, 3)
    ]

    for n_in, m_in, expected in test_cases:
        dut.n.value = n_in
        dut.m.value = m_in
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        result = int(dut.result.value)
        print(f"n={n_in}, m={m_in}: Got {result}, Expected {expected}")
        assert result == expected, f"Test failed for n={n_in}, m={m_in}"

    print("All tests passed")
