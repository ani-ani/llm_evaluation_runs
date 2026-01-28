module game_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [11:0] numbers [0:3],
    output reg [3:0] count,
    output reg done
);

// State encoding
localparam [3:0] IDLE = 4'd0;
localparam [3:0] INIT_START = 4'd1;
localparam [3:0] BUILD_LINEAR = 4'd2;
localparam [3:0] SPECIAL_CASE = 4'd3;
localparam [3:0] DP_INIT = 4'd4;
localparam [3:0] DP_LOOP = 4'd5;
localparam [3:0] DP_DONE = 4'd6;
localparam [3:0] INCREMENT_START = 4'd7;
localparam [3:0] FINISHED = 4'd8;

reg [3:0] state, next_state;

// Internal registers
reg [2:0] current_start_index;
reg [3:0] count_reg;

// Linear array registers
reg [11:0] B0, B1, B2;
reg [1:0] L;

// DP table registers (signed)
reg signed [5:0] dp00, dp11, dp22, dp01, dp12, dp02;

// DP loop counters
reg [1:0] current_length;
reg [1:0] inner_index;

// Helper function: odd
function automatic [0:0] is_odd;
    input [11:0] num;
    begin
        is_odd = num[0];
    end
endfunction

// Helper function: max of two signed 6-bit numbers
function automatic signed [5:0] max6;
    input signed [5:0] a, b;
    begin
        max6 = (a > b) ? a : b;
    end
endfunction

// State transition and output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        current_start_index <= 0;
        count_reg <= 0;
        B0 <= 0; B1 <= 0; B2 <= 0;
        L <= 0;
        dp00 <= 0; dp11 <= 0; dp22 <= 0; dp01 <= 0; dp12 <= 0; dp02 <= 0;
        current_length <= 0;
        inner_index <= 0;
        count <= 0;
        done <= 0;
    end else begin
        state <= next_state;
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    count_reg <= 0;
                    current_start_index <= 0;
                end
            end

            INIT_START: begin
                // Nothing to do
            end

            BUILD_LINEAR: begin
                // Build linear array for current_start_index
                L <= (N > 1) ? N - 1 : 4'd0;
                case (N)
                    4'd1: begin
                        // No linear array
                    end
                    4'd2: begin
                        B0 <= (current_start_index == 0) ? numbers[1] : numbers[0];
                    end
                    4'd3: begin
                        case (current_start_index)
                            3'd0: begin B0 <= numbers[1]; B1 <= numbers[2]; end
                            3'd1: begin B0 <= numbers[2]; B1 <= numbers[0]; end
                            3'd2: begin B0 <= numbers[0]; B1 <= numbers[1]; end
                        endcase
                    end
                    4'd4: begin
                        case (current_start_index)
                            3'd0: begin B0 <= numbers[1]; B1 <= numbers[2]; B2 <= numbers[3]; end
                            3'd1: begin B0 <= numbers[2]; B1 <= numbers[3]; B2 <= numbers[0]; end
                            3'd2: begin B0 <= numbers[3]; B1 <= numbers[0]; B2 <= numbers[1]; end
                            3'd3: begin B0 <= numbers[0]; B1 <= numbers[1]; B2 <= numbers[2]; end
                        endcase
                    end
                endcase
            end

            SPECIAL_CASE: begin
                // L=0
                if (is_odd(numbers[current_start_index])) begin
                    count_reg <= count_reg + 4'd1;
                end
            end

            DP_INIT: begin
                if (L >= 1) dp00 <= is_odd(B0) ? 6'sd1 : 6'sd0;
                if (L >= 2) dp11 <= is_odd(B1) ? 6'sd1 : 6'sd0;
                if (L >= 3) dp22 <= is_odd(B2) ? 6'sd1 : 6'sd0;
                current_length <= 2;
                inner_index <= 0;
            end

            DP_LOOP: begin
                if (current_length == 2) begin
                    case (inner_index)
                        2'd0: begin
                            if (L >= 2)
                                dp01 <= max6( (is_odd(B0) - dp11), (is_odd(B1) - dp00) );
                        end
                        2'd1: begin
                            if (L >= 3)
                                dp12 <= max6( (is_odd(B1) - dp22), (is_odd(B2) - dp11) );
                        end
                    endcase
                end else if (current_length == 3) begin
                    if (inner_index == 0 && L >= 3)
                        dp02 <= max6( (is_odd(B0) - dp12), (is_odd(B2) - dp01) );
                end

                inner_index <= inner_index + 2'd1;
                if (inner_index + 2'd1 >= L - current_length) begin
                    inner_index <= 0;
                    current_length <= current_length + 2'd1;
                end
            end

            DP_DONE: begin
                reg signed [5:0] dp_value;
                case (L)
                    3'd1: dp_value = dp00;
                    3'd2: dp_value = dp01;
                    3'd3: dp_value = dp02;
                    default: dp_value = 0;
                endcase
                if (is_odd(numbers[current_start_index]) - dp_value > 0)
                    count_reg <= count_reg + 4'd1;
            end

            INCREMENT_START: begin
                current_start_index <= current_start_index + 3'd1;
            end

            FINISHED: begin
                count <= count_reg;
                done <= 1;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = INIT_START;
        INIT_START: next_state = BUILD_LINEAR;
        BUILD_LINEAR: begin
            if (N == 1) next_state = SPECIAL_CASE;
            else next_state = DP_INIT;
        end
        SPECIAL_CASE: next_state = INCREMENT_START;
        DP_INIT: begin
            if (L == 1) next_state = DP_DONE;
            else next_state = DP_LOOP;
        end
        DP_LOOP: begin
            if (current_length > L) next_state = DP_DONE;
            else next_state = DP_LOOP;
        end
        DP_DONE: next_state = INCREMENT_START;
        INCREMENT_START: begin
            if (current_start_index + 3'd1 >= N) next_state = FINISHED;
            else next_state = BUILD_LINEAR;
        end
        FINISHED: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

endmodule