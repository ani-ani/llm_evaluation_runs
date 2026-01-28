module critical_elements (
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] seq [0:15],
    output reg [23:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] RESET_COMPUTE = 4'd1;
    localparam [3:0] DP_F_INIT    = 4'd2;
    localparam [3:0] DP_F_LOOP1   = 4'd3;
    localparam [3:0] DP_F_LOOP2   = 4'd4;
    localparam [3:0] DP_F_UPDATE  = 4'd5;
    localparam [3:0] LIS_LEN_CALC = 4'd6;
    localparam [3:0] DP_B_INIT    = 4'd7;
    localparam [3:0] DP_B_LOOP1   = 4'd8;
    localparam [3:0] DP_B_LOOP2   = 4'd9;
    localparam [3:0] DP_B_UPDATE  = 4'd10;
    localparam [3:0] CHECK_CRIT   = 4'd11;
    localparam [3:0] COUNT_CRIT   = 4'd12;
    localparam [3:0] FINISH       = 4'd13;

    reg [3:0] state, next_state;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Storage for DP calculations
    reg [4:0] dp_f [0:15]; // LIS length ending at i (max 16)
    reg [4:0] dp_b [0:15]; // LIS length starting at i (max 16)
    reg [3:0] i_idx, j_idx; // Loop indices
    reg [4:0] lis_len;      // Total LIS length
    reg [15:0] critical_mask;
    reg [3:0] critical_count;
    reg [4:0] temp_max;

    // Helper signals for calculation
    reg [4:0] compare_val;
    reg found_greater;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            cycle_counter <= 8'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            lis_len <= 5'd0;
            critical_mask <= 16'd0;
            critical_count <= 4'd0;
            temp_max <= 5'd0;
            compare_val <= 5'd0;
            found_greater <= 1'b0;
            // Initialize DP arrays
            for (i_idx = 0; i_idx < 16; i_idx = i_idx + 1) begin
                dp_f[i_idx] <= 5'd0;
                dp_b[i_idx] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        state <= RESET_COMPUTE;
                    end else begin
                        state <= IDLE;
                    end
                end

                RESET_COMPUTE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    i_idx <= 4'd0;
                    state <= DP_F_INIT;
                end

                DP_F_INIT: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    // dp_f[i] = 1 for all valid elements
                    if (i_idx < len) begin
                        dp_f[i_idx] <= 5'd1;
                        i_idx <= i_idx + 4'd1;
                        state <= DP_F_INIT;
                    end else begin
                        i_idx <= 4'd1; // Start j loop from 1
                        state <= DP_F_LOOP1;
                    end
                end

                DP_F_LOOP1: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (i_idx < len) begin
                        j_idx <= 4'd0;
                        temp_max <= 5'd0; // Max LIS length ending before i
                        state <= DP_F_LOOP2;
                    end else begin
                        state <= LIS_LEN_CALC;
                    end
                end

                DP_F_LOOP2: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (j_idx < i_idx) begin
                        // Check if seq[j] < seq[i]
                        if (seq[j_idx] < seq[i_idx]) begin
                            // Update max if dp_f[j] is larger
                            if (dp_f[j_idx] > temp_max) begin
                                temp_max <= dp_f[j_idx];
                            end
                        end
                        j_idx <= j_idx + 4'd1;
                        state <= DP_F_LOOP2;
                    end else begin
                        state <= DP_F_UPDATE;
                    end
                end

                DP_F_UPDATE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    dp_f[i_idx] <= temp_max + 5'd1;
                    i_idx <= i_idx + 4'd1;
                    state <= DP_F_LOOP1;
                end

                LIS_LEN_CALC: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    // Find max in dp_f
                    if (i_idx < len) begin
                        if (dp_f[i_idx] > lis_len) begin
                            lis_len <= dp_f[i_idx];
                        end
                        i_idx <= i_idx + 4'd1;
                        state <= LIS_LEN_CALC;
                    end else begin
                        i_idx <= 4'd0;
                        state <= DP_B_INIT;
                    end
                end

                DP_B_INIT: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (i_idx < len) begin
                        dp_b[i_idx] <= 5'd1;
                        i_idx <= i_idx + 4'd1;
                        state <= DP_B_INIT;
                    end else begin
                        i_idx <= len - 4'd1; // Start from second to last
                        state <= DP_B_LOOP1;
                    end
                end

                DP_B_LOOP1: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (i_idx < len && i_idx != 4'd15) begin // Check valid range
                        j_idx <= i_idx + 4'd1;
                        temp_max <= 5'd0;
                        state <= DP_B_LOOP2;
                    end else if (i_idx == 4'd15 || i_idx >= len) begin
                        i_idx <= 4'd0;
                        critical_mask <= 16'd0;
                        state <= CHECK_CRIT;
                    end else begin
                        // Should not happen with valid len
                        i_idx <= 4'd0;
                        critical_mask <= 16'd0;
                        state <= CHECK_CRIT;
                    end
                end

                DP_B_LOOP2: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (j_idx < len) begin
                        // Check if seq[j] > seq[i] (reverse direction)
                        if (seq[j_idx] > seq[i_idx]) begin
                            if (dp_b[j_idx] > temp_max) begin
                                temp_max <= dp_b[j_idx];
                            end
                        end
                        j_idx <= j_idx + 4'd1;
                        state <= DP_B_LOOP2;
                    end else begin
                        state <= DP_B_UPDATE;
                    end
                end

                DP_B_UPDATE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    dp_b[i_idx] <= temp_max + 5'd1;
                    if (i_idx == 4'd0) begin
                        i_idx <= 4'd0;
                        critical_mask <= 16'd0;
                        state <= CHECK_CRIT;
                    end else begin
                        i_idx <= i_idx - 4'd1;
                        state <= DP_B_LOOP1;
                    end
                end

                CHECK_CRIT: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (i_idx < len) begin
                        // Check if element is part of any LIS
                        // Condition: dp_f[i] + dp_b[i] - 1 == lis_len
                        if (dp_f[i_idx] + dp_b[i_idx] - 5'd1 == lis_len) begin
                            // Check if it is the ONLY element with this property
                            // in the specific position in ANY LIS? 
                            // The prompt says: "it's the only element with that property at that position"
                            // But position is fixed by index. 
                            // Actually, the condition is simpler: if it belongs to ALL LISs.
                            // Standard check: If removing it reduces LIS length.
                            // But we are using the count condition.
                            // If element i is in ALL LISs, then it MUST be the unique element
                            // that connects the LIS ending before i and starting after i.
                            // The prompt implies: if dp_f[i] + dp_b[i] - 1 == lis_len, it belongs to SOME LIS.
                            // To be in ALL LISs: 
                            // Usually this requires counting paths. 
                            // With n <= 16, we can be more precise.
                            // Let's assume the simpler condition requested:
                            // "it's the only element with that property at that position in any LIS"
                            // This phrasing is slightly ambiguous. 
                            // Usually, criticality means: the number of LISs passing through i 
                            // equals the total number of LISs.
                            // Given the "simplified algorithm" description:
                            // An element is critical if: 
                            // 1. dp_f[i] + dp_b[i] - 1 == LIS_length (it belongs to some LIS)
                            // 2. AND (implicit) it is unique for that "rank"? 
                            // Actually, standard definition: 
                            // Element is critical if it appears in ALL LISs.
                            // For n <= 16, let's do the count check properly to be accurate.
                            // Count LISs starting at each position.
                            // But to keep cycle count low (< 100), we might need to approximate.
                            // Wait, prompt says: "An element is critical if it appears in all LISs."
                            // Then "Implementation notes: Element i is critical if dp_f[i] + dp_b[i] - 1 == LIS_length AND it's the only element..."
                            // The "only element..." part usually implies checking uniqueness at a specific length index.
                            // However, with n=16, we can do the following check:
                            // If dp_f[i] + dp_b[i] - 1 == lis_len, it belongs to at least one LIS.
                            // To be in ALL LISs, the count of LISs passing through i must equal total LISs.
                            // Since we are limited on cycles, and the prompt gives a specific check:
                            // "Element i is critical if dp_f[i] + dp_b[i] - 1 == LIS_length AND it's the only element with that property at that position in any LIS"
                            // This likely means: Is there another index k where dp_f[k] == dp_f[i] and k also satisfies the condition?
                            // If so, i is not critical because you can swap k for i in some LIS.
                            // So, we need to check if for the calculated dp_f[i], there is any other j such that dp_f[j] == dp_f[i] AND dp_f[j] + dp_b[j] - 1 == lis_len.
                            // If yes, not critical. If no, critical.
                            // We need a temporary check loop.
                            // Let's store the flag in a temp variable.
                            // For now, set a flag assuming it IS critical, then verify.
                            found_greater <= 1'b0;
                            compare_val <= dp_f[i_idx];
                            state <= 4'd14; // Check uniqueness state
                        end else begin
                            // Not in any LIS
                            state <= CHECK_CRIT_LOOP_ADVANCE;
                        end
                    end else begin
                        state <= COUNT_CRIT;
                    end
                end

                // State 14: Check Uniqueness
                4'd14: begin
                    // Scan other indices j != i_idx
                    j_idx <= 4'd0;
                    state <= 4'd15;
                end

                4'd15: begin
                    if (j_idx < len) begin
                        if (j_idx != i_idx) begin
                            if (dp_f[j_idx] == compare_val && (dp_f[j_idx] + dp_b[j_idx] - 5'd1 == lis_len)) begin
                                found_greater <= 1'b1; // Found another element with same dp_f rank
                            end
                        end
                        j_idx <= j_idx + 4'd1;
                        state <= 4'd15;
                    end else begin
                        if (!found_greater) begin
                            // It is critical
                            critical_mask[i_idx] <= 1'b1;
                        end
                        state <= CHECK_CRIT_LOOP_ADVANCE;
                    end
                end

                CHECK_CRIT_LOOP_ADVANCE: begin
                    i_idx <= i_idx + 4'd1;
                    state <= CHECK_CRIT;
                end

                COUNT_CRIT: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    // Count set bits in critical_mask
                    if (i_idx < len) begin
                        if (critical_mask[i_idx]) begin
                            critical_count <= critical_count + 4'd1;
                        end
                        i_idx <= i_idx + 4'd1;
                        state <= COUNT_CRIT;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    result[23:8] <= critical_mask;
                    result[7:0] <= {4'd0, critical_count};
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Helper combinational logic for specific states (optional, but helps sequential flow)
    // Since we are strictly sequential to meet cycle constraints and avoid complexity,
    // the logic above handles the flow.
    // To ensure robustness for the "CHECK_CRIT" condition:
    // We need to handle the loop advances cleanly.

endmodule