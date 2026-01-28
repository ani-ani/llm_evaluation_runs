module string_filter(
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
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] read_ptr;
    reg [3:0] write_ptr;
    reg [3:0] lut_index;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // LUT to mark characters in str2
    reg [255:0] char_lut;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            read_ptr <= 4'd0;
            write_ptr <= 4'd0;
            lut_index <= 4'd0;
            cycle_count <= 8'd0;
            result_len <= 4'd0;
            done <= 1'b0;
            
            // Initialize result array
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state = PROCESS;
                    end else begin
                        next_state = IDLE;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Build LUT for str2 characters
                    if (lut_index < len2) begin
                        case (lut_index)
                            4'd0: char_lut[str2_0] <= 1'b1;
                            4'd1: char_lut[str2_1] <= 1'b1;
                            4'd2: char_lut[str2_2] <= 1'b1;
                            4'd3: char_lut[str2_3] <= 1'b1;
                            4'd4: char_lut[str2_4] <= 1'b1;
                            4'd5: char_lut[str2_5] <= 1'b1;
                            4'd6: char_lut[str2_6] <= 1'b1;
                            4'd7: char_lut[str2_7] <= 1'b1;
                            default: ;
                        endcase
                        lut_index <= lut_index + 4'd1;
                    
                    // Filter str1 characters
                    else if (read_ptr < len1) begin
                        reg [7:0] current_char;
                        case (read_ptr)
                            4'd0: current_char = str1_0;
                            4'd1: current_char = str1_1;
                            4'd2: current_char = str1_2;
                            4'd3: current_char = str1_3;
                            4'd4: current_char = str1_4;
                            4'd5: current_char = str1_5;
                            4'd6: current_char = str1_6;
                            4'd7: current_char = str1_7;
                            default: current_char = 8'd0;
                        endcase
                        
                        if (!char_lut[current_char]) begin
                            // Character not in str2, keep it
                            case (write_ptr)
                                4'd0: result_0 <= current_char;
                                4'd1: result_1 <= current_char;
                                4'd2: result_2 <= current_char;
                                4'd3: result_3 <= current_char;
                                4'd4: result_4 <= current_char;
                                4'd5: result_5 <= current_char;
                                4'd6: result_6 <= current_char;
                                4'd7: result_7 <= current_char;
                                default: ;
                            endcase
                            write_ptr <= write_ptr + 4'd1;
                        end
                        read_ptr <= read_ptr + 4'd1;
                    
                    // Done with processing
                    else begin
                        result_len <= write_ptr;
                        next_state = DONE_STATE;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        result_len <= write_ptr;
                        next_state = DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state = IDLE;
                end
                
                default: next_state = IDLE;
            endcase
        end
    end

    // Initialize LUT to 0 when starting
    always @(posedge clk) begin
        if (state == PROCESS && lut_index == 4'd0) begin
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                char_lut[i] <= 1'b0;
            end
        end
    end

endmodule