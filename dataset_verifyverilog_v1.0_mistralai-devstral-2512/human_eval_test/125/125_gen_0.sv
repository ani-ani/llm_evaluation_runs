module string_processor(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_data [0:15],
    input [3:0] str_len,
    output reg [1:0] result_type,
    output reg [15:0] result_val,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [3:0] index;
    reg [3:0] count;
    reg [15:0] word_mask;
    reg whitespace_found;
    reg comma_found;
    reg [3:0] whitespace_pos;
    reg [3:0] comma_pos;
    reg [7:0] current_char;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            count <= 4'd0;
            word_mask <= 16'd0;
            whitespace_found <= 1'b0;
            comma_found <= 1'b0;
            whitespace_pos <= 4'd0;
            comma_pos <= 4'd0;
            current_char <= 8'd0;
            cycle_count <= 8'd0;
            result_type <= 2'd0;
            result_val <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        index <= 4'd0;
                        count <= 4'd0;
                        word_mask <= 16'd0;
                        whitespace_found <= 1'b0;
                        comma_found <= 1'b0;
                        whitespace_pos <= 4'd0;
                        comma_pos <= 4'd0;
                        current_char <= 8'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (index < str_len) begin
                        current_char <= char_data[index];
                        
                        // Check for whitespace
                        if (current_char == 8'd32 && !whitespace_found) begin
                            whitespace_found <= 1'b1;
                            whitespace_pos <= index;
                        end
                        
                        // Check for comma
                        if (current_char == 8'd44 && !comma_found) begin
                            comma_found <= 1'b1;
                            comma_pos <= index;
                        end
                        
                        // Count lowercase odd letters
                        if (current_char >= 8'd97 && current_char <= 8'd122) begin
                            if ((current_char - 8'd97) % 2 == 1) begin
                                count <= count + 4'd1;
                            end
                        end
                        
                        // Build word mask
                        if (index == 4'd0) begin
                            word_mask[0] <= 1'b1;
                        end else begin
                            if (char_data[index - 1] == 8'd32 || char_data[index - 1] == 8'd44) begin
                                word_mask[index] <= 1'b1;
                            end else begin
                                word_mask[index] <= 1'b0;
                            end
                        end
                        
                        index <= index + 4'd1;
                    end else begin
                        // Processing complete
                        if (whitespace_found) begin
                            result_type <= whitespace_pos[0] ? 2'd1 : 2'd0;
                            result_val <= word_mask;
                            state <= FINISH;
                        end else if (comma_found) begin
                            result_type <= comma_pos[0] ? 2'd1 : 2'd0;
                            result_val <= word_mask;
                            state <= FINISH;
                        end else begin
                            result_type <= count[0] ? 2'd3 : 2'd2;
                            result_val <= {12'd0, count};
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule