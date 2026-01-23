module min_diff (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input [2:0] index,
    input data_valid,
    output reg [7:0] min_diff,
    output reg done,
    output reg [2:0] state_out
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam SORT = 3'b010;
    localparam SORT_PASS = 3'b011;
    localparam COMPARE = 3'b100;
    localparam DONE = 3'b101;

    // Array storage
    reg [7:0] arr [0:7];
    
    // Counters and temporary storage
    reg [2:0] load_cnt;
    reg [2:0] i; // outer loop index for bubble sort
    reg [2:0] j; // inner loop index for bubble sort
    reg [2:0] cmp_idx; // index for comparison
    reg [7:0] temp; // temporary swap variable
    reg [7:0] diff; // current difference
    
    // State register
    reg [2:0] state;
    
    // Control signals
    reg sorting_done;
    reg comparison_done;

    // State transition and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_cnt <= 3'b0;
            i <= 3'b0;
            j <= 3'b0;
            cmp_idx <= 3'b0;
            min_diff <= 8'hFF;
            done <= 1'b0;
            state_out <= IDLE;
            sorting_done <= 1'b0;
            comparison_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        state_out <= LOAD;
                        load_cnt <= 3'b0;
                    end
                end

                LOAD: begin
                    if (data_valid) begin
                        arr[index] <= data_in;
                        load_cnt <= load_cnt + 1'b1;
                    end
                    // Transition to SORT when all 8 elements loaded (load_cnt == 8)
                    // We check data_valid && load_cnt == 7 to catch the 8th element
                    if (data_valid && load_cnt == 3'd7) begin
                        state <= SORT;
                        state_out <= SORT;
                        i <= 3'd0;
                    end
                end

                SORT: begin
                    // Initialize inner loop for bubble sort pass
                    if (i < 3'd7) begin // Outer loop runs 7 times for 8 elements
                        j <= 3'd0;
                        state <= SORT_PASS;
                        state_out <= SORT_PASS;
                    end else begin
                        // Sorting complete
                        state <= COMPARE;
                        state_out <= COMPARE;
                        cmp_idx <= 3'd0;
                        min_diff <= 8'hFF; // Initialize min_diff to max possible value
                    end
                end

                SORT_PASS: begin
                    // Compare adjacent elements and swap if needed
                    // Inner loop: iterate through array
                    if (j < 3'd7 - i) begin
                        if (arr[j] > arr[j+1]) begin
                            // Swap
                            temp <= arr[j];
                            arr[j] <= arr[j+1];
                            arr[j+1] <= temp;
                        end
                        j <= j + 1'b1;
                    end else begin
                        // End of this pass
                        i <= i + 1'b1;
                        state <= SORT;
                        state_out <= SORT;
                    end
                end

                COMPARE: begin
                    // Calculate difference between adjacent elements
                    if (arr[cmp_idx] > arr[cmp_idx+1])
                        diff <= arr[cmp_idx] - arr[cmp_idx+1];
                    else
                        diff <= arr[cmp_idx+1] - arr[cmp_idx];
                    
                    // Check if we need to update min_diff (checking previous cycle's diff calculation)
                    // Wait one cycle for subtraction to complete
                    if (cmp_idx > 0) begin
                        if (diff < min_diff)
                            min_diff <= diff;
                    end
                    
                    // Increment index
                    cmp_idx <= cmp_idx + 1'b1;
                    
                    // Check completion (indices 0..6 for 7 pairs)
                    if (cmp_idx == 3'd6) begin
                        state <= DONE;
                        state_out <= DONE;
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    // Hold state until start is pulsed again
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        state_out <= LOAD;
                        load_cnt <= 3'b0;
                    end else begin
                        state <= IDLE;
                        state_out <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                    state_out <= IDLE;
                end
            endcase
        end
    end

endmodule
