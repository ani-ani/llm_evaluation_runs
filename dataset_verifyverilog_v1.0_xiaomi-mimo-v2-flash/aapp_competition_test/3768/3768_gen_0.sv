module fruit_card_compression(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] x_i,
    input wire [63:0] y_i,
    output reg result_valid,
    output reg [7:0] result_char,
    output reg [31:0] result_count,
    output reg done,
    output reg impossible
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE   = 3'd1;
    localparam [2:0] OUTPUT    = 3'd2;
    localparam [2:0] CHECK     = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    localparam [2:0] IMPOSSIBLE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [63:0] state_x, state_y;
    reg [63:0] state_x_next, state_y_next;
    reg [31:0] k_reg;
    reg [7:0] char_reg;
    reg [31:0] step_counter;
    localparam [31:0] MAX_STEPS = 32'd200;

    // Computation intermediate signals
    reg [63:0] temp_x, temp_y;
    reg [31:0] div_result, mod_result;
    reg [63:0] k_temp;

    // Always block for state transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            state_x <= 64'd0;
            state_y <= 64'd0;
            k_reg <= 32'd0;
            char_reg <= 8'd0;
            step_counter <= 32'd0;
            result_valid <= 1'b0;
            result_char <= 8'd0;
            result_count <= 32'd0;
            done <= 1'b0;
            impossible <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    impossible <= 1'b0;
                    step_counter <= 32'd0;
                    if (start) begin
                        state_x <= x_i;
                        state_y <= y_i;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Compute k and char
                    if (state_x > state_y) begin
                        // k = min(state_x / state_y, state_x - 1)
                        if (state_y > 64'd1) begin
                            div_result = state_x[63:0] / state_y[63:0];
                            if (div_result < state_x[31:0] - 32'd1) begin
                                k_temp = {32'd0, div_result};
                            end else begin
                                k_temp = {32'd0, state_x[31:0] - 32'd1};
                            end
                        end else begin
                            k_temp = {32'd0, state_x[31:0] - 32'd1};
                        end
                        char_reg <= 8'd65; // 'A'
                        // Update state: (x, y) = (y, x - k*y)
                        state_y_next <= state_x - (k_temp * state_y);
                        state_x_next <= state_y;
                    end else if (state_y > state_x) begin
                        // k = min(state_y / state_x, state_y - 1)
                        if (state_x > 64'd1) begin
                            div_result = state_y[63:0] / state_x[63:0];
                            if (div_result < state_y[31:0] - 32'd1) begin
                                k_temp = {32'd0, div_result};
                            end else begin
                                k_temp = {32'd0, state_y[31:0] - 32'd1};
                            end
                        end else begin
                            k_temp = {32'd0, state_y[31:0] - 32'd1};
                        end
                        char_reg <= 8'd66; // 'B'
                        // Update state: (x, y) = (y - k*x, x)
                        state_x_next <= state_y - (k_temp * state_x);
                        state_y_next <= state_x;
                    end else begin
                        // state_x == state_y (should not happen for valid inputs > 0 unless 1)
                        k_temp = 64'd0;
                        state_x_next <= state_x;
                        state_y_next <= state_y;
                    end
                    
                    k_reg <= k_temp[31:0];
                    state <= OUTPUT;
                    step_counter <= step_counter + 32'd1;
                end

                OUTPUT: begin
                    result_valid <= 1'b1;
                    result_char <= char_reg;
                    result_count <= k_reg;
                    state <= CHECK;
                end

                CHECK: begin
                    result_valid <= 1'b0;
                    // Update state for next iteration
                    state_x <= state_x_next;
                    state_y <= state_y_next;
                    
                    if (state_x_next == 64'd1 && state_y_next == 64'd1) begin
                        state <= FINISH;
                    end else if (state_x_next == 64'd0 || state_y_next == 64'd0) begin
                        state <= IMPOSSIBLE_STATE;
                    end else if (step_counter >= MAX_STEPS) begin
                        // Safety timeout
                        state <= IMPOSSIBLE_STATE;
                    end else begin
                        state <= COMPUTE;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                IMPOSSIBLE_STATE: begin
                    impossible <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule