module fruit_game_compressor(
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

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] OUTPUT  = 3'd2;
    localparam [2:0] CHECK   = 3'd3;
    localparam [2:0] FINISH  = 3'd4;

    reg [2:0] state;
    reg [63:0] state_x, state_y;
    reg [7:0] char_reg;
    reg [31:0] count_reg;
    reg [7:0] step_counter;
    localparam [7:0] MAX_STEPS = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            state_x <= 64'd0;
            state_y <= 64'd0;
            char_reg <= 8'd0;
            count_reg <= 32'd0;
            step_counter <= 8'd0;
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
                    step_counter <= 8'd0;
                    if (start) begin
                        state_x <= x_i;
                        state_y <= y_i;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    step_counter <= step_counter + 8'd1;
                    if (state_x > state_y) begin
                        if (state_y == 64'd0) begin
                            state <= CHECK;
                        end else begin
                            count_reg <= state_x / state_y;
                            if (count_reg > state_x - 64'd1) begin
                                count_reg <= state_x - 64'd1;
                            end
                            char_reg <= 8'd65; // 'A'
                            state <= OUTPUT;
                        end
                    end else if (state_y > state_x) begin
                        if (state_x == 64'd0) begin
                            state <= CHECK;
                        end else begin
                            count_reg <= state_y / state_x;
                            if (count_reg > state_y - 64'd1) begin
                                count_reg <= state_y - 64'd1;
                            end
                            char_reg <= 8'd66; // 'B'
                            state <= OUTPUT;
                        end
                    end else begin
                        state <= CHECK;
                    end
                end

                OUTPUT: begin
                    result_valid <= 1'b1;
                    result_char <= char_reg;
                    result_count <= count_reg;
                    if (char_reg == 8'd65) begin // 'A'
                        state_x <= state_x - (count_reg * state_y);
                    end else begin // 'B'
                        state_y <= state_y - (count_reg * state_x);
                    end
                    state <= CHECK;
                end

                CHECK: begin
                    result_valid <= 1'b0;
                    if (state_x == 64'd1 && state_y == 64'd1) begin
                        state <= FINISH;
                    end else if (state_x == 64'd0 || state_y == 64'd0 || step_counter >= MAX_STEPS) begin
                        impossible <= 1'b1;
                        state <= FINISH;
                    end else begin
                        state <= COMPUTE;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule