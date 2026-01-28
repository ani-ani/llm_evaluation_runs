module findDeletePattern (
    input clk,
    input rst_n,
    input start,
    input [7:0] files [0:7][0:15],
    input [3:0] delete_idx [0:3],
    input [2:0] num_files,
    input [1:0] num_delete,
    input [3:0] lengths [0:7],
    output reg [7:0] result [0:15],
    output reg [3:0] result_len,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] CHECK_LEN     = 3'd1;
    localparam [2:0] BUILD_PATTERN = 3'd2;
    localparam [2:0] CHECK_OTHERS  = 3'd3;
    localparam [2:0] DONE          = 3'd4;
    localparam [2:0] FAIL          = 3'd5;

    // Registers and counters
    reg [2:0] state, next_state;
    reg [3:0] len_reg;
    reg [2:0] i, j, k;  // Loop counters
    reg [7:0] first_char;
    reg [7:0] current_char;
    reg mismatch_found;
    reg match_possible;
    reg [7:0] pattern_temp [0:15];
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd12;  // Conservative limit

    integer file_idx, pos_idx, del_idx;
    reg [3:0] current_len;
    reg [7:0] pattern_char;
    reg file_matches;
    reg is_delete_file;
    reg [7:0] char_at_pos;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result_len <= 4'd0;
            len_reg <= 4'd0;
            cycle_count <= 4'd0;
            mismatch_found <= 1'b0;
            match_possible <= 1'b0;
            first_char <= 8'd0;
            current_char <= 8'd0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            // Initialize result array
            for (pos_idx = 0; pos_idx < 16; pos_idx = pos_idx + 1) begin
                result[pos_idx] <= 8'd0;
                pattern_temp[pos_idx] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= CHECK_LEN;
                        i <= 3'd0;
                        mismatch_found <= 1'b0;
                        len_reg <= 4'd0;
                    end
                end

                CHECK_LEN: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (i < num_delete && !mismatch_found) begin
                        // Get index, subtract 1 for 0-based
                        del_idx = delete_idx[i] - 4'd1;
                        if (i == 3'd0) begin
                            len_reg <= lengths[del_idx];
                        end else begin
                            if (lengths[del_idx] != len_reg) begin
                                mismatch_found <= 1'b1;
                            end
                        end
                        i <= i + 3'd1;
                    end else begin
                        if (mismatch_found || len_reg == 4'd0 || len_reg > 4'd16) begin
                            state <= FAIL;
                        end else begin
                            state <= BUILD_PATTERN;
                            i <= 3'd0;
                            j <= 4'd0;
                            mismatch_found <= 1'b0;
                        end
                    end
                end

                BUILD_PATTERN: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (j < len_reg && !mismatch_found) begin
                        // Check if all delete files have same char at position j
                        if (i < num_delete) begin
                            del_idx = delete_idx[i] - 4'd1;
                            current_char = files[del_idx][j];
                            if (i == 3'd0) begin
                                first_char <= current_char;
                                pattern_temp[j] <= current_char;
                            end else begin
                                if (current_char != first_char) begin
                                    mismatch_found <= 1'b1;
                                    pattern_temp[j] <= 8'd63;  // '?'
                                end
                            end
                            i <= i + 3'd1;
                        end else begin
                            // Next position
                            i <= 3'd0;
                            j <= j + 4'd1;
                            mismatch_found <= 1'b0;
                        end
                    end else if (j >= len_reg) begin
                        state <= CHECK_OTHERS;
                        i <= 3'd0;
                        j <= 4'd0;
                        match_possible <= 1'b1;
                    end else begin
                        state <= FAIL;
                    end
                end

                CHECK_OTHERS: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (i < num_files && match_possible) begin
                        // Check if file i is a delete file
                        is_delete_file = 1'b0;
                        for (k = 0; k < num_delete && !is_delete_file; k = k + 1) begin
                            if (delete_idx[k] == i) begin
                                is_delete_file = 1'b1;
                            end
                        end
                        
                        if (!is_delete_file) begin
                            if (lengths[i] == len_reg) begin
                                // Check if this file matches pattern
                                file_matches = 1'b1;
                                for (pos_idx = 0; pos_idx < len_reg && file_matches; pos_idx = pos_idx + 1) begin
                                    char_at_pos = files[i][pos_idx];
                                    pattern_char = pattern_temp[pos_idx];
                                    if (pattern_char != 8'd63 && char_at_pos != pattern_char) begin
                                        file_matches = 1'b0;
                                    end
                                end
                                if (file_matches) begin
                                    match_possible <= 1'b0;
                                end
                            end
                        end
                        i <= i + 3'd1;
                    end else begin
                        if (match_possible) begin
                            state <= DONE;
                        end else begin
                            state <= FAIL;
                        end
                    end
                end

                DONE: begin
                    for (pos_idx = 0; pos_idx < 16; pos_idx = pos_idx + 1) begin
                        if (pos_idx < len_reg) begin
                            result[pos_idx] <= pattern_temp[pos_idx];
                        end else begin
                            result[pos_idx] <= 8'd0;
                        end
                    end
                    result_len <= len_reg;
                    valid <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                FAIL: begin
                    for (pos_idx = 0; pos_idx < 16; pos_idx = pos_idx + 1) begin
                        result[pos_idx] <= 8'd0;
                    end
                    result_len <= 4'd0;
                    valid <= 1'b0;
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