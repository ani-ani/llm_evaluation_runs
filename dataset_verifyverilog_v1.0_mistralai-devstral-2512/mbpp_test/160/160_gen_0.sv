module find_solution(
    input clk,
    input rst_n,
    input start,
    input [15:0] a,
    input [15:0] b,
    input [15:0] n,
    output reg [7:0] x,
    output reg [7:0] y,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE_X = 3'd1;
    localparam [2:0] CHECK_Y   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    reg [2:0] state, next_state;
    reg [7:0] x_counter;
    reg [15:0] ax_product;
    reg [15:0] n_minus_ax;
    reg [15:0] y_temp;
    reg [15:0] remainder;
    reg solution_found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd768;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_counter <= 8'd0;
            ax_product <= 16'd0;
            n_minus_ax <= 16'd0;
            y_temp <= 16'd0;
            remainder <= 16'd0;
            solution_found <= 1'b0;
            x <= 8'd0;
            y <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        x_counter <= 8'd0;
                        solution_found <= 1'b0;
                        next_state <= COMPUTE_X;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_X: begin
                    cycle_count <= cycle_count + 8'd1;
                    ax_product <= a * x_counter;
                    next_state <= CHECK_Y;
                end

                CHECK_Y: begin
                    cycle_count <= cycle_count + 8'd1;
                    n_minus_ax <= n - ax_product;
                    remainder <= n_minus_ax % b;
                    if (remainder == 16'd0) begin
                        y_temp <= n_minus_ax / b;
                        if (y_temp[15:8] == 8'd0) begin
                            solution_found <= 1'b1;
                            x <= x_counter;
                            y <= y_temp[7:0];
                        end
                    end
                    next_state <= FINISH;
                end

                FINISH: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (x_counter == 8'd255 || solution_found || cycle_count >= MAX_CYCLES) begin
                        done <= 1'b1;
                        valid <= solution_found;
                        next_state <= IDLE;
                    end else begin
                        x_counter <= x_counter + 8'd1;
                        next_state <= COMPUTE_X;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule