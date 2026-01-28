module CheckAllEqual (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] values [0:15],
    input wire signed [7:0] target,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    reg [1:0] state;
    reg [3:0] counter; // Counter for 16 values (0-15)
    reg all_equal;
    reg start_dly; // Delayed start signal to detect rising edge

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Synchronous reset
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            counter <= 4'd0;
            all_equal <= 1'b0; // Default: assume not equal until proven
            start_dly <= 1'b0;
        end else begin
            // Default assignments
            done <= 1'b0;
            start_dly <= start;

            case (state)
                IDLE: begin
                    result <= 1'b0;
                    counter <= 4'd0;
                    // Wait for rising edge of start signal
                    if (start && !start_dly) begin
                        // Initialize all_equal to 1 (assuming all match until mismatch found)
                        all_equal <= 1'b1;
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Compare current value with target
                    if (values[counter] != target) begin
                        all_equal <= 1'b0;
                    end

                    // Increment counter
                    counter <= counter + 4'd1;

                    // After checking all 16 values (counter wraps from 15 to 0)
                    if (counter == 4'd15) begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    // Final result is the accumulated 'all_equal' flag
                    result <= all_equal;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule