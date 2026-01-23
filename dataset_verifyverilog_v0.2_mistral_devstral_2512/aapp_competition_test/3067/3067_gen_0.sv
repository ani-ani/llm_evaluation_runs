module patience_merge (
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

    // States
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] FIND_BEST = 3'b001;
    localparam [2:0] SCAN = 3'b010;
    localparam [2:0] COMPARE = 3'b011;
    localparam [2:0] OUTPUT = 3'b100;
    localparam [2:0] CHECK_DONE = 3'b101;

    // Internal registers
    reg [2:0] ptr [0:7];
    reg [2:0] state;
    reg [2:0] scan_idx;
    reg [2:0] best_idx;
    reg [2:0] k;
    reg [7:0] val_scan_val;
    reg [7:0] val_best_val;
    reg val_scan_valid;
    reg val_best_valid;

    // Reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_valid <= 1'b0;
            for (int i = 0; i < 8; i = i + 1) begin
                ptr[i] <= 3'b000;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= FIND_BEST;
                        done <= 1'b0;
                    end
                end
                FIND_BEST: begin
                    scan_idx <= 3'b000;
                    best_idx <= 3'b100; // Invalid index
                    state <= SCAN;
                end
                SCAN: begin
                    if (scan_idx == N_in) begin
                        if (best_idx != 3'b100) begin
                            state <= OUTPUT;
                        end else begin
                            state <= CHECK_DONE;
                        end
                    end else if (ptr[scan_idx] == L_seq[scan_idx]) begin
                        scan_idx <= scan_idx + 1'b1;
                    end else if (best_idx == 3'b100) begin
                        best_idx <= scan_idx;
                        scan_idx <= scan_idx + 1'b1;
                    end else begin
                        k <= 3'b000;
                        state <= COMPARE;
                    end
                end
                COMPARE: begin
                    val_scan_valid = (ptr[scan_idx] + k < L_seq[scan_idx]);
                    val_best_valid = (ptr[best_idx] + k < L_seq[best_idx]);
                    val_scan_val = val_scan_valid ? seq_data[scan_idx][ptr[scan_idx] + k] : 8'hFF;
                    val_best_val = val_best_valid ? seq_data[best_idx][ptr[best_idx] + k] : 8'hFF;

                    if (val_scan_val < val_best_val) begin
                        best_idx <= scan_idx;
                        scan_idx <= scan_idx + 1'b1;
                        state <= SCAN;
                    end else if (val_scan_val > val_best_val) begin
                        scan_idx <= scan_idx + 1'b1;
                        state <= SCAN;
                    end else begin
                        if (!val_scan_valid && !val_best_valid) begin
                            scan_idx <= scan_idx + 1'b1;
                            state <= SCAN;
                        end else if (!val_scan_valid) begin
                            best_idx <= scan_idx;
                            scan_idx <= scan_idx + 1'b1;
                            state <= SCAN;
                        end else if (!val_best_valid) begin
                            scan_idx <= scan_idx + 1'b1;
                            state <= SCAN;
                        end else if (k == 3'b111) begin
                            scan_idx <= scan_idx + 1'b1;
                            state <= SCAN;
                        end else begin
                            k <= k + 1'b1;
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
                    reg done_flag;
                    done_flag = 1'b1;
                    for (int i = 0; i < 8; i = i + 1) begin
                        if (i < N_in && ptr[i] < L_seq[i]) begin
                            done_flag = 1'b0;
                        end
                    end
                    if (done_flag) begin
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