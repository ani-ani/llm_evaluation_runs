module MaxShowsRecorder (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input signed [31:0] x [0:15],
    input signed [31:0] y [0:15],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_SORT = 3'd1;
    localparam [2:0] SORTING   = 3'd2;
    localparam [2:0] SCHEDULE  = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] i, j;           // Loop counters for sorting
    reg [3:0] show_idx;       // Current show being scheduled
    reg [1:0] slot_idx;       // Current slot being checked (k <= 4)
    reg [15:0] count;         // Number of shows scheduled
    reg cycle_count;          // Additional cycle counter

    // Sorted arrays
    reg signed [31:0] sorted_x [0:15];
    reg signed [31:0] sorted_y [0:15];
    
    // Slot end times (k slots, max 4)
    reg signed [31:0] slot_end_time [0:3];
    
    // Slot availability flag
    reg slot_available;
    reg slot_found;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            show_idx <= 4'd0;
            slot_idx <= 2'd0;
            count <= 16'd0;
            cycle_count <= 1'b0;
            slot_available <= 1'b0;
            slot_found <= 1'b0;
            // Initialize sorted arrays
            for (int idx = 0; idx < 16; idx = idx + 1) begin
                sorted_x[idx] <= 32'sd0;
                sorted_y[idx] <= 32'sd0;
            end
            // Initialize slot end times to minimum (most negative)
            for (int sidx = 0; sidx < 4; sidx = sidx + 1) begin
                slot_end_time[sidx] <= 32'h80000000; // -2^31
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Copy input to sorted arrays
                        for (int idx = 0; idx < 16; idx = idx + 1) begin
                            if (idx < n) begin
                                sorted_x[idx] <= x[idx];
                                sorted_y[idx] <= y[idx];
                            end else begin
                                sorted_x[idx] <= 32'sd0;
                                sorted_y[idx] <= 32'sd0;
                            end
                        end
                        i <= 4'd0;
                        j <= 4'd0;
                        count <= 16'd0;
                        // Initialize slot end times
                        for (int sidx = 0; sidx < 4; sidx = sidx + 1) begin
                            if (sidx < k) begin
                                slot_end_time[sidx] <= 32'sd0; // Available immediately
                            end else begin
                                slot_end_time[sidx] <= 32'h80000000; // Unused
                            end
                        end
                    end
                end
                
                INIT_SORT: begin
                    i <= 4'd1;
                    j <= 4'd0;
                end
                
                SORTING: begin
                    if (j < n - 4'd1 - i) begin
                        if (sorted_y[j] > sorted_y[j + 4'd1]) begin
                            // Swap y
                            sorted_y[j] <= sorted_y[j + 4'd1];
                            sorted_y[j + 4'd1] <= sorted_y[j];
                            // Swap x
                            sorted_x[j] <= sorted_x[j + 4'd1];
                            sorted_x[j + 4'd1] <= sorted_x[j];
                        end
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd0;
                        i <= i + 4'd1;
                        if (i >= n - 4'd1) begin
                            show_idx <= 4'd0;
                            slot_idx <= 2'd0;
                            slot_available <= 1'b0;
                            slot_found <= 1'b0;
                        end
                    end
                end
                
                SCHEDULE: begin
                    if (show_idx < n) begin
                        // Check slots for availability
                        if (slot_idx < k) begin
                            if (slot_end_time[slot_idx] <= sorted_x[show_idx]) begin
                                slot_available <= 1'b1;
                                slot_found <= 1'b1;
                            end else begin
                                slot_available <= slot_available; // Keep previous if found earlier
                            end
                            slot_idx <= slot_idx + 2'd1;
                        end else begin
                            // Done checking slots
                            if (slot_found) begin
                                // Find first available slot again (simplified: check from 0)
                                // For simplicity, assign to first available found
                                for (int s = 0; s < 4; s = s + 1) begin
                                    if (s < k && slot_end_time[s] <= sorted_x[show_idx] && !slot_available) begin
                                        slot_end_time[s] <= sorted_y[show_idx];
                                        slot_available <= 1'b1;
                                    end
                                end
                                count <= count + 16'd1;
                            end
                            // Reset for next show
                            slot_idx <= 2'd0;
                            show_idx <= show_idx + 4'd1;
                            slot_available <= 1'b0;
                            slot_found <= 1'b0;
                        end
                    end
                end
                
                FINISH: begin
                    result <= count;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (n > 4'd1) next_state = INIT_SORT;
                    else next_state = SCHEDULE;
                end
            end
            INIT_SORT: next_state = SORTING;
            SORTING: begin
                if (i >= n - 4'd1) begin
                    next_state = SCHEDULE;
                end else begin
                    if (j >= n - 4'd1 - i) begin
                        next_state = INIT_SORT;
                    end else begin
                        next_state = SORTING;
                    end
                end
            end
            SCHEDULE: begin
                if (show_idx >= n) begin
                    next_state = FINISH;
                end else if (slot_idx >= k && !slot_found) begin
                    next_state = SCHEDULE; // Continue to next show
                end else if (slot_idx >= k && slot_found) begin
                    next_state = SCHEDULE; // Continue to next show
                end else begin
                    next_state = SCHEDULE; // Check next slot
                end
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule