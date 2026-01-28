module delete_pattern_matcher(
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

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_LENGTH = 3'd1;
    localparam [2:0] BUILD_PATTERN = 3'd2;
    localparam [2:0] CHECK_NONDELETE = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Internal registers
    reg [3:0] pattern_len;
    reg [7:0] pattern [0:15];
    reg [3:0] current_file;
    reg [3:0] current_pos;
    reg [3:0] current_delete;
    reg [3:0] current_nondelete;
    reg pattern_valid;
    reg [7:0] temp_char;
    reg char_match;
    reg file_matches;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            pattern_len <= 4'd0;
            current_file <= 4'd0;
            current_pos <= 4'd0;
            current_delete <= 4'd0;
            current_nondelete <= 4'd0;
            pattern_valid <= 1'b0;
            valid <= 1'b0;
            done <= 1'b0;
            result_len <= 4'd0;
            
            // Initialize pattern array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                pattern[i] <= 8'd0;
                result[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CHECK_LENGTH;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_LENGTH: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check all delete files have same length
                    reg [3:0] first_len;
                    reg all_same;
                    integer d;
                    
                    first_len = lengths[delete_idx[0]];
                    all_same = 1'b1;
                    for (d = 1; d < num_delete; d = d + 1) begin
                        if (lengths[delete_idx[d]] != first_len) begin
                            all_same = 1'b0;
                        end
                    end
                    
                    if (all_same && first_len > 4'd0) begin
                        pattern_len = first_len;
                        next_state <= BUILD_PATTERN;
                    end else begin
                        pattern_valid = 1'b0;
                        next_state <= OUTPUT;
                    end
                end

                BUILD_PATTERN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Build pattern character by character
                    if (current_pos < pattern_len) begin
                        // Check if all delete files have same character at this position
                        reg [7:0] first_char;
                        reg all_same_char;
                        integer d;
                        
                        first_char = files[delete_idx[0]][current_pos];
                        all_same_char = 1'b1;
                        for (d = 1; d < num_delete; d = d + 1) begin
                            if (files[delete_idx[d]][current_pos] != first_char) begin
                                all_same_char = 1'b0;
                            end
                        end
                        
                        if (all_same_char) begin
                            pattern[current_pos] = first_char;
                        end else begin
                            pattern[current_pos] = 8'd63; // '?'
                        end
                        
                        current_pos = current_pos + 4'd1;
                        next_state <= BUILD_PATTERN;
                    end else begin
                        current_pos = 4'd0;
                        current_nondelete = 4'd0;
                        pattern_valid = 1'b1;
                        next_state <= CHECK_NONDELETE;
                    end
                end

                CHECK_NONDELETE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if any non-delete file matches the pattern
                    if (current_nondelete < num_files) begin
                        reg is_delete;
                        integer d;
                        
                        // Check if current file is a delete file
                        is_delete = 1'b0;
                        for (d = 0; d < num_delete; d = d + 1) begin
                            if (current_nondelete == delete_idx[d]) begin
                                is_delete = 1'b1;
                            end
                        end
                        
                        if (!is_delete && lengths[current_nondelete] == pattern_len) begin
                            // Check if this file matches the pattern
                            reg [3:0] pos;
                            reg matches;
                            
                            matches = 1'b1;
                            for (pos = 0; pos < pattern_len; pos = pos + 1) begin
                                if (pattern[pos] != 8'd63 && files[current_nondelete][pos] != pattern[pos]) begin
                                    matches = 1'b0;
                                end
                            end
                            
                            if (matches) begin
                                pattern_valid = 1'b0;
                            end
                        end
                        
                        current_nondelete = current_nondelete + 4'd1;
                        next_state <= CHECK_NONDELETE;
                    end else begin
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (pattern_valid) begin
                        valid <= 1'b1;
                        result_len <= pattern_len;
                        
                        // Copy pattern to output
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            result[i] <= pattern[i];
                        end
                    end else begin
                        valid <= 1'b0;
                        result_len <= 4'd0;
                        
                        // Output "No" if no pattern
                        result[0] <= 8'd78; // 'N'
                        result[1] <= 8'd111; // 'o'
                        integer i;
                        for (i = 2; i < 16; i = i + 1) begin
                            result[i] <= 8'd0;
                        end
                    end
                    
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end
endmodule