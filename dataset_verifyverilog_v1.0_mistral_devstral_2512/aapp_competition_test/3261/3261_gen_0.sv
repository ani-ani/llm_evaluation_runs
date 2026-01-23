module zigzag_grey_counter(
    input clk,
    input rst_n,
    input start,
    input [15:0] K,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    reg [3:0] row;
    reg [3:0] col;
    reg [3:0] diagonal;
    reg [3:0] visited_count;
    reg [15:0] grey_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            row <= 4'd0;
            col <= 4'd0;
            diagonal <= 4'd0;
            visited_count <= 4'd0;
            grey_count <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        row <= 4'd0;
                        col <= 4'd0;
                        diagonal <= 4'd0;
                        visited_count <= 4'd0;
                        grey_count <= 16'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if current cell is grey
                    if ((row & col) == 4'd0) begin
                        grey_count <= grey_count + 16'd1;
                    end

                    // Move to next cell in zig-zag pattern
                    if ((diagonal % 2) == 1'b0) begin
                        // Even diagonal: (0,d) to (d,0)
                        if (row < diagonal) begin
                            row <= row + 4'd1;
                            col <= col - 4'd1;
                        end else begin
                            // Move to next diagonal
                            diagonal <= diagonal + 4'd1;
                            if (diagonal < 4'd4) begin
                                row <= diagonal;
                                col <= 4'd0;
                            end
                        end
                    end else begin
                        // Odd diagonal: (d,0) to (0,d)
                        if (col < diagonal) begin
                            row <= row - 4'd1;
                            col <= col + 4'd1;
                        end else begin
                            // Move to next diagonal
                            diagonal <= diagonal + 4'd1;
                            if (diagonal < 4'd4) begin
                                row <= 4'd0;
                                col <= diagonal;
                            end
                        end
                    end

                    visited_count <= visited_count + 4'd1;

                    // Check if we've visited K cells or reached end
                    if ((visited_count == K) || (diagonal >= 4'd4) || (cycle_count >= MAX_CYCLES)) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= grey_count;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule