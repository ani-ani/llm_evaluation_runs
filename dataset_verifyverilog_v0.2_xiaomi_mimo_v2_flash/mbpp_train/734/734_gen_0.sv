module sum_of_products (
    input clk,
    input rst_n,
    input start,
    input [7:0] array_size,
    input [7:0] arr [0:7],
    output reg [31:0] result,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [3:0] i;
    reg [31:0] res;
    reg [31:0] total;

    // Combinational logic for increment calculation
    wire [31:0] incr;
    assign incr = arr[i] * (1 + res);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'b0;
            i <= 4'b0;
            res <= 32'b0;
            total <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (array_size == 8'd0) begin
                            // Handle empty array: go straight to DONE
                            total <= 32'b0;
                            state <= DONE;
                        end else begin
                            // Initialize for processing
                            i <= array_size - 1'b1;
                            res <= 32'b0;
                            total <= 32'b0;
                            state <= PROCESSING;
                        end
                    end
                end

                PROCESSING: begin
                    // Update total and res with the current element's contribution
                    total <= total + incr;
                    res <= incr;

                    // Check if we just processed the last element (index 0)
                    if (i == 4'd0) begin
                        state <= DONE;
                    end else begin
                        i <= i - 1'b1;
                    end
                end

                DONE: begin
                    // Capture the final result and assert done
                    result <= total;
                    done <= 1'b1;
                    // Remain in DONE state until reset
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule