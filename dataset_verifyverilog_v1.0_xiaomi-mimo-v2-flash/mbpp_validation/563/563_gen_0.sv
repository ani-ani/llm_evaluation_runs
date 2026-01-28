module QuotedStringExtractor (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] input_str,
    output reg [63:0] result_0,
    output reg [63:0] result_1,
    output reg [63:0] result_2,
    output reg [63:0] result_3,
    output reg [1:0] result_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH_START = 3'd1;
    localparam [2:0] CAPTURE = 3'd2;
    localparam [2:0] SEARCH_END = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [3:0] byte_idx;      // 0-15 for 16 bytes
    reg [2:0] char_idx;      // 0-7 for 8 chars per result
    reg [1:0] str_idx;       // 0-3 for 4 result strings
    reg inside_quotes;
    reg [7:0] current_byte;
    reg [63:0] temp_result_0;
    reg [63:0] temp_result_1;
    reg [63:0] temp_result_2;
    reg [63:0] temp_result_3;
    reg [1:0] temp_count;
    reg [5:0] cycle_count;   // To prevent infinite loops (0-63)
    localparam [5:0] MAX_CYCLES = 6'd32;

    // Helper wire for current character
    wire [7:0] current_char;
    assign current_char = input_str[(byte_idx * 8) +: 8];

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_0 <= 64'd0;
            result_1 <= 64'd0;
            result_2 <= 64'd0;
            result_3 <= 64'd0;
            result_count <= 2'd0;
            done <= 1'b0;
            byte_idx <= 4'd0;
            char_idx <= 3'd0;
            str_idx <= 2'd0;
            inside_quotes <= 1'b0;
            current_byte <= 8'd0;
            temp_result_0 <= 64'd0;
            temp_result_1 <= 64'd0;
            temp_result_2 <= 64'd0;
            temp_result_3 <= 64'd0;
            temp_count <= 2'd0;
            cycle_count <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    byte_idx <= 4'd0;
                    char_idx <= 3'd0;
                    str_idx <= 2'd0;
                    inside_quotes <= 1'b0;
                    cycle_count <= 6'd0;
                    temp_result_0 <= 64'd0;
                    temp_result_1 <= 64'd0;
                    temp_result_2 <= 64'd0;
                    temp_result_3 <= 64'd0;
                    temp_count <= 2'd0;
                    
                    if (start) begin
                        state <= SEARCH_START;
                    end
                end

                SEARCH_START: begin
                    cycle_count <= cycle_count + 6'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= COMPLETE;
                    end else begin
                        current_byte <= current_char;
                        
                        if (current_char == 8'd34) begin  // Double quote character
                            inside_quotes <= 1'b1;
                            state <= CAPTURE;
                            char_idx <= 3'd0;
                            // Initialize current result slot to 0
                            case (str_idx)
                                2'd0: temp_result_0 <= 64'd0;
                                2'd1: temp_result_1 <= 64'd0;
                                2'd2: temp_result_2 <= 64'd0;
                                2'd3: temp_result_3 <= 64'd0;
                                default: temp_result_0 <= 64'd0;
                            endcase
                        end
                        
                        byte_idx <= byte_idx + 4'd1;
                        if (byte_idx >= 4'd15) begin
                            state <= COMPLETE;
                        end
                    end
                end

                CAPTURE: begin
                    cycle_count <= cycle_count + 6'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= COMPLETE;
                    end else begin
                        current_byte <= current_char;
                        
                        if (current_char == 8'd34) begin
                            // End quote found
                            inside_quotes <= 1'b0;
                            temp_count <= str_idx + 2'd1;
                            str_idx <= str_idx + 2'd1;
                            
                            if (str_idx >= 2'd3) begin
                                // Already extracted 4 strings
                                state <= COMPLETE;
                            end else begin
                                state <= SEARCH_END;
                            end
                        end else if (char_idx < 3'd7) begin
                            // Capture character (not quote)
                            case (str_idx)
                                2'd0: begin
                                    temp_result_0 <= {temp_result_0[55:0], current_byte};
                                end
                                2'd1: begin
                                    temp_result_1 <= {temp_result_1[55:0], current_byte};
                                end
                                2'd2: begin
                                    temp_result_2 <= {temp_result_2[55:0], current_byte};
                                end
                                2'd3: begin
                                    temp_result_3 <= {temp_result_3[55:0], current_byte};
                                end
                            endcase
                            char_idx <= char_idx + 3'd1;
                            byte_idx <= byte_idx + 4'd1;
                            
                            if (byte_idx >= 4'd15) begin
                                state <= COMPLETE;
                            end
                        end else begin
                            // Reached 8 char limit for this string
                            // Continue searching for end quote without adding
                            byte_idx <= byte_idx + 4'd1;
                            if (byte_idx >= 4'd15) begin
                                state <= COMPLETE;
                            end
                        end
                    end
                end

                SEARCH_END: begin
                    cycle_count <= cycle_count + 6'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= COMPLETE;
                    end else begin
                        current_byte <= current_char;
                        
                        if (current_char == 8'd34) begin
                            // Start of next quoted string
                            inside_quotes <= 1'b1;
                            state <= CAPTURE;
                            char_idx <= 3'd0;
                            
                            // Initialize next result slot
                            case (str_idx)
                                2'd1: temp_result_1 <= 64'd0;
                                2'd2: temp_result_2 <= 64'd0;
                                2'd3: temp_result_3 <= 64'd0;
                                default: temp_result_1 <= 64'd0;
                            endcase
                        end
                        
                        byte_idx <= byte_idx + 4'd1;
                        if (byte_idx >= 4'd15) begin
                            state <= COMPLETE;
                        end
                    end
                end

                COMPLETE: begin
                    done <= 1'b1;
                    result_0 <= temp_result_0;
                    result_1 <= temp_result_1;
                    result_2 <= temp_result_2;
                    result_3 <= temp_result_3;
                    result_count <= temp_count;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule