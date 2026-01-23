module round_generator (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Data loading interface
    input wire [15:0] data_val,
    input wire [1:0] data_type,
    input wire data_valid,
    
    output reg [199:0] line1_out,
    output reg [199:0] line2_out,
    output reg output_valid,
    output reg done
);

    // Parameters
    parameter MAX_LINES = 8;
    parameter MAX_SYLLABLES = 8;
    parameter MAX_CHARS = 16;
    parameter LINE_WIDTH = 200;

    // Internal Memory
    reg [7:0] syllable_text [0:MAX_LINES-1][0:MAX_SYLLABLES-1][0:MAX_CHARS-1];
    reg [7:0] syllable_time [0:MAX_LINES-1][0:MAX_SYLLABLES-1];
    reg [3:0] syllable_count [0:MAX_LINES-1];
    reg [7:0] line_delay;
    reg [3:0] num_lines;

    // Pointers
    reg [3:0] cur_line_idx;
    reg [3:0] cur_syl_idx;
    reg [3:0] cur_char_idx;
    reg [7:0] cur_abs_time;

    // State
    reg [2:0] state;
    localparam S_IDLE = 0;
    localparam S_LOAD = 1;
    localparam S_PROC_V1 = 2;
    localparam S_PROC_V2 = 3;
    localparam S_OUTPUT = 4;
    localparam S_NEXT_LINE = 5;
    localparam S_DONE = 6;

    // Processing registers
    reg [3:0] proc_syl_idx;
    reg [3:0] proc_char_idx;
    reg [7:0] v1_cursor;
    reg [7:0] v2_start_time;
    reg [7:0] total_line_dur;
    reg [199:0] temp_line1;
    reg [199:0] temp_line2;
    reg v2_has_data;

    // Line processing
    reg [3:0] line_proc_idx;
    reg [3:0] syl_proc_idx;
    reg [3:0] char_proc_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            output_valid <= 0;
            done <= 0;
            num_lines <= 0;
            cur_line_idx <= 0;
            cur_syl_idx <= 0;
            cur_char_idx <= 0;
            cur_abs_time <= 0;
            proc_syl_idx <= 0;
            proc_char_idx <= 0;
            v1_cursor <= 0;
            v2_start_time <= 0;
            total_line_dur <= 0;
            temp_line1 <= {200{8'h5F}};
            temp_line2 <= {200{8'h5F}};
            v2_has_data <= 0;
            line_proc_idx <= 0;
            syl_proc_idx <= 0;
            char_proc_idx <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    output_valid <= 0;
                    done <= 0;
                    if (start) begin
                        state <= S_LOAD;
                        cur_line_idx <= 0;
                        cur_syl_idx <= 0;
                        cur_char_idx <= 0;
                        num_lines <= 0;
                        line_delay <= 0;
                    end
                end

                S_LOAD: begin
                    if (data_valid) begin
                        if (num_lines == 0 && cur_line_idx == 0 && cur_syl_idx == 0 && cur_char_idx == 0) begin
                            // First data is config (L and D)
                            num_lines <= data_val[15:8];
                            line_delay <= data_val[7:0];
                        end else begin
                            case (data_type)
                                0: begin // Time
                                    syllable_time[cur_line_idx][cur_syl_idx] <= data_val[7:0];
                                end
                                1: begin // Char
                                    if (cur_char_idx < MAX_CHARS) begin
                                        syllable_text[cur_line_idx][cur_syl_idx][cur_char_idx] <= data_val[7:0];
                                        cur_char_idx <= cur_char_idx + 1;
                                    end
                                end
                                2: begin // EndSyl
                                    syllable_count[cur_line_idx] <= cur_syl_idx + 1;
                                    cur_syl_idx <= cur_syl_idx + 1;
                                    cur_char_idx <= 0;
                                end
                                3: begin // EndLine
                                    cur_line_idx <= cur_line_idx + 1;
                                    cur_syl_idx <= 0;
                                    cur_char_idx <= 0;
                                    if (cur_line_idx >= num_lines) begin
                                        state <= S_PROC_V1;
                                        cur_line_idx <= 0;
                                        proc_syl_idx <= 0;
                                        v1_cursor <= 0;
                                        total_line_dur <= 0;
                                        temp_line1 <= {200{8'h5F}};
                                    end
                                end
                            endcase
                        end
                    end
                end

                S_PROC_V1: begin
                    if (proc_syl_idx < syllable_count[cur_line_idx]) begin
                        // Process syllable
                        if (proc_char_idx < MAX_CHARS && syllable_text[cur_line_idx][proc_syl_idx][proc_char_idx] != 0) begin
                            // Write character
                            temp_line1[(v1_cursor + proc_char_idx) * 8 +: 8] <= syllable_text[cur_line_idx][proc_syl_idx][proc_char_idx];
                            proc_char_idx <= proc_char_idx + 1;
                        end else begin
                            // Fill with underscores to duration
                            if (proc_char_idx < syllable_time[cur_line_idx][proc_syl_idx]) begin
                                temp_line1[(v1_cursor + proc_char_idx) * 8 +: 8] <= 8'h5F;
                                proc_char_idx <= proc_char_idx + 1;
                            end else begin
                                // Move to next syllable
                                v1_cursor <= v1_cursor + syllable_time[cur_line_idx][proc_syl_idx];
                                total_line_dur <= total_line_dur + syllable_time[cur_line_idx][proc_syl_idx];
                                proc_syl_idx <= proc_syl_idx + 1;
                                proc_char_idx <= 0;
                            end
                        end
                    end else begin
                        // Done with V1, move to V2
                        state <= S_PROC_V2;
                        line_proc_idx <= 0;
                        syl_proc_idx <= 0;
                        char_proc_idx <= 0;
                        v2_start_time <= cur_abs_time + line_delay;
                        v2_has_data <= 0;
                        temp_line2 <= {200{8'h5F}};
                    end
                end

                S_PROC_V2: begin
                    if (line_proc_idx < num_lines) begin
                        if (syl_proc_idx < syllable_count[line_proc_idx]) begin
                            // Calculate absolute start time of syllable
                            reg [7:0] abs_start_time = 0;
                            integer k;
                            for (k = 0; k < syl_proc_idx; k = k + 1) begin
                                abs_start_time = abs_start_time + syllable_time[line_proc_idx][k];
                            end
                            // Check if in window
                            if (abs_start_time >= v2_start_time && abs_start_time < v2_start_time + total_line_dur) begin
                                reg [7:0] rel_pos = abs_start_time - v2_start_time;
                                if (char_proc_idx < MAX_CHARS && syllable_text[line_proc_idx][syl_proc_idx][char_proc_idx] != 0) begin
                                    temp_line2[(rel_pos + char_proc_idx) * 8 +: 8] <= syllable_text[line_proc_idx][syl_proc_idx][char_proc_idx];
                                    char_proc_idx <= char_proc_idx + 1;
                                    v2_has_data <= 1;
                                end else begin
                                    if (char_proc_idx < syllable_time[line_proc_idx][syl_proc_idx]) begin
                                        temp_line2[(rel_pos + char_proc_idx) * 8 +: 8] <= 8'h5F;
                                        char_proc_idx <= char_proc_idx + 1;
                                    end else begin
                                        syl_proc_idx <= syl_proc_idx + 1;
                                        char_proc_idx <= 0;
                                    end
                                end
                            end else begin
                                syl_proc_idx <= syl_proc_idx + 1;
                                char_proc_idx <= 0;
                            end
                        end else begin
                            line_proc_idx <= line_proc_idx + 1;
                            syl_proc_idx <= 0;
                            char_proc_idx <= 0;
                        end
                    end else begin
                        if (!v2_has_data) begin
                            temp_line2 <= {200{8'h2F}}; // '/'
                        end
                        state <= S_OUTPUT;
                    end
                end

                S_OUTPUT: begin
                    line1_out <= temp_line1;
                    line2_out <= temp_line2;
                    output_valid <= 1;
                    state <= S_NEXT_LINE;
                end

                S_NEXT_LINE: begin
                    output_valid <= 0;
                    cur_line_idx <= cur_line_idx + 1;
                    cur_abs_time <= cur_abs_time + total_line_dur;
                    if (cur_line_idx >= num_lines) begin
                        state <= S_DONE;
                        done <= 1;
                    end else begin
                        state <= S_PROC_V1;
                        proc_syl_idx <= 0;
                        proc_char_idx <= 0;
                        v1_cursor <= 0;
                        total_line_dur <= 0;
                        temp_line1 <= {200{8'h5F}};
                    end
                end

                S_DONE: begin
                    done <= 1;
                    if (!start) begin
                        done <= 0;
                        state <= S_IDLE;
                    end
                end
            endcase
        end
    end

endmodule