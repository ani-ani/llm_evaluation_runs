module string_generator (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [6:0] N,
    input [7:0] c_AA, c_AB, c_BA, c_BB
);
    output reg [29:0] result;
    output reg done;

    reg [1:0] state;
    reg [29:0] result_int;
    reg done_int;

    // Parameters
    localparam MOD = 1000000007;

    // Registers for case1 and case2
    reg [29:0] pow_val;
    reg [6:0] pow_cnt;
    reg [29:0] fib_a, fib_b;
    reg [6:0] fib_cnt;
    reg [1:0] case_type;

    // Temporary variables for arithmetic
    reg [31:0] temp;
    reg [29:0] pow_val_next;
    reg [30:0] sum;
    reg [29:0] fib_a_next, fib_b_next;

    // Default assignments
    always @(*) begin
        result = 30'b0;
        done = 1'b0;
        state = 2'b00;
        result_int = 30'b0;
        done_int = 1'b0;
        pow_val = 30'b0;
        pow_cnt = 7'b0;
        fib_a = 30'b0;
        fib_b = 30'b0;
        fib_cnt = 7'b0;
        case_type = 2'b00;
        temp = 32'b0;
        pow_val_next = 30'b0;
        sum = 31'b0;
        fib_a_next = 30'b0;
        fib_b_next = 30'b0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 2'b00;
            result_int <= 30'b0;
            done_int <= 1'b0;
            pow_val <= 30'b0;
            pow_cnt <= 7'b0;
            fib_a <= 30'b0;
            fib_b <= 30'b0;
            fib_cnt <= 7'b0;
            case_type <= 2'b00;
        end else begin
            if (state == 2'b00) begin
                if (start) begin
                    state <= 2'b01;
                end
            end else if (state == 2'b01) begin
                if (N == 2 || N == 3) begin
                    result_int <= 30'b1;
                    done_int <= 1'b1;
                    state <= 2'b11;
                end else begin
                    if (((c_AB[0] == 0) && (c_AA[0] == 0)) || ((c_AB[0] == 1) && (c_BB[0] == 1))) begin
                        result_int <= 30'b1;
                        done_int <= 1'b1;
                        state <= 2'b11;
                    end else begin
                        if (c_BA[0] != c_AB[0]) begin
                            case_type <= 2'b00;
                            pow_cnt <= N - 3;
                            if (pow_cnt < 0) pow_cnt <= 7'b0;
                            pow_val <= 30'b1;
                            state <= 2'b10;
                        end else begin
                            case_type <= 2'b01;
                            fib_a <= 30'b1;
                            fib_b <= 30'b1;
                            fib_cnt <= N - 3;
                            if (fib_cnt < 0) fib_cnt <= 7'b0;
                            state <= 2'b10;
                        end
                    end
                end
            end else if (state == 2'b10) begin
                if (case_type == 2'b00) begin
                    if (pow_cnt == 0) begin
                        result_int <= pow_val;
                        done_int <= 1'b1;
                        state <= 2'b11;
                    end else begin
                        temp = pow_val * 2;
                        pow_val_next = (temp >= MOD) ? temp - MOD : temp;
                        pow_val <= pow_val_next;
                        pow_cnt <= pow_cnt - 1;
                    end
                end else if (case_type == 2'b01) begin
                    if (fib_cnt == 0) begin
                        result_int <= fib_a;
                        done_int <= 1'b1;
                        state <= 2'b11;
                    end else begin
                        sum = fib_a + fib_b;
                        fib_a_next = (sum >= MOD) ? sum - MOD : sum;
                        fib_b_next = fib_a;
                        fib_a <= fib_a_next;
                        fib_b <= fib_b_next;
                        fib_cnt <= fib_cnt - 1;
                    end
                end
            end
        end
    end

    assign result = result_int;
    assign done = done_int;
endmodule