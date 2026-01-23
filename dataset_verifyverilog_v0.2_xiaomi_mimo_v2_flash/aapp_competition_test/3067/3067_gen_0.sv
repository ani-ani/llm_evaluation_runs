module patience_merge(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] N_in,
    input wire [2:0] L_seq [0:7],
    input wire [7:0] seq_data [0:7][0:7],
    output reg [7:0] result_value,
    output reg result_valid,
    output reg done
);

    // State encoding
    localparam IDLE = 3'd0;
    localparam FIND_BEST = 3'd1;
    localparam SCAN = 3'd2;
    localparam COMPARE = 3'd3;
    localparam OUTPUT = 3'd4;
    localparam CHECK_DONE = 3'd5;

    // Internal Registers
    reg [2:0] ptr [0:7];
    reg [2:0] state;
    reg [2:0] scan_idx;
    reg [2:0] best_idx;
    reg [2:0] k; // offset for lookahead comparison

    // Temporary values for comparison
    wire [7:0] val_scan;
    wire val_scan_valid;
    wire [7:0] val_best;
    wire val_best_valid;

    // Combinational logic for current comparison values
    assign val_scan_valid = (ptr[scan_idx] + k < L_seq[scan_idx]);
    assign val_scan = val_scan_valid ? seq_data[scan_idx][ptr[scan_idx] + k] : 8'hFF;
    
    assign val_best_valid = (ptr[best_idx] + k < L_seq[best_idx]);
    assign val_best = val_best_valid ? seq_data[best_idx][ptr[best_idx] + k] : 8'hFF;

    // Helper to check if all sequences are done
    wire all_done;
    reg all_done_temp;
    integer i_check;
    always @(*) begin
        all_done_temp = 1'b1;
        for (i_check = 0; i_check < 8; i_check = i_check + 1) begin
            if (i_check < N_in) begin
                if (ptr[i_check] < L_seq[i_check]) all_done_temp = 1'b0;
            end
        end
    end
    assign all_done = all_done_temp;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            done <= 1'b0;
            // Reset pointers explicitly if needed, though IDLE does it
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Reset pointers
                        for (int i = 0; i < 8; i++) begin
                            ptr[i] <= 3'd0;
                        end
                        state <= FIND_BEST;
                    end
                end

                FIND_BEST: begin
                    scan_idx <= 3'd0;
                    best_idx <= 3'd7; // Use 7 as invalid marker since N is max 8 (indices 0-7)
                    state <= SCAN;
                end

                SCAN: begin
                    if (scan_idx >= N_in) begin
                        // End of scan. If we found a best sequence, output it.
                        if (best_idx <= 3'd7 && ptr[best_idx] < L_seq[best_idx]) begin
                            state <= OUTPUT;
                        end else begin
                            // Should not happen if all_done check was correct, but safe fallback
                            state <= CHECK_DONE;
                        end
                    end else if (ptr[scan_idx] >= L_seq[scan_idx]) begin
                        // Current sequence exhausted, skip
                        scan_idx <= scan_idx + 1'b1;
                    end else if (best_idx == 3'd7) begin
                        // Found first valid candidate
                        best_idx <= scan_idx;
                        scan_idx <= scan_idx + 1'b1;
                    end else begin
                        // Need to compare scan_idx vs best_idx
                        k <= 3'd0;
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Compare val_scan vs val_best
                    if (val_scan < val_best) begin
                        // scan_idx is better
                        best_idx <= scan_idx;
                        scan_idx <= scan_idx + 1'b1;
                        state <= SCAN;
                    end else if (val_scan > val_best) begin
                        // best_idx remains best
                        scan_idx <= scan_idx + 1'b1;
                        state <= SCAN;
                    end else begin
                        // Values are equal
                        if (!val_scan_valid && !val_best_valid) begin
                            // Both ended. They are equal. Keep best_idx (arbitrary choice, stable).
                            scan_idx <= scan_idx + 1'b1;
                            state <= SCAN;
                        end else if (!val_scan_valid) begin
                            // Scan ended. Best continues. Scan is prefix. Scan wins.
                            best_idx <= scan_idx;
                            scan_idx <= scan_idx + 1'b1;
                            state <= SCAN;
                        end else if (!val_best_valid) begin
                            // Best ended. Scan continues. Best is prefix. Best wins.
                            scan_idx <= scan_idx + 1'b1;
                            state <= SCAN;
                        end else begin
                            // Both valid and equal. Lookahead.
                            k <= k + 1'b1;
                            if (k == 3'd7) begin // Safety limit (max seq length)
                                // Equal up to limit, assume equal, keep best
                                scan_idx <= scan_idx + 1'b1;
                                state <= SCAN;
                            end
                        end
                    end
                end

                OUTPUT: begin
                    result_value <= seq_data[best_idx][ptr[best_idx]];
                    result_valid <= 1'b1;
                    ptr[best_idx] <= ptr[best_idx] + 1'b1;
                    state <= CHECK_DONE;
                end

                CHECK_DONE: begin
                    result_valid <= 1'b0;
                    if (all_done) begin
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        state <= FIND_BEST;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule