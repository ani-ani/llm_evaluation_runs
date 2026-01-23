module substring_search (input clk, input rst_n, input start, input [7:0] str_data, input [2:0] str_idx, input [2:0] char_idx, input [2:0] substr_len, output reg found, output reg done);
localparam IDLE = 3'd0, LOAD_SUBSTR = 3'd1, CHECK_STRING = 3'd2, FOUND = 3'd3, DONE = 3'd4;
reg [2:0] state;
reg [2:0] current_string_idx;
reg [2:0] char_count;
reg [2:0] substr_len_reg;
reg [6:0] substring [7:0];
reg [7:0] current_string_buffer [7:0];
reg [2:0] load_counter;
reg [2:0] substr_idx;
reg found_flag;
reg done_flag;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        current_string_idx <= 0;
        char_count <= 0;
        substr_len_reg <= 0;
        load_counter <= 0;
        substr_idx <= 0;
        for (int i=0; i<7; i=i+1) substring[i] <= 8'b0;
        for (int i=0; i<8; i=i+1) current_string_buffer[i] <= 8'b0;
        found_flag <= 0;
        done_flag <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= LOAD_SUBSTR;
                    substr_len_reg <= substr_len;
                    load_counter <= substr_len_reg;
                    substr_idx <= 0;
                end
            end
            LOAD_SUBSTR: begin
                if (load_counter > 0) begin
                    substring[substr_idx] <= str_data;
                    substr_idx <= substr_idx + 1;
                    load_counter <= load_counter - 1;
                end else begin
                    state <= CHECK_STRING;
                    load_counter <= 0;
                    substr_idx <= 0;
                    current_string_idx <= 0;
                    char_count <= 0;
                end
            end
            CHECK_STRING: begin
                if (str_idx == current_string_idx && char_idx == char_count) begin
                    current_string_buffer[char_count] <= str_data;
                    char_count <= char_count + 1;
                    if (char_count == 8) begin
                        if (substr_len_reg == 1) begin
                            match_found = (current_string_buffer[0] == substring[0]) || (current_string_buffer[1] == substring[0]) || (current_string_buffer[2] == substring[0]) || (current_string_buffer[3] == substring[0]) || (current_string_buffer[4] == substring[0]) || (current_string_buffer[5] == substring[0]) || (current_string_buffer[6] == substring[0]) || (current_string_buffer[7] == substring[0]);
                        end else if (substr_len_reg == 2) begin
                            match_found = (current_string_buffer[0] == substring[0] && current_string_buffer[1] == substring[1]) || (current_string_buffer[1] == substring[0] && current_string_buffer[2] == substring[1]) || (current_string_buffer[2] == substring[0] && current_string_buffer[3] == substring[1]) || (current_string_buffer[3] == substring[0] && current_string_buffer[4] == substring[1]) || (current_string_buffer[4] == substring[0] && current_string_buffer[5] == substring[1]) || (current_string_buffer[5] == substring[0] && current_string_buffer[6] == substring[1]) || (current_string_buffer[6] == substring[0] && current_string_buffer[7] == substring[1]);
                        end else if (substr_len_reg == 3) begin
                            match_found = (current_string_buffer[0] == substring[0] && current_string_buffer[1] == substring[1] && current_string_buffer[2] == substring[2]) || (current_string_buffer[1] == substring[0] && current_string_buffer[2] == substring[1] && current_string_buffer[3] == substring[2]) || (current_string_buffer[2] == substring[0] && current_string_buffer[3] == substring[1] && current_string_buffer[4] == substring[2]) || (current_string_buffer[3] == substring[0] && current_string_buffer[4] == substring[1] && current_string_buffer[5] == substring[2]) || (current_string_buffer[4] == substring[0] && current_string_buffer[5] == substring[1] && current_string_buffer[6] == substring[2]) || (current_string_buffer[5] == substring[0] && current_string_buffer[6] == substring[1] && current_string_buffer[7] == substring[2]);
                        end else if (substr_len_reg == 4) begin
                            match_found = (current_string_buffer[0] == substring[0] && current_string_buffer[1] == substring[1] && current_string_buffer[2] == substring[2] && current_string_buffer[3] == substring[3]) || (current_string_buffer[1] == substring[0] && current_string_buffer[2] == substring[1] && current_string_buffer[3] == substring[2] && current_string_buffer[4] == substring[3]) || (current_string_buffer[2] == substring[0] && current_string_buffer[3] == substring[1] && current_string_buffer[4] == substring[2] && current_string_buffer[5] == substring[3]) || (current_string_buffer[3] == substring[0] && current_string_buffer[4] == substring[1] && current_string_buffer[5] == substring[2] && current_string_buffer[6] == substring[3]) || (current_string_buffer[4] == substring[0] && current_string_buffer[5] == substring[1] && current_string_buffer[6] == substring[2] && current_string_buffer[7] == substring[3]);
                        end else if (substr_len_reg == 5) begin
                            match_found = (current_string_buffer[0] == substring[0] && current_string_buffer[1] == substring[1] && current_string_buffer[2] == substring[2] && current_string_buffer[3] == substring[3] && current_string_buffer[4] == substring[4]) || (current_string_buffer[1] == substring[0] && current_string_buffer[2] == substring[1] && current_string_buffer[3] == substring[2] && current_string_buffer[4] == substring[3] && current_string_buffer[5] == substring[4]) || (current_string_buffer[2] == substring[0] && current_string_buffer[3] == substring[1] && current_string_buffer[4] == substring[2] && current_string_buffer[5] == substring[3] && current_string_buffer[6] == substring[4]) || (current_string_buffer[3] == substring[0] && current_string_buffer[4] == substring[1] && current_string_buffer[5] == substring[2] && current_string_buffer[6] == substring[3] && current_string_buffer[7] == substring[4]);
                        end else if (substr_len_reg == 6) begin
                            match_found = (current_string_buffer[0] == substring[0] && current_string_buffer[1] == substring[1] && current_string_buffer[2] == substring[2] && current_string_buffer[3] == substring[3] && current_string_buffer[4] == substring[4] && current_string_buffer[5] == substring[5]) || (current_string_buffer[1] == substring[0] && current_string_buffer[2] == substring[1] && current_string_buffer[3] == substring[2] && current_string_buffer[4] == substring[3] && current_string_buffer[5] == substring[4] && current_string_buffer[6] == substring[5]) || (current_string_buffer[2] == substring[0] && current_string_buffer[3] == substring[1] && current_string_buffer[4] == substring[2] && current_string_buffer[5] == substring[3] && current_string_buffer[6] == substring[4] && current_string_buffer[7] == substring[5]);
                        end else if (substr_len_reg == 7) begin
                            match_found = (current_string_buffer[0] == substring[0] && current_string_buffer[1] == substring[1] && current_string_buffer[2] == substring[2] && current_string_buffer[3] == substring[3] && current_string_buffer[4] == substring[4] && current_string_buffer[5] == substring[5] && current_string_buffer[6] == substring[6]) || (current_string_buffer[1] == substring[0] && current_string_buffer[2] == substring[1] && current_string_buffer[3] == substring[2] && current_string_buffer[4] == substring[3] && current_string_buffer[5] == substring[4] && current_string_buffer[6] == substring[5] && current_string_buffer[7] == substring[6]);
                        end
                        if (match_found) begin
                            found_flag <= 1;
                            state <= FOUND;
                        end
                        current_string_idx <= current_string_idx + 1;
                        if (current_string_idx == 5) begin
                            state <= DONE;
                            done_flag <= 1;
                        end else begin
                            char_count <= 0;
                        end
                    end
                end
            end
            FOUND: begin
                if (current_string_idx < 5) begin
                    state <= CHECK_STRING;
                end else begin
                    state <= DONE;
                end
            end
            DONE: begin
                done_flag <= 1;
            end
        endcase
    end
end

assign found = found_flag;
assign done = done_flag;

endmodule