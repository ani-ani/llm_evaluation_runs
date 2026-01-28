module MinAbsDiffFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SORT    = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] DONE    = 3'd3;

    reg [2:0] state, next_state;
    reg [7:0] sorted_arr [0:7];  // Working array for sorting
    reg [3:0] i, j;               // Loop counters
    reg [3:0] pass_count;         // Bubble sort passes
    reg [8:0] min_diff, temp_diff; // 9-bit for differences
    reg [7:0] temp_swap;          // For swapping
    reg swapping;                 // Flag for bubble sort
    reg [7:0] cycle_count;        // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Combinational logic for sorting
    reg do_swap;
    always @(*) begin
        if (pass_count < len - 1 && i < len - 2'd1) begin
            do_swap = (sorted_arr[i] > sorted_arr[i + 1]);
        end else begin
            do_swap = 1'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize all registers and arrays
            for (integer k = 0; k < 8; k = k + 1) begin
                sorted_arr[k] <= 8'd0;
            end
            i <= 4'd0;
            j <= 4'd0;
            pass_count <= 4'd0;
            min_diff <= 9'd0;
            temp_diff <= 9'd0;
            temp_swap <= 8'd0;
            swapping <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    // Reset loop variables
                    i <= 4'd0;
                    j <= 4'd0;
                    pass_count <= 4'd0;
                    if (start) begin
                        // Load input array into sorted_arr
                        for (integer k = 0; k < 8; k = k + 1) begin
                            if (k < len) begin
                                sorted_arr[k] <= arr[k];
                            end else begin
                                sorted_arr[k] <= 8'd0;
                            end
                        end
                        state <= SORT;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Bubble sort: 7 passes max for 8 elements
                    if (len > 4'd1) begin
                        if (pass_count < len - 1) begin
                            if (i < len - 2'd1) begin
                                // Compare and possibly swap
                                if (sorted_arr[i] > sorted_arr[i + 1]) begin
                                    // Swap
                                    temp_swap <= sorted_arr[i];
                                    sorted_arr[i] <= sorted_arr[i + 1];
                                    sorted_arr[i + 1] <= temp_swap;
                                    swapping <= 1'b1;
                                end else begin
                                    swapping <= 1'b0;
                                end
                                i <= i + 1'b1;
                            end else begin
                                // End of one pass
                                i <= 4'd0;
                                pass_count <= pass_count + 1'b1;
                            end
                        end else begin
                            // Sorting complete
                            pass_count <= 4'd0;
                            i <= 4'd0;
                            min_diff <= 9'd255; // Initialize with max possible diff
                            state <= COMPARE;
                        end
                    end else begin
                        // len <= 1, no sorting needed
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Find minimum difference between adjacent pairs
                    if (len <= 4'd1) begin
                        // Handle edge cases
                        if (len == 4'd1) begin
                            result <= 16'd255; // Max diff for single element
                        end else begin
                            result <= 16'd0; // Invalid or empty
                        end
                        state <= DONE;
                    end else begin
                        if (i < len - 2'd1) begin
                            // Calculate difference
                            if (sorted_arr[i] >= sorted_arr[i + 1]) begin
                                temp_diff <= {1'b0, sorted_arr[i]} - {1'b0, sorted_arr[i + 1]};
                            end else begin
                                temp_diff <= {1'b0, sorted_arr[i + 1]} - {1'b0, sorted_arr[i]};
                            end
                            // Update minimum difference
                            if (temp_diff < min_diff) begin
                                min_diff <= temp_diff;
                            end
                            i <= i + 1'b1;
                        end else begin
                            // Check last comparison
                            if (len > 4'd1) begin
                                if (sorted_arr[len - 2'd1] >= sorted_arr[len - 2'd2]) begin
                                    temp_diff <= {1'b0, sorted_arr[len - 2'd1]} - {1'b0, sorted_arr[len - 2'd2]};
                                end else begin
                                    temp_diff <= {1'b0, sorted_arr[len - 2'd2]} - {1'b0, sorted_arr[len - 2'd1]};
                                end
                                if (temp_diff < min_diff) begin
                                    min_diff <= temp_diff;
                                end
                            end
                            result <= {7'd0, min_diff}; // Pad to 16-bit
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule