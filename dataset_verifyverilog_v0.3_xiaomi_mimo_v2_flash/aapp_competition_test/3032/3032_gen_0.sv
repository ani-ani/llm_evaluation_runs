module program_optimizer #(
    parameter MAX_VARS = 4,
    parameter MAX_BANKS = 4,
    parameter MAX_SEQ_LEN = 64,
    parameter VAR_IDX_WIDTH = 3,
    parameter BANK_IDX_WIDTH = 3,
    parameter COST_WIDTH = 32
)(
    input clk,
    input rst_n,
    input start,
    input [3:0] b,
    input [3:0] s,
    input [VAR_IDX_WIDTH-1:0] var_idx,
    input seq_pos_valid,
    input seq_done,
    output reg [COST_WIDTH-1:0] min_cost,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INPUT_SEQ = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] OUTPUT = 2'd3;

    reg [1:0] state;
    reg [5:0] seq_len;
    reg [VAR_IDX_WIDTH-1:0] seq_buffer [0:MAX_SEQ_LEN-1];
    reg [5:0] input_ptr;
    reg [3:0] assignment [0:MAX_VARS-1];
    reg [3:0] current_var;
    reg [5:0] seq_ptr;
    reg [COST_WIDTH-1:0] current_cost;
    reg [COST_WIDTH-1:0] best_cost;
    reg [3:0] bsr_state;
    reg bs_valid;
    reg [3:0] var_count;
    reg [3:0] bank_usage [0:MAX_BANKS-1];
    reg [3:0] assignment_iter;
    reg [3:0] assignment_idx;
    reg compute_done;
    reg [3:0] temp_var;
    reg [3:0] temp_bank;
    reg [3:0] temp_bsr;
    reg [3:0] bsr;
    reg [3:0] prev_var;
    reg valid_seq;
    reg [3:0] bank_idx;
    reg [COST_WIDTH-1:0] cost_acc;
    reg [3:0] var_idx_local;
    reg [3:0] bank_idx_local;
    reg [3:0] next_bsr;
    reg [3:0] next_prev_var;
    reg [3:0] next_bsr_update;
    reg cost_valid;
    reg assignment_valid;
    reg all_assignments_done;
    reg [3:0] next_assignment_idx;
    reg [3:0] next_assignment_iter;
    reg increment_flag;

    integer i, j;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            seq_len <= 0;
            input_ptr <= 0;
            min_cost <= 0;
            done <= 0;
            bsr_state <= 15;
            bs_valid <= 0;
            compute_done <= 0;
            var_count <= 0;
            assignment_iter <= 0;
            assignment_idx <= 0;
            best_cost <= 32'hFFFF_FFFF;
            current_cost <= 0;
            seq_ptr <= 0;
            current_var <= 0;
            bsr <= 15;
            prev_var <= 15;
            bank_usage[0] <= 0;
            bank_usage[1] <= 0;
            bank_usage[2] <= 0;
            bank_usage[3] <= 0;
            assignment[0] <= 15;
            assignment[1] <= 15;
            assignment[2] <= 15;
            assignment[3] <= 15;
            seq_buffer[0] <= 0;
            seq_buffer[1] <= 0;
            seq_buffer[2] <= 0;
            seq_buffer[3] <= 0;
            seq_buffer[4] <= 0;
            seq_buffer[5] <= 0;
            seq_buffer[6] <= 0;
            seq_buffer[7] <= 0;
            seq_buffer[8] <= 0;
            seq_buffer[9] <= 0;
            seq_buffer[10] <= 0;
            seq_buffer[11] <= 0;
            seq_buffer[12] <= 0;
            seq_buffer[13] <= 0;
            seq_buffer[14] <= 0;
            seq_buffer[15] <= 0;
            seq_buffer[16] <= 0;
            seq_buffer[17] <= 0;
            seq_buffer[18] <= 0;
            seq_buffer[19] <= 0;
            seq_buffer[20] <= 0;
            seq_buffer[21] <= 0;
            seq_buffer[22] <= 0;
            seq_buffer[23] <= 0;
            seq_buffer[24] <= 0;
            seq_buffer[25] <= 0;
            seq_buffer[26] <= 0;
            seq_buffer[27] <= 0;
            seq_buffer[28] <= 0;
            seq_buffer[29] <= 0;
            seq_buffer[30] <= 0;
            seq_buffer[31] <= 0;
            seq_buffer[32] <= 0;
            seq_buffer[33] <= 0;
            seq_buffer[34] <= 0;
            seq_buffer[35] <= 0;
            seq_buffer[36] <= 0;
            seq_buffer[37] <= 0;
            seq_buffer[38] <= 0;
            seq_buffer[39] <= 0;
            seq_buffer[40] <= 0;
            seq_buffer[41] <= 0;
            seq_buffer[42] <= 0;
            seq_buffer[43] <= 0;
            seq_buffer[44] <= 0;
            seq_buffer[45] <= 0;
            seq_buffer[46] <= 0;
            seq_buffer[47] <= 0;
            seq_buffer[48] <= 0;
            seq_buffer[49] <= 0;
            seq_buffer[50] <= 0;
            seq_buffer[51] <= 0;
            seq_buffer[52] <= 0;
            seq_buffer[53] <= 0;
            seq_buffer[54] <= 0;
            seq_buffer[55] <= 0;
            seq_buffer[56] <= 0;
            seq_buffer[57] <= 0;
            seq_buffer[58] <= 0;
            seq_buffer[59] <= 0;
            seq_buffer[60] <= 0;
            seq_buffer[61] <= 0;
            seq_buffer[62] <= 0;
            seq_buffer[63] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    compute_done <= 1'b0;
                    if (start) begin
                        state <= INPUT_SEQ;
                        input_ptr <= 6'd0;
                        seq_len <= 6'd0;
                        var_count <= 4'd0;
                        for (i = 0; i < MAX_VARS; i = i + 1) begin
                            assignment[i] <= 4'd15;
                        end
                        for (i = 0; i < MAX_BANKS; i = i + 1) begin
                            bank_usage[i] <= 4'd0;
                        end
                    end
                end

                INPUT_SEQ: begin
                    if (seq_pos_valid && input_ptr < MAX_SEQ_LEN) begin
                        seq_buffer[input_ptr] <= var_idx;
                        if (var_idx > 0 && var_idx <= MAX_VARS) begin
                            if (assignment[var_idx-1] == 4'd15) begin
                                assignment[var_idx-1] <= 4'd0;
                                var_count <= var_count + 4'd1;
                            end
                        end
                        input_ptr <= input_ptr + 6'd1;
                        seq_len <= seq_len + 6'd1;
                    end
                    if (seq_done) begin
                        state <= COMPUTE;
                        assignment_iter <= 4'd0;
                        assignment_idx <= 4'd0;
                        best_cost <= 32'hFFFF_FFFF;
                        compute_done <= 1'b0;
                        seq_ptr <= 6'd0;
                        bsr <= 15;
                        prev_var <= 15;
                        current_cost <= 32'd0;
                    end
                end

                COMPUTE: begin
                    if (!compute_done) begin
                        // Generate next assignment
                        if (assignment_iter < var_count) begin
                            // Try next bank for current variable
                            if (assignment[assignment_iter] < b) begin
                                assignment[assignment_iter] <= assignment[assignment_iter] + 4'd1;
                                // Reset subsequent variables
                                for (i = assignment_iter + 1; i < MAX_VARS; i = i + 1) begin
                                    if (i < var_count) assignment[i] <= 4'd0;
                                end
                                // Start sequence scan
                                seq_ptr <= 6'd0;
                                bsr <= 15;
                                prev_var <= 15;
                                current_cost <= 32'd0;
                            end else begin
                                assignment[assignment_iter] <= 4'd0;
                                assignment_iter <= assignment_iter + 4'd1;
                            end
                        end else begin
                            compute_done <= 1'b1;
                        end

                        // Compute cost for current assignment
                        if (seq_ptr < seq_len) begin
                            var_idx_local <= seq_buffer[seq_ptr];
                            if (var_idx_local > 0 && var_idx_local <= MAX_VARS) begin
                                bank_idx_local <= assignment[var_idx_local-1];
                                next_bsr <= bsr;
                                next_prev_var <= prev_var;
                                if (prev_var == 4'd15) begin
                                    next_bsr <= bank_idx_local;
                                    next_prev_var <= var_idx_local;
                                end else if (prev_var != var_idx_local) begin
                                    next_bsr <= bank_idx_local;
                                    next_prev_var <= var_idx_local;
                                end
                                if (bsr != 4'd15 && bsr != bank_idx_local) begin
                                    current_cost <= current_cost + 32'd1;
                                end
                            end
                            seq_ptr <= seq_ptr + 6'd1;
                            bsr <= next_bsr;
                            prev_var <= next_prev_var;
                        end

                        if (seq_ptr == seq_len && seq_len > 0) begin
                            if (current_cost < best_cost) begin
                                best_cost <= current_cost;
                            end
                        end
                    end else begin
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    min_cost <= best_cost;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule