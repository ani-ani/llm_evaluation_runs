module find_largest_even (
    input clk,
    input rst_n,
    input start,
    input [15:0] x,
    input [15:0] y,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_RANGE = 3'd1;
    localparam [2:0] CHECK_EVEN  = 3'd2;
    localparam [2:0] CHECK_X_EQ_Y = 3'd3;
    localparam [2:0] COMPUTE_EVEN = 3'd4;
    localparam [2:0] SET_DONE     = 3'd5;
    
    reg [2:0] state, next_state;
    reg [15:0] x_reg, y_reg;
    reg computation_needed;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            x_reg <= 16'd0;
            y_reg <= 16'd0;
            computation_needed <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x_reg <= x;
                        y_reg <= y;
                        state <= CHECK_RANGE;
                    end
                end
                
                CHECK_RANGE: begin
                    if (x_reg > y_reg) begin
                        result <= 16'hFFFF;  // -1
                        state <= SET_DONE;
                    end else begin
                        computation_needed <= 1'b1;
                        state <= CHECK_EVEN;
                    end
                end
                
                CHECK_EVEN: begin
                    if (computation_needed && !y_reg[0]) begin
                        result <= y_reg;  // y is even
                        state <= SET_DONE;
                    end else if (computation_needed && y_reg[0]) begin
                        state <= CHECK_X_EQ_Y;
                    end
                end
                
                CHECK_X_EQ_Y: begin
                    if (x_reg == y_reg) begin
                        result <= 16'hFFFF;  // -1, no even number in range
                        state <= SET_DONE;
                    end else begin
                        state <= COMPUTE_EVEN;
                    end
                end
                
                COMPUTE_EVEN: begin
                    result <= y_reg - 16'd1;  // y-1 is guaranteed even
                    state <= SET_DONE;
                end
                
                SET_DONE: begin
                    done <= 1'b1;
                    computation_needed <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule