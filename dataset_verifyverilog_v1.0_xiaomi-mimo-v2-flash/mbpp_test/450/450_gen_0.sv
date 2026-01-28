module FilterStrings (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len_req,
    input wire [7:0] str_arr [0:15][0:7],
    output reg [7:0] result_arr [0:15][0:7],
    output reg [3:0] result_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] CALC_LEN = 3'd1;
    localparam [2:0] STORE    = 3'd2;
    localparam [2:0] DONE     = 3'd3;
    
    // Internal registers
    reg [2:0] state;
    reg [3:0] idx;               // Current string index (0-15)
    reg [3:0] calc_len;          // Calculated length for current string
    reg [3:0] char_idx;          // Character index for length scan (0-8)
    reg match_found;             // Flag if current string matches len_req
    
    // Temporary storage for current string processing
    reg [7:0] current_str [0:7];
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            idx <= 4'd0;
            calc_len <= 4'd0;
            char_idx <= 4'd0;
            match_found <= 1'b0;
            result_count <= 4'd0;
            done <= 1'b0;
            
            // Initialize result_arr to zeros
            for (i = 0; i < 16; i = i + 1) begin
                result_arr[i][0] <= 8'd0;
                result_arr[i][1] <= 8'd0;
                result_arr[i][2] <= 8'd0;
                result_arr[i][3] <= 8'd0;
                result_arr[i][4] <= 8'd0;
                result_arr[i][5] <= 8'd0;
                result_arr[i][6] <= 8'd0;
                result_arr[i][7] <= 8'd0;
            end
            
            // Initialize current_str
            for (i = 0; i < 8; i = i + 1) begin
                current_str[i] <= 8'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_count <= 4'd0;
                    idx <= 4'd0;
                    calc_len <= 4'd0;
                    char_idx <= 4'd0;
                    match_found <= 1'b0;
                    
                    // Clear result array when starting new operation
                    if (start) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            result_arr[i][0] <= 8'd0;
                            result_arr[i][1] <= 8'd0;
                            result_arr[i][2] <= 8'd0;
                            result_arr[i][3] <= 8'd0;
                            result_arr[i][4] <= 8'd0;
                            result_arr[i][5] <= 8'd0;
                            result_arr[i][6] <= 8'd0;
                            result_arr[i][7] <= 8'd0;
                        end
                        state <= CALC_LEN;
                    end
                end
                
                CALC_LEN: begin
                    // Load current string into temporary register
                    current_str[0] <= str_arr[idx][0];
                    current_str[1] <= str_arr[idx][1];
                    current_str[2] <= str_arr[idx][2];
                    current_str[3] <= str_arr[idx][3];
                    current_str[4] <= str_arr[idx][4];
                    current_str[5] <= str_arr[idx][5];
                    current_str[6] <= str_arr[idx][6];
                    current_str[7] <= str_arr[idx][7];
                    
                    // Start scanning from beginning
                    char_idx <= 4'd0;
                    calc_len <= 4'd0;
                    state <= STORE;
                end
                
                STORE: begin
                    // Process length calculation for current character
                    if (char_idx < 4'd8) begin
                        // Check if current character is null
                        if (current_str[char_idx] == 8'd0) begin
                            // Found null byte, length is char_idx
                            calc_len <= char_idx;
                            char_idx <= 4'd8; // Move to next step
                        end else if (char_idx == 4'd7) begin
                            // Last character and not null, string length is 8
                            calc_len <= 4'd8;
                            char_idx <= 4'd8;
                        end else begin
                            // Continue scanning
                            char_idx <= char_idx + 4'd1;
                        end
                    end else begin
                        // Length calculation complete, check match
                        if (calc_len == len_req) begin
                            match_found <= 1'b1;
                            result_count <= result_count + 4'd1;
                            
                            // Copy string to result array
                            result_arr[idx][0] <= current_str[0];
                            result_arr[idx][1] <= current_str[1];
                            result_arr[idx][2] <= current_str[2];
                            result_arr[idx][3] <= current_str[3];
                            result_arr[idx][4] <= current_str[4];
                            result_arr[idx][5] <= current_str[5];
                            result_arr[idx][6] <= current_str[6];
                            result_arr[idx][7] <= current_str[7];
                        end else begin
                            match_found <= 1'b0;
                            // Result array already zeroed from IDLE
                        end
                        
                        // Move to next string or finish
                        if (idx == 4'd15) begin
                            state <= DONE;
                        end else begin
                            idx <= idx + 4'd1;
                            state <= CALC_LEN;
                        end
                    end
                end
                
                DONE: begin
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