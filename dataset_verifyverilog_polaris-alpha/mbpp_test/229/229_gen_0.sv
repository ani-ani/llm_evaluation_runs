module rearrange_neg_pos (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              start,
    input  logic      [3:0]   n,
    input  logic signed [15:0][7:0] arr_in,
    output logic signed [15:0][7:0] arr_out,
    output logic              done
);

    // Internal registers
    typedef logic signed [7:0] elem_t;

    elem_t temp      [15:0];
    elem_t neg_buf   [15:0];
    elem_t pos_buf   [15:0];

    logic [3:0] idx;         // 0..15 index for cycles
    logic [4:0] neg_count;   // up to 16
    logic [4:0] pos_count;   // up to 16

    // Phase encoding
    typedef enum logic [1:0] {
        PH_IDLE   = 2'b00,
        PH_SCAN   = 2'b01,
        PH_MERGE  = 2'b10,
        PH_COPY   = 2'b11
    } phase_e;

    phase_e phase;

    // Latched inputs
    logic [3:0]   n_reg;
    elem_t        arr_latched [15:0];

    // Sequential control and data path
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase      <= PH_IDLE;
            idx        <= 4'd0;
            neg_count  <= 5'd0;
            pos_count  <= 5'd0;
            n_reg      <= 4'd0;
            done       <= 1'b0;
            arr_out    <= '{default:8'sd0};
        end else begin
            done <= 1'b0;

            case (phase)

                PH_IDLE: begin
                    if (start) begin
                        // Latch input array and n at start
                        n_reg <= (n == 4'd0) ? 4'd0 : n; // though spec says 1-16
                        for (int i = 0; i < 16; i++) begin
                            arr_latched[i] <= arr_in[i];
                        end

                        idx       <= 4'd0;
                        neg_count <= 5'd0;
                        pos_count <= 5'd0;
                        phase     <= PH_SCAN;
                    end
                end

                // Cycles 0-7: scan first n_reg elements, fill neg_buf/pos_buf
                PH_SCAN: begin
                    if (idx < 4'd8) begin
                        if (idx < n_reg) begin
                            if (arr_latched[idx][7] == 1'b1) begin
                                neg_buf[neg_count] <= arr_latched[idx];
                                neg_count          <= neg_count + 5'd1;
                            end else begin
                                pos_buf[pos_count] <= arr_latched[idx];
                                pos_count          <= pos_count + 5'd1;
                            end
                        end
                        idx <= idx + 4'd1;
                    end
                    if (idx == 4'd7) begin
                        // Next cycle moves to MERGE
                        phase <= PH_MERGE;
                        idx   <= 4'd0;
                    end
                end

                // Cycles 8-11: build temp[0..n_reg-1] = negatives then positives
                PH_MERGE: begin
                    if (idx < 4'd4) begin
                        // Compute base indices for this cycle (4-wide block)
                        int base = idx << 2; // idx*4
                        for (int k = 0; k < 4; k++) begin
                            int t_idx = base + k;
                            if (t_idx < n_reg) begin
                                if (t_idx < neg_count)
                                    temp[t_idx] <= neg_buf[t_idx];
                                else
                                    temp[t_idx] <= pos_buf[t_idx - neg_count];
                            end
                        end
                        idx <= idx + 4'd1;
                    end
                    if (idx == 4'd3) begin
                        // Next cycle moves to COPY
                        phase <= PH_COPY;
                        idx   <= 4'd0;
                    end
                end

                // Cycles 12-15: form arr_out from temp and original
                PH_COPY: begin
                    if (idx < 4'd4) begin
                        int base = idx << 2; // idx*4
                        for (int k = 0; k < 4; k++) begin
                            int t_idx = base + k;
                            if (t_idx < 16) begin
                                if (t_idx < n_reg)
                                    arr_out[t_idx] <= temp[t_idx];
                                else
                                    arr_out[t_idx] <= arr_latched[t_idx];
                            end
                        end
                        idx <= idx + 4'd1;
                    end
                    if (idx == 4'd3) begin
                        // Completed exactly 16 cycles from start
                        done  <= 1'b1;
                        phase <= PH_IDLE;
                    end
                end

                default: begin
                    phase <= PH_IDLE;
                end

            endcase
        end
    end

endmodule