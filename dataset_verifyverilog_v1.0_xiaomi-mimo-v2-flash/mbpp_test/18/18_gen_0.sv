module remove_chars (
    input clk,
    input rst_n,
    input start,
    input [7:0] str1_0,
    input [7:0] str1_1,
    input [7:0] str1_2,
    input [7:0] str1_3,
    input [7:0] str1_4,
    input [7:0] str1_5,
    input [7:0] str1_6,
    input [7:0] str1_7,
    input [7:0] str2_0,
    input [7:0] str2_1,
    input [7:0] str2_2,
    input [7:0] str2_3,
    input [7:0] str2_4,
    input [7:0] str2_5,
    input [7:0] str2_6,
    input [7:0] str2_7,
    input [3:0] len1,
    input [3:0] len2,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg [3:0] result_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SETUP_LUT = 2'd1;
    localparam [1:0] PROCESS = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] lut_ptr, next_lut_ptr;
    reg [3:0] read_ptr, next_read_ptr;
    reg [3:0] write_ptr, next_write_ptr;
    reg [3:0] result_len_reg, next_result_len_reg;
    reg lut_valid, next_lut_valid;
    
    // LUT registers (256 entries, 1-bit each)
    reg [255:0] lut_reg, next_lut_reg;
    
    // Str1 and Str2 arrays for easier access
    reg [7:0] str1_arr [0:7];
    reg [7:0] str2_arr [0:7];
    
    // Combinational logic for LUT setup
    reg [7:0] lut_char;
    reg lut_bit;
    
    // Output result array
    reg [7:0] result_arr [0:7];

    // Initialize arrays (non-blocking in always block)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            str1_arr[0] <= 8'd0;
            str1_arr[1] <= 8'd0;
            str1_arr[2] <= 8'd0;
            str1_arr[3] <= 8'd0;
            str1_arr[4] <= 8'd0;
            str1_arr[5] <= 8'd0;
            str1_arr[6] <= 8'd0;
            str1_arr[7] <= 8'd0;
            str2_arr[0] <= 8'd0;
            str2_arr[1] <= 8'd0;
            str2_arr[2] <= 8'd0;
            str2_arr[3] <= 8'd0;
            str2_arr[4] <= 8'd0;
            str2_arr[5] <= 8'd0;
            str2_arr[6] <= 8'd0;
            str2_arr[7] <= 8'd0;
        end else if (start) begin
            str1_arr[0] <= str1_0;
            str1_arr[1] <= str1_1;
            str1_arr[2] <= str1_2;
            str1_arr[3] <= str1_3;
            str1_arr[4] <= str1_4;
            str1_arr[5] <= str1_5;
            str1_arr[6] <= str1_6;
            str1_arr[7] <= str1_7;
            str2_arr[0] <= str2_0;
            str2_arr[1] <= str2_1;
            str2_arr[2] <= str2_2;
            str2_arr[3] <= str2_3;
            str2_arr[4] <= str2_4;
            str2_arr[5] <= str2_5;
            str2_arr[6] <= str2_6;
            str2_arr[7] <= str2_7;
        end
    end

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            lut_ptr <= 4'd0;
            read_ptr <= 4'd0;
            write_ptr <= 4'd0;
            result_len_reg <= 4'd0;
            lut_valid <= 1'b0;
            lut_reg <= 256'd0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            result_len <= 4'd0;
            done <= 1'b0;
            // Initialize result_arr
            result_arr[0] <= 8'd0;
            result_arr[1] <= 8'd0;
            result_arr[2] <= 8'd0;
            result_arr[3] <= 8'd0;
            result_arr[4] <= 8'd0;
            result_arr[5] <= 8'd0;
            result_arr[6] <= 8'd0;
            result_arr[7] <= 8'd0;
        end else begin
            state <= next_state;
            lut_ptr <= next_lut_ptr;
            read_ptr <= next_read_ptr;
            write_ptr <= next_write_ptr;
            result_len_reg <= next_result_len_reg;
            lut_valid <= next_lut_valid;
            lut_reg <= next_lut_reg;
            result_len <= result_len_reg;
            
            // Update result outputs when done
            if (state == FINISH) begin
                result_0 <= result_arr[0];
                result_1 <= result_arr[1];
                result_2 <= result_arr[2];
                result_3 <= result_arr[3];
                result_4 <= result_arr[4];
                result_5 <= result_arr[5];
                result_6 <= result_arr[6];
                result_7 <= result_arr[7];
            end
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        next_lut_ptr = lut_ptr;
        next_read_ptr = read_ptr;
        next_write_ptr = write_ptr;
        next_result_len_reg = result_len_reg;
        next_lut_valid = lut_valid;
        next_lut_reg = lut_reg;
        done = 1'b0;
        
        // Default for result_arr
        result_arr[0] = result_arr[0];
        result_arr[1] = result_arr[1];
        result_arr[2] = result_arr[2];
        result_arr[3] = result_arr[3];
        result_arr[4] = result_arr[4];
        result_arr[5] = result_arr[5];
        result_arr[6] = result_arr[6];
        result_arr[7] = result_arr[7];

        case (state)
            IDLE: begin
                next_lut_valid = 1'b0;
                next_lut_ptr = 4'd0;
                next_read_ptr = 4'd0;
                next_write_ptr = 4'd0;
                next_result_len_reg = 4'd0;
                next_lut_reg = 256'd0;
                done = 1'b0;
                
                if (start) begin
                    next_state = SETUP_LUT;
                end
            end
            
            SETUP_LUT: begin
                next_lut_reg = lut_reg;
                next_lut_valid = lut_valid;
                
                // Build LUT based on str2 characters
                if (lut_ptr < len2) begin
                    lut_char = str2_arr[lut_ptr];
                    next_lut_reg[lut_char] = 1'b1;
                    next_lut_ptr = lut_ptr + 4'd1;
                end else begin
                    next_lut_valid = 1'b1;
                    next_lut_ptr = 4'd0;
                    next_state = PROCESS;
                end
            end
            
            PROCESS: begin
                if (read_ptr < len1) begin
                    lut_char = str1_arr[read_ptr];
                    lut_bit = lut_reg[lut_char];
                    
                    if (!lut_bit && lut_char != 8'd0) begin
                        // Keep character
                        result_arr[write_ptr] = lut_char;
                        next_write_ptr = write_ptr + 4'd1;
                        next_result_len_reg = result_len_reg + 4'd1;
                    end
                    next_read_ptr = read_ptr + 4'd1;
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule