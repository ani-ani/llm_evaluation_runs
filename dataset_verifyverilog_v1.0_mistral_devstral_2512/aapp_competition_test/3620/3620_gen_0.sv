module k_colorings(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] N,
    input wire [15:0] k,
    input wire [15:0] P,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] START     = 3'd1;
    localparam [2:0] EXP_LOOP  = 3'd2;
    localparam [2:0] MULT_LOOP = 3'd3;
    localparam [2:0] MOD_OP    = 3'd4;
    localparam [2:0] DONE      = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] T;
    reg [15:0] k_minus_1;
    reg [15:0] exp_counter;
    reg [31:0] product;
    reg [31:0] remainder;
    reg [31:0] divisor;
    reg [31:0] temp_P;
    reg [4:0] shift_count;
    reg [15:0] final_result;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            T <= 16'd1;
            k_minus_1 <= 16'd0;
            exp_counter <= 16'd0;
            product <= 32'd0;
            remainder <= 32'd0;
            divisor <= 32'd0;
            temp_P <= 32'd0;
            shift_count <= 5'd0;
            final_result <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = START;
                end
            end

            START: begin
                next_state = EXP_LOOP;
            end

            EXP_LOOP: begin
                if (exp_counter == N - 1) begin
                    next_state = MULT_LOOP;
                end
            end

            MULT_LOOP: begin
                next_state = MOD_OP;
            end

            MOD_OP: begin
                if (remainder < temp_P) begin
                    if (exp_counter == N - 1) begin
                        next_state = DONE;
                    end else begin
                        next_state = EXP_LOOP;
                    end
                end
            end

            DONE: begin
                if (start) begin
                    next_state = START;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                START: begin
                    k_minus_1 <= k - 16'd1;
                    T <= 16'd1;
                    exp_counter <= 16'd0;
                    temp_P <= {16'd0, P};
                end

                EXP_LOOP: begin
                    // Multiply T by (k-1)
                    product <= T * k_minus_1;
                    remainder <= product;
                    divisor <= temp_P;
                    shift_count <= 5'd0;
                    exp_counter <= exp_counter + 16'd1;
                end

                MULT_LOOP: begin
                    // Compute k * T mod P
                    product <= final_result * k;
                    remainder <= product;
                    divisor <= temp_P;
                    shift_count <= 5'd0;
                end

                MOD_OP: begin
                    // Binary division algorithm
                    if (remainder >= divisor) begin
                        remainder <= remainder - divisor;
                    end
                    if (remainder >= (divisor >> 1)) begin
                        remainder <= remainder - (divisor >> 1);
                    end
                    if (remainder >= (divisor >> 2)) begin
                        remainder <= remainder - (divisor >> 2);
                    end
                    if (remainder >= (divisor >> 3)) begin
                        remainder <= remainder - (divisor >> 3);
                    end
                    if (remainder >= (divisor >> 4)) begin
                        remainder <= remainder - (divisor >> 4);
                    end
                    if (remainder >= (divisor >> 5)) begin
                        remainder <= remainder - (divisor >> 5);
                    end
                    if (remainder >= (divisor >> 6)) begin
                        remainder <= remainder - (divisor >> 6);
                    end
                    if (remainder >= (divisor >> 7)) begin
                        remainder <= remainder - (divisor >> 7);
                    end
                    if (remainder >= (divisor >> 8)) begin
                        remainder <= remainder - (divisor >> 8);
                    end
                    if (remainder >= (divisor >> 9)) begin
                        remainder <= remainder - (divisor >> 9);
                    end
                    if (remainder >= (divisor >> 10)) begin
                        remainder <= remainder - (divisor >> 10);
                    end
                    if (remainder >= (divisor >> 11)) begin
                        remainder <= remainder - (divisor >> 11);
                    end
                    if (remainder >= (divisor >> 12)) begin
                        remainder <= remainder - (divisor >> 12);
                    end
                    if (remainder >= (divisor >> 13)) begin
                        remainder <= remainder - (divisor >> 13);
                    end
                    if (remainder >= (divisor >> 14)) begin
                        remainder <= remainder - (divisor >> 14);
                    end
                    if (remainder >= (divisor >> 15)) begin
                        remainder <= remainder - (divisor >> 15);
                    end
                    if (remainder >= (divisor >> 16)) begin
                        remainder <= remainder - (divisor >> 16);
                    end
                    if (remainder >= (divisor >> 17)) begin
                        remainder <= remainder - (divisor >> 17);
                    end
                    if (remainder >= (divisor >> 18)) begin
                        remainder <= remainder - (divisor >> 18);
                    end
                    if (remainder >= (divisor >> 19)) begin
                        remainder <= remainder - (divisor >> 19);
                    end
                    if (remainder >= (divisor >> 20)) begin
                        remainder <= remainder - (divisor >> 20);
                    end
                    if (remainder >= (divisor >> 21)) begin
                        remainder <= remainder - (divisor >> 21);
                    end
                    if (remainder >= (divisor >> 22)) begin
                        remainder <= remainder - (divisor >> 22);
                    end
                    if (remainder >= (divisor >> 23)) begin
                        remainder <= remainder - (divisor >> 23);
                    end
                    if (remainder >= (divisor >> 24)) begin
                        remainder <= remainder - (divisor >> 24);
                    end
                    if (remainder >= (divisor >> 25)) begin
                        remainder <= remainder - (divisor >> 25);
                    end
                    if (remainder >= (divisor >> 26)) begin
                        remainder <= remainder - (divisor >> 26);
                    end
                    if (remainder >= (divisor >> 27)) begin
                        remainder <= remainder - (divisor >> 27);
                    end
                    if (remainder >= (divisor >> 28)) begin
                        remainder <= remainder - (divisor >> 28);
                    end
                    if (remainder >= (divisor >> 29)) begin
                        remainder <= remainder - (divisor >> 29);
                    end
                    if (remainder >= (divisor >> 30)) begin
                        remainder <= remainder - (divisor >> 30);
                    end
                    if (remainder >= (divisor >> 31)) begin
                        remainder <= remainder - (divisor >> 31);
                    end
                    
                    if (state == EXP_LOOP) begin
                        T <= remainder[15:0];
                    end else begin
                        final_result <= remainder[15:0];
                    end
                end
            end

            DONE: begin
                result <= final_result;
                done <= 1'b1;
            end

            default: begin
                result <= 16'd0;
                done <= 1'b0;
            end
        endcase
        end
    end

endmodule