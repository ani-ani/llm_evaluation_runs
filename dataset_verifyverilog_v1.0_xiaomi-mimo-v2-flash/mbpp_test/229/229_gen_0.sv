module rearrange_array (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg [7:0] result [0:7],
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] temp_arr [0:7];      // Working array
    reg [3:0] i;                   // Outer loop index
    reg [3:0] j;                   // Inner loop index
    reg [3:0] swap_count;          // Track swaps for stability
    reg [7:0] temp_val;            // Temporary swap value
    reg processing_done;           // Internal done flag
    reg [7:0] cycle_counter;       // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Integer for loop (Icarus compatible)
    integer k;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            // Initialize all registers
            for (k = 0; k < 8; k = k + 1) begin
                result[k] <= 8'd0;
                temp_arr[k] <= 8'd0;
            end
            i <= 4'd0;
            j <= 4'd0;
            swap_count <= 4'd0;
            temp_val <= 8'd0;
            processing_done <= 1'b0;
            cycle_counter <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    swap_count <= 4'd0;
                    processing_done <= 1'b0;
                    
                    if (start) begin
                        // Load input array into temp array
                        for (k = 0; k < 8; k = k + 1) begin
                            temp_arr[k] <= arr[k];
                        end
                        i <= 4'd0;
                        j <= 4'd1;
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // One swap per clock cycle (stable partition)
                    if (cycle_counter >= MAX_CYCLES) begin
                        processing_done <= 1'b1;
                        state <= COMPLETE;
                    end else if (i < len - 4'd1) begin
                        if (j < len) begin
                            // Check if we need to swap
                            // Negative numbers should move left
                            if (temp_arr[j] < 8'sd0 && temp_arr[i] >= 8'sd0) begin
                                // Swap elements at i and j
                                temp_val <= temp_arr[i];
                                temp_arr[i] <= temp_arr[j];
                                temp_arr[j] <= temp_val;
                                swap_count <= swap_count + 4'd1;
                            end
                            j <= j + 4'd1;
                        end else begin
                            // Inner loop done, move to next outer index
                            i <= i + 4'd1;
                            j <= i + 4'd2;  // j starts at i+1 next time
                        end
                    end else begin
                        // Processing complete
                        processing_done <= 1'b1;
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    // Copy result to output
                    for (k = 0; k < 8; k = k + 1) begin
                        result[k] <= temp_arr[k];
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule