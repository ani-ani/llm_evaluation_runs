module repeating_decimal_converter(
    input clk,
    input rst_n,
    input start,
    input [7:0] decimal_int_part,
    input [31:0] decimal_frac_part,
    input [3:0] frac_digits,
    input [3:0] repeat_count,
    output reg [63:0] numerator,
    output reg [63:0] denominator,
    output reg done,
    output reg error
);

    // FSM States
    localparam IDLE = 4'd0;
    localparam PARSE = 4'd1;
    localparam COMPUTE_SCALED = 4'd2;
    localparam CALCULATE_GCD = 4'd3;
    localparam REDUCE = 4'd4;
    localparam DONE = 4'd5;
    localparam ERROR_STATE = 4'd6;

    // Internal Registers
    reg [3:0] state;
    reg [3:0] next_state;

    // Temporary registers for computation
    reg [63:0] num;
    reg [63:0] den;
    reg [63:0] gcd_a;
    reg [63:0] gcd_b;
    reg [63:0] gcd_temp;

    // Intermediate calculation registers
    reg [63:0] pow10_L;
    reg [63:0] pow10_L_minus_K;
    reg [63:0] pow10_K;

    reg [7:0] L; // frac_digits
    reg [7:0] K; // repeat_count
    reg [7:0] I; // int part
    reg [31:0] F; // frac part

    reg [7:0] A_len; // non-repeating fractional digits length
    reg [63:0] A_val; // value of non-repeating part
    reg [63:0] B_val; // value of repeating part

    reg [7:0] counter;
    reg gcd_done;

    // Power of 10 calculation registers
    reg [7:0] pow_counter;

    // Sequential State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            error <= 0;
            numerator <= 0;
            denominator <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PARSE;
            end
            PARSE: begin
                if (frac_digits < repeat_count || repeat_count == 0 || frac_digits == 0 || frac_digits > 8 || repeat_count > 8)
                    next_state = ERROR_STATE;
                else
                    next_state = COMPUTE_SCALED;
            end
            COMPUTE_SCALED: begin
                next_state = CALCULATE_GCD;
            end
            CALCULATE_GCD: begin
                if (gcd_done) next_state = REDUCE;
            end
            REDUCE: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            ERROR_STATE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            error <= 0;
            numerator <= 0;
            denominator <= 0;
            num <= 0;
            den <= 0;
            gcd_a <= 0;
            gcd_b <= 0;
            pow10_L <= 0;
            pow10_L_minus_K <= 0;
            pow10_K <= 0;
            counter <= 0;
            pow_counter <= 0;
            A_len <= 0;
            A_val <= 0;
            B_val <= 0;
            I <= 0;
            F <= 0;
            L <= 0;
            K <= 0;
            gcd_done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    error <= 0;
                    gcd_done <= 0;
                    if (start) begin
                        I <= decimal_int_part;
                        F <= decimal_frac_part;
                        L <= frac_digits;
                        K <= repeat_count;
                    end
                end

                PARSE: begin
                    if (L >= K) begin
                        A_len <= L - K;
                    end
                end

                COMPUTE_SCALED: begin
                    if (counter == 0) begin
                        pow10_L <= 1;
                        pow10_L_minus_K <= 1;
                        pow10_K <= 1;
                    end else if (counter <= 8) begin
                        if (counter < L) pow10_L <= pow10_L * 10;
                        if (counter < K) pow10_K <= pow10_K * 10;
                        if (counter < (L - K)) pow10_L_minus_K <= pow10_L_minus_K * 10;
                    end else if (counter == 9) begin
                        A_val <= F / pow10_K;
                        B_val <= F % pow10_K;
                        counter <= 0;
                    end else if (counter <= 8) begin
                        num <= I * (pow10_L - pow10_L_minus_K) + A_val * (pow10_K - 1) + B_val;
                        den <= (pow10_L - pow10_L_minus_K) * (pow10_K - 1);
                        counter <= 10;
                    end
                end

                CALCULATE_GCD: begin
                    if (counter == 0) begin
                        gcd_a <= num;
                        gcd_b <= den;
                        gcd_done <= 0;
                        if (den == 0) begin
                            gcd_done <= 1;
                            if (num == 0) error <= 1;
                            else error <= 1;
                        end else if (num == 0) begin
                            gcd_done <= 1;
                        end else begin
                            counter <= 1;
                        end
                    end else begin
                        if (gcd_b != 0) begin
                            gcd_temp <= gcd_a % gcd_b;
                            gcd_a <= gcd_b;
                            gcd_b <= gcd_temp;
                        end else begin
                            gcd_done <= 1;
                        end
                    end
                end

                REDUCE: begin
                    numerator <= num / gcd_a;
                    denominator <= den / gcd_a;
                end

                DONE: begin
                    done <= 1;
                end

                ERROR_STATE: begin
                    error <= 1;
                    done <= 1;
                end
            endcase
        end
    end

    // Combinational Logic for GCD next state values
    wire [63:0] next_gcd_a;
    wire [63:0] next_gcd_b;
    wire gcd_b_zero;

    assign next_gcd_a = (state == CALCULATE_GCD && counter == 0) ? num : gcd_b;
    assign next_gcd_b = (state == CALCULATE_GCD && counter == 0) ? den : (gcd_a % gcd_b);
    assign gcd_b_zero = (gcd_b == 0);

    // Re-writing the GCD block cleanly
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
        end else if (state == CALCULATE_GCD) begin
            if (counter == 0) begin
                if (den == 0) begin
                    gcd_a <= 1;
                    gcd_b <= 0;
                end else if (num == 0) begin
                    gcd_a <= den;
                    gcd_b <= 0;
                end else begin
                    gcd_a <= num;
                    gcd_b <= den;
                end
                counter <= 1;
            end else begin
                if (gcd_b != 0) begin
                    gcd_a <= next_gcd_b;
                    gcd_b <= next_gcd_a % next_gcd_b;
                    if ((gcd_a % gcd_b) == 0) begin
                        gcd_a <= gcd_b;
                        gcd_b <= 0;
                        counter <= counter + 1;
                    end else begin
                        gcd_a <= gcd_b;
                        gcd_b <= gcd_a % gcd_b;
                        counter <= counter + 1;
                    end
                end else begin
                end
            end
        end
    end

endmodule