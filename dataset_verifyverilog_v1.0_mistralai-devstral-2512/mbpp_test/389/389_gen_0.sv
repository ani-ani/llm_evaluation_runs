module LucasGenerator(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] COMPUTING = 2'd1;
    localparam [1:0] DONE      = 2'd2;

    // State and counter registers
    reg [1:0] state;
    reg [3:0] counter;

    // Lucas sequence registers
    reg [15:0] prev;
    reg [15:0] curr;
    reg [15:0] next;

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            counter <= 4'd0;
            prev <= 16'd0;
            curr <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Handle n=0 and n=1 combinatorially
                        if (n == 4'd0) begin
                            result <= 16'd2;
                            state <= DONE;
                        end else if (n == 4'd1) begin
                            result <= 16'd1;
                            state <= DONE;
                        end else begin
                            // Initialize for iterative computation
                            prev <= 16'd2;  // L0
                            curr <= 16'd1;  // L1
                            counter <= 4'd2; // Start from i=2
                            state <= COMPUTING;
                        end
                    end
                end

                COMPUTING: begin
                    // Compute next Lucas number
                    next <= prev + curr;

                    // Update registers for next iteration
                    prev <= curr;
                    curr <= next;

                    // Check if we've reached the target n
                    if (counter == n) begin
                        result <= curr;
                        state <= DONE;
                    end else begin
                        counter <= counter + 4'd1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule