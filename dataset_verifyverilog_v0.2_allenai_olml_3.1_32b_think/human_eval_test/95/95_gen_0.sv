module check_dict_case (
    input clk,
    input rst_n,
    input start,
    input [7:0] valid_entries,
    input [63:0] key_0, key_1, key_2, key_3, key_4, key_5, key_6, key_7,
    output reg result,
    output reg done
);

// State definitions
localparam IDLE = 3'd0, CHECK_EMPTY = 3'd1, PROCESS_KEYS = 3'd2, VALIDATE_CASE = 3'd3, DONE = 3'd4;

// Registers
reg [2:0] state;
reg [6:0] char_count;
reg [7:0] entry_has_invalid;
reg [7:0] entry_first_case;
reg [7:0] entry_case_mismatch;
reg [3:0] entry_char_count [7:0];
reg [1:0] target_case;
reg overall_invalid;
reg any_valid_key;
reg [7:0] char_val;

// Reset logic
always @(negedge rst_n or posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        char_count <= 0;
        entry_has_invalid <= 0;
        entry_first_case <= 0;
        entry_case_mismatch <= 0;
        entry_char_count <= 0;
        target_case <= 0;
        overall_invalid <= 0;
        any_valid_key <= 0;
        result <= 0;
        done <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= CHECK_EMPTY;
                end else begin
                    state <= IDLE;
                end
                result <= 0;
                done <= 0;
            end
            CHECK_EMPTY: begin
                if (valid_entries == 0) begin
                    state <= DONE;
                    result <= 0;
                    done <= 1;
                end else begin
                    state <= PROCESS_KEYS;
                    char_count <= 0;
                    entry_has_invalid <= 0;
                    entry_first_case <= 0;
                    entry_case_mismatch <= 0;
                    entry_char_count <= 0;
                    target_case <= 0;
                    overall_invalid <= 0;
                    any_valid_key <= 0;
                end
                result <= 0;
                done <= 0;
            end
            PROCESS_KEYS: begin
                result <= 0;
                done <= 0;
                if (char_count < 64) begin
                    int entry = char_count / 8;
                    int char_pos = char_count % 8;
                    if (valid_entries[entry]) begin
                        reg [63:0] key_val;
                        case (entry)
                            0: key_val = key_0;
                            1: key_val = key_1;
                            2: key_val = key_2;
                            3: key_val = key_3;
                            4: key_val = key_4;
                            5: key_val = key_5;
                            6: key_val = key_6;
                            7: key_val = key_7;
                        endcase
                        char_val = key_val[char_pos*8 + 7 : char_pos*8];
                        if (char_val < 65 || (char_val > 90 && char_val < 97) || char_val > 122) begin
                            entry_has_invalid[entry] = 1;
                        end else begin
                            if (char_val <= 90) begin
                                char_case = 2;
                            end else begin
                                char_case = 1;
                            end
                            if (entry_first_case[entry] == 0) begin
                                entry_first_case[entry] = char_case;
                            end else if (entry_first_case[entry] != char_case) begin
                                entry_case_mismatch[entry] = 1;
                            end
                        end
                        entry_char_count[entry] = entry_char_count[entry] + 1;
                    end
                    char_count <= char_count + 1;
                    state <= PROCESS_KEYS;
                end else begin
                    state <= VALIDATE_CASE;
                    char_count <= 64;
                end
            end
            VALIDATE_CASE: begin
                result <= 0;
                done <= 0;
                overall_invalid = 0;
                any_valid_key = 0;
                target_case = 0;

                if (valid_entries[0] && (entry_has_invalid[0] || entry_case_mismatch[0])) overall_invalid = 1;
                if (valid_entries[1] && (entry_has_invalid[1] || entry_case_mismatch[1])) overall_invalid = 1;
                if (valid_entries[2] && (entry_has_invalid[2] || entry_case_mismatch[2])) overall_invalid = 1;
                if (valid_entries[3] && (entry_has_invalid[3] || entry_case_mismatch[3])) overall_invalid = 1;
                if (valid_entries[4] && (entry_has_invalid[4] || entry_case_mismatch[4])) overall_invalid = 1;
                if (valid_entries[5] && (entry_has_invalid[5] || entry_case_mismatch[5])) overall_invalid = 1;
                if (valid_entries[6] && (entry_has_invalid[6] || entry_case_mismatch[6])) overall_invalid = 1;
                if (valid_entries[7] && (entry_has_invalid[7] || entry_case_mismatch[7])) overall_invalid = 1;

                any_valid_key = 0;
                if (valid_entries[0] && !entry_has_invalid[0] && !entry_case_mismatch[0]) begin
                    any_valid_key = 1;
                    if (target_case == 0) target_case = entry_first_case[0];
                end
                if (valid_entries[1] && !entry_has_invalid[1] && !entry_case_mismatch[1]) begin
                    any_valid_key = 1;
                    if (target_case == 0) target_case = entry_first_case[1];
                end
                if (valid_entries[2] && !entry_has_invalid[2] && !entry_case_mismatch[2]) begin
                    any_valid_key = 1;
                    if (target_case == 0) target_case = entry_first_case[2];
                end
                if (valid_entries[3] && !entry_has_invalid[3] && !entry_case_mismatch[3]) begin
                    any_valid_key = 1;
                    if (target_case == 0) target_case = entry_first_case[3];
                end
                if (valid_entries[4] && !entry_has_invalid[4] && !entry_case_mismatch[4]) begin
                    any_valid_key = 1;
                    if (target_case == 0) target_case = entry_first_case[4];
                end
                if (valid_entries[5] && !entry_has_invalid[5] && !entry_case_mismatch[5]) begin
                    any_valid_key = 1;
                    if (target_case == 0) target_case = entry_first_case[5];
                end
                if (valid_entries[6] && !entry_has_invalid[6] && !entry_case_mismatch[6]) begin
                    any_valid_key = 1;
                    if (target_case == 0) target_case = entry_first_case[6];
                end
                if (valid_entries[7] && !entry_has_invalid[7] && !entry_case_mismatch[7]) begin
                    any_valid_key = 1;
                    if (target_case == 0) target_case = entry_first_case[7];
                end

                if (any_valid_key) begin
                    if (valid_entries[0] && !entry_has_invalid[0] && !entry_case_mismatch[0] && entry_first_case[0] != target_case) begin
                        overall_invalid = 1;
                    end
                    if (valid_entries[1] && !entry_has_invalid[1] && !entry_case_mismatch[1] && entry_first_case[1] != target_case) begin
                        overall_invalid = 1;
                    end
                    if (valid_entries[2] && !entry_has_invalid[2] && !entry_case_mismatch[2] && entry_first_case[2] != target_case) begin
                        overall_invalid = 1;
                    end
                    if (valid_entries[3] && !entry_has_invalid[3] && !entry_case_mismatch[3] && entry_first_case[3] != target_case) begin
                        overall_invalid = 1;
                    end
                    if (valid_entries[4] && !entry_has_invalid[4] && !entry_case_mismatch[4] && entry_first_case[4] != target_case) begin
                        overall_invalid = 1;
                    end
                    if (valid_entries[5] && !entry_has_invalid[5] && !entry_case_mismatch[5] && entry_first_case[5] != target_case) begin
                        overall_invalid = 1;
                    end
                    if (valid_entries[6] && !entry_has_invalid[6] && !entry_case_mismatch[6] && entry_first_case[6] != target_case) begin
                        overall_invalid = 1;
                    end
                    if (valid_entries[7] && !entry_has_invalid[7] && !entry_case_mismatch[7] && entry_first_case[7] != target_case) begin
                        overall_invalid = 1;
                    end
                end

                if (!overall_invalid) begin
                    result = 1;
                end else begin
                    result = 0;
                end
                done = 1;
                state = DONE;
            end
            DONE: begin
                result <= result;
                done <= 1;
                state <= DONE;
            end
        endcase
    end
endmodule