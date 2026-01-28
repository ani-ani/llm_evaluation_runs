module union_sorter(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr1 [0:7],
    input [7:0] arr2 [0:7],
    input [3:0] len1,
    input [3:0] len2,
    output reg [7:0] result [0:15],
    output reg [15:0] valid,
    output reg [4:0] len_out,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMBINE = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] DEDUP = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] idx;              // Generic index counter
    reg [3:0] sort_idx;         // Sorting network stage counter
    reg [3:0] dedup_idx;        // Deduplication index
    reg [4:0] cycle_count;      // Timeout counter
    localparam [4:0] MAX_CYCLES = 5'd50;

    // Working array (16 elements)
    reg [7:0] work [0:15];
    reg [3:0] work_len;
    
    // Temporary variables for sorting network
    reg [7:0] temp1, temp2;
    reg swap;

    integer i;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 5'd0;
            idx <= 4'd0;
            sort_idx <= 4'd0;
            dedup_idx <= 4'd0;
            work_len <= 5'd0;
            len_out <= 5'd0;
            valid <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
                work[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    idx <= 4'd0;
                    sort_idx <= 4'd0;
                    dedup_idx <= 4'd0;
                    if (start) begin
                        state <= COMBINE;
                    end
                end

                COMBINE: begin
                    // Merge arr1 and arr2 into work array
                    if (idx < 4'd8) begin
                        if (idx < len1) begin
                            work[idx] <= arr1[idx];
                        end else begin
                            work[idx] <= 8'd0;
                        end
                        idx <= idx + 4'd1;
                    end else if (idx < 4'd16) begin
                        if ((idx - 4'd8) < len2) begin
                            work[idx] <= arr2[idx - 4'd8];
                        end else begin
                            work[idx] <= 8'd0;
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        work_len <= len1 + len2;
                        idx <= 4'd0;
                        state <= SORT;
                    end
                end

                SORT: begin
                    // Bubble sort network - 16 stages, each stage swaps adjacent pairs
                    // Stage sorts: (0-1), (2-3), (4-5), (6-7), (8-9), (10-11), (12-13), (14-15)
                    // Then (1-2), (3-4), (5-6), (7-8), (9-10), (11-12), (13-14), (15-16)*
                    // (* 16 doesn't exist, so skip)
                    
                    if (sort_idx < 4'd16) begin
                        // Bubble sort comparisons
                        case (sort_idx)
                            4'd0: if (work[0] > work[1]) begin work[0] <= work[1]; work[1] <= work[0]; end
                            4'd1: if (work[2] > work[3]) begin work[2] <= work[3]; work[3] <= work[2]; end
                            4'd2: if (work[4] > work[5]) begin work[4] <= work[5]; work[5] <= work[4]; end
                            4'd3: if (work[6] > work[7]) begin work[6] <= work[7]; work[7] <= work[6]; end
                            4'd4: if (work[8] > work[9]) begin work[8] <= work[9]; work[9] <= work[8]; end
                            4'd5: if (work[10] > work[11]) begin work[10] <= work[11]; work[11] <= work[10]; end
                            4'd6: if (work[12] > work[13]) begin work[12] <= work[13]; work[13] <= work[12]; end
                            4'd7: if (work[14] > work[15]) begin work[14] <= work[15]; work[15] <= work[14]; end
                            4'd8: if (work[1] > work[2]) begin work[1] <= work[2]; work[2] <= work[1]; end
                            4'd9: if (work[3] > work[4]) begin work[3] <= work[4]; work[4] <= work[3]; end
                            4'd10: if (work[5] > work[6]) begin work[5] <= work[6]; work[6] <= work[5]; end
                            4'd11: if (work[7] > work[8]) begin work[7] <= work[8]; work[8] <= work[7]; end
                            4'd12: if (work[9] > work[10]) begin work[9] <= work[10]; work[10] <= work[9]; end
                            4'd13: if (work[11] > work[12]) begin work[11] <= work[12]; work[12] <= work[11]; end
                            4'd14: if (work[13] > work[14]) begin work[13] <= work[14]; work[14] <= work[13]; end
                            4'd15: if (work[15] > work[0]) begin work[15] <= work[0]; work[0] <= work[15]; end
                        endcase
                        sort_idx <= sort_idx + 4'd1;
                    end else begin
                        // Repeat sort 4 times for full bubble sort
                        if (cycle_count < 4'd4) begin
                            sort_idx <= 4'd0;
                            cycle_count <= cycle_count + 5'd1;
                        end else begin
                            sort_idx <= 4'd0;
                            cycle_count <= 5'd0;
                            state <= DEDUP;
                        end
                    end
                end

                DEDUP: begin
                    // Remove duplicates by shifting
                    // We need to count non-duplicate and non-zero elements
                    if (dedup_idx < 4'd15) begin
                        // Check if current element equals next element
                        if (work[dedup_idx] == work[dedup_idx + 1]) begin
                            // Mark as duplicate by setting to max value (then we'll filter)
                            work[dedup_idx] <= 8'd255;
                        end
                        dedup_idx <= dedup_idx + 4'd1;
                    end else begin
                        // Final pass: check last element against max
                        if (work[15] == work[0] && work_len > 5'd0) begin
                            work[15] <= 8'd255;
                        end
                        dedup_idx <= 4'd0;
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    // Copy to output, filter out duplicates and zeros
                    if (idx < 4'd16) begin
                        // Copy non-zero, non-duplicate (255) elements
                        if (work[idx] != 8'd0 && work[idx] != 8'd255) begin
                            result[len_out] <= work[idx];
                            valid[len_out] <= 1'b1;
                            len_out <= len_out + 5'd1;
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        // Fill remaining output with zeros
                        for (i = len_out; i < 16; i = i + 1) begin
                            result[i] <= 8'd0;
                            valid[i] <= 1'b0;
                        end
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
            
            // Timeout protection
            if (state != IDLE) begin
                cycle_count <= cycle_count + 5'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            end
        end
    end

endmodule