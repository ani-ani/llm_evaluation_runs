module exponial_mod (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [31:0] m,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK_N   = 3'd1;
    localparam [2:0] BASE_CASE = 3'd2;
    localparam [2:0] CALC_TOT  = 3'd3;
    localparam [2:0] CALC_RECUR = 3'd4;
    localparam [2:0] CALC_POW   = 3'd5;
    localparam [2:0] FINISH     = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] n_reg;
    reg [31:0] m_reg;
    reg [31:0] result_reg;
    reg [7:0] depth_counter;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd250;
    localparam [7:0] MAX_DEPTH = 8'd16;

    // Totient calculation registers
    reg [7:0] tot_n;
    reg [31:0] tot_result;
    reg [7:0] tot_i;
    reg [7:0] tot_gcd_a;
    reg [7:0] tot_gcd_b;
    reg [7:0] tot_gcd_temp;

    // Power calculation registers
    reg [31:0] pow_base;
    reg [7:0] pow_exp;
    reg [31:0] pow_result;
    reg [7:0] pow_counter;

    // Recursive call parameters
    reg [7:0] call_n;
    reg [31:0] call_m;
    reg [31:0] call_result;
    reg call_start;
    wire call_done;
    wire [31:0] call_res;

    // GCD function for totient (combinational)
    function automatic [7:0] gcd_func;
        input [7:0] a, b;
        begin
            if (a == 8'd0)
                gcd_func = b;
            else if (b == 8'd0)
                gcd_func = a;
            else if (a > b)
                gcd_func = gcd_func(b, a);
            else
                gcd_func = gcd_func(b % a, a);
        end
    endfunction

    // Euler's totient function (combinational for n <= 255)
    function automatic [7:0] totient_func;
        input [7:0] val;
        reg [7:0] i;
        reg [7:0] result;
        begin
            result = val;
            for (i = 2; i <= val; i = i + 1) begin
                if (gcd_func(val, i) == 8'd1)
                    result = result - 8'd1;
            end
            totient_func = result;
        end
    endfunction

    // Modular exponentiation (combinational - small exponents only)
    function automatic [31:0] mod_pow_func;
        input [31:0] base;
        input [7:0] exp;
        input [31:0] mod;
        reg [31:0] res;
        reg [7:0] e;
        reg [63:0] temp;
        begin
            res = 32'd1;
            base = base % mod;
            e = exp;
            while (e > 0) begin
                if (e[0] == 1'b1) begin
                    temp = res * base;
                    res = temp % mod;
                end
                temp = base * base;
                base = temp % mod;
                e = e >> 1;
            end
            mod_pow_func = res;
        end
    endfunction

    // Recursive call to exponial_mod
    exponial_mod recursive_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(call_start),
        .n(call_n),
        .m(call_m),
        .result(call_res),
        .done(call_done)
    );

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 8'd0;
            m_reg <= 32'd0;
            result_reg <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            depth_counter <= 8'd0;
            cycle_counter <= 8'd0;
            call_start <= 1'b0;
            tot_n <= 8'd0;
            tot_result <= 8'd0;
            tot_i <= 8'd0;
            tot_gcd_a <= 8'd0;
            tot_gcd_b <= 8'd0;
            tot_gcd_temp <= 8'd0;
            pow_base <= 32'd0;
            pow_exp <= 8'd0;
            pow_result <= 32'd0;
            pow_counter <= 8'd0;
            call_n <= 8'd0;
            call_m <= 32'd0;
            call_result <= 32'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 32'd0;
                    cycle_counter <= 8'd0;
                    depth_counter <= 8'd0;
                    call_start <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        m_reg <= m;
                    end
                end

                CHECK_N: begin
                    cycle_counter <= cycle_counter + 8'd1;
                end

                BASE_CASE: begin
                    result_reg <= result_reg;
                    call_start <= 1'b0;
                end

                CALC_TOT: begin
                    // Initialize totient calculation
                    tot_n <= n_reg - 8'd1;
                    tot_result <= n_reg - 8'd1;
                    tot_i <= 8'd2;
                end

                CALC_RECUR: begin
                    // Set up recursive call
                    call_start <= 1'b0;
                end

                CALC_POW: begin
                    // Start power calculation
                    pow_base <= call_res;
                    pow_exp <= n_reg;
                    pow_result <= 32'd1;
                    pow_counter <= 8'd0;
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= result_reg;
                end
            endcase

            // Totient calculation state machine
            if (state == CALC_TOT && tot_i <= tot_n) begin
                if (gcd_func(tot_n, tot_i) == 8'd1)
                    tot_result <= tot_result - 8'd1;
                tot_i <= tot_i + 8'd1;
            end

            // Recursive call trigger
            if (state == CALC_RECUR && !call_start) begin
                call_start <= 1'b1;
                call_n <= tot_result;
                call_m <= m_reg;
            end

            // Modular power calculation
            if (state == CALC_POW) begin
                if (pow_counter < 8'd31) begin
                    if (pow_exp[pow_counter]) begin
                        result_reg <= (result_reg * pow_base) % m_reg;
                    end
                    pow_base <= (pow_base * pow_base) % m_reg;
                    pow_counter <= pow_counter + 8'd1;
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_N;
                else
                    next_state = IDLE;
            end

            CHECK_N: begin
                if (n_reg == 8'd1) begin
                    result_reg = 32'd1;
                    next_state = FINISH;
                end else if (n_reg == 8'd2) begin
                    result_reg = 32'd2;
                    next_state = FINISH;
                end else if (n_reg == 8'd3) begin
                    result_reg = 32'd9;
                    next_state = FINISH;
                end else if (n_reg == 8'd4) begin
                    // 4^65536 % m
                    result_reg = 32'd262144 % m_reg;
                    next_state = FINISH;
                end else begin
                    next_state = CALC_TOT;
                end
            end

            CALC_TOT: begin
                if (tot_i > tot_n) begin
                    next_state = CALC_RECUR;
                end else begin
                    next_state = CALC_TOT;
                end
            end

            CALC_RECUR: begin
                if (call_done) begin
                    next_state = CALC_POW;
                end else begin
                    next_state = CALC_RECUR;
                end
            end

            CALC_POW: begin
                if (pow_counter >= 8'd31) begin
                    next_state = FINISH;
                end else begin
                    next_state = CALC_POW;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase

        // Safety timeout
        if (cycle_counter >= MAX_CYCLES && state != FINISH && state != IDLE) begin
            next_state = FINISH;
        end
    end

endmodule