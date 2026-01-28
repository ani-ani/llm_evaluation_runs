module LargestEvenInRange(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] x,
    input wire [15:0] y,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd32;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if x > y
                    if (x > y) begin
                        result <= 16'hFFFF;
                        state <= FINISH;
                    end
                    // Check if y is even
                    else if (y[0] == 1'b0) begin
                        result <= y;
                        state <= FINISH;
                    end
                    // Check if x == y and y is odd
                    else if (x == y) begin
                        result <= 16'hFFFF;
                        state <= FINISH;
                    end
                    // Otherwise, result is y - 1
                    else begin
                        result <= y - 16'd1;
                        state <= FINISH;
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