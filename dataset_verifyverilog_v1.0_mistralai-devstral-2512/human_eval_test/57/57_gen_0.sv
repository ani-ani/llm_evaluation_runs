module MonotonicChecker(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr [0:7],
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] count;
    reg signed [7:0] captured_arr [0:7];
    reg [3:0] captured_len;
    reg direction_set;
    reg is_increasing;
    reg is_decreasing;

    // Capture input array and length on start
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            count <= 4'd0;
            direction_set <= 1'b0;
            is_increasing <= 1'b0;
            is_decreasing <= 1'b0;
            captured_len <= 4'd0;
            // Initialize array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                captured_arr[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Capture inputs
                        captured_len <= len;
                        integer j;
                        for (j = 0; j < 8; j = j + 1) begin
                            captured_arr[j] <= arr[j];
                        end
                        count <= 4'd0;
                        direction_set <= 1'b0;
                        is_increasing <= 1'b0;
                        is_decreasing <= 1'b0;
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Check if we've compared all elements
                    if (count >= captured_len - 4'd1) begin
                        // All comparisons done
                        if (captured_len < 4'd2) begin
                            result <= 1'b1;  // len=0 or 1 is trivially monotonic
                        end else if (!direction_set) begin
                            result <= 1'b1;  // All elements equal
                        end else begin
                            result <= (is_increasing || is_decreasing);
                        end
                        state <= COMPLETE;
                    end else begin
                        // Perform comparison
                        if (!direction_set) begin
                            // First comparison - set direction
                            if (captured_arr[count] < captured_arr[count + 4'd1]) begin
                                is_increasing <= 1'b1;
                                is_decreasing <= 1'b0;
                                direction_set <= 1'b1;
                            end else if (captured_arr[count] > captured_arr[count + 4'd1]) begin
                                is_increasing <= 1'b0;
                                is_decreasing <= 1'b1;
                                direction_set <= 1'b1;
                            end
                            // If equal, direction remains unset
                        end else begin
                            // Subsequent comparisons
                            if (is_increasing && (captured_arr[count] > captured_arr[count + 4'd1])) begin
                                result <= 1'b0;  // Violates increasing
                            end else if (is_decreasing && (captured_arr[count] < captured_arr[count + 4'd1])) begin
                                result <= 1'b0;  // Violates decreasing
                            end
                        end
                        count <= count + 4'd1;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule