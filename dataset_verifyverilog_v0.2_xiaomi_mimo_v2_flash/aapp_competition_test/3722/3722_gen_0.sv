module string_generator (
    input clk,
    input rst_n,
    input start,
    input [6:0] N,
    input [7:0] c_AA, c_AB, c_BA, c_BB,
    output reg [29:0] result,
    output reg done
);

    parameter MOD = 1000000007;

    // States
    localparam IDLE = 2'b00;
    localparam DECODE = 2'b01;
    localparam ITERATE = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state, next_state;
    reg [6:0] count, next_count;
    reg [29:0] res, next_res;
    reg [29:0] prev, next_prev; // Used for Fibonacci or Shift Reg (MSB)
    reg [7:0] case_type, next_case_type; // 0: Const 1, 1: Power 2, 2: Fibonacci
    reg [29:0] pow2_val, next_pow2_val;

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 0;
            res <= 0;
            prev <= 0;
            case_type <= 0;
            pow2_val <= 0;
        end else begin
            state <= next_state;
            count <= next_count;
            res <= next_res;
            prev <= next_prev;
            case_type <= next_case_type;
            pow2_val <= next_pow2_val;
        end
    end

    // Next State Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_count = count;
        next_res = res;
        next_prev = prev;
        next_case_type = case_type;
        next_pow2_val = pow2_val;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = DECODE;
                    next_count = 0; // Initialize counter
                    next_res = 0;
                    next_prev = 0;
                    next_pow2_val = 0;
                    next_case_type = 0;
                end
            end

            DECODE: begin
                // Logic derived from Python solutions
                // Case 0 (Constant 1): (c_AB==0 & c_AA==0) or (c_AB==1 & c_BB==1)
                if ((c_AB == 0 && c_AA == 0) || (c_AB == 1 && c_BB == 1)) begin
                    next_case_type = 0;
                    next_state = DONE;
                    next_res = 1;
                end
                // Case 1 (Power of 2): c_BA != c_AB
                else if (c_BA != c_AB) begin
                    next_case_type = 1;
                    if (N <= 3) begin
                        next_state = DONE;
                        next_res = 1;
                    end else begin
                        next_state = ITERATE;
                        next_count = N - 3;
                        next_res = 1; // 2^0
                        next_pow2_val = 2; // Base for multiplication
                    end
                end
                // Case 2 (Fibonacci): c_BA == c_AB
                else begin
                    next_case_type = 2;
                    if (N <= 3) begin
                        next_state = DONE;
                        next_res = 1;
                    end else begin
                        next_state = ITERATE;
                        next_count = N - 3;
                        // F(i) = F(i-1) + F(i-2). Start: F(3)=1, F(2)=1
                        next_res = 1; // F(3)
                        next_prev = 1; // F(2)
                    end
                end
            end

            ITERATE: begin
                if (count > 0) begin
                    next_count = count - 1;
                    
                    if (case_type == 1) begin // Power of 2
                        // res = res * 2 % MOD
                        next_res = (res * 2) % MOD;
                    end else if (case_type == 2) begin // Fibonacci
                        // next_res = (res + prev) % MOD
                        // shift: prev becomes old res, res becomes new
                        next_prev = res;
                        next_res = (res + prev) % MOD;
                    end
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                if (!start) begin // Wait for start to go low to allow restarting
                    next_state = IDLE;
                    next_res = 0;
                    next_prev = 0;
                    next_count = 0;
                    next_case_type = 0;
                    next_pow2_val = 0;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
        end else begin
            if (state == DONE) begin
                result <= res;
                done <= 1;
            end else begin
                done <= 0;
                // Keep result stable or reset to 0? Usually stable until next start, 
                // but problem asks to output result. We can keep it at the last valid value.
                if (state == IDLE) result <= 0;
            end
        end
    end

endmodule
