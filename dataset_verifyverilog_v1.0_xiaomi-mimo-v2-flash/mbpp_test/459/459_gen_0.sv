module remove_uppercase (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] input_string,
    input wire [3:0] input_length,
    output reg [127:0] output_string,
    output reg [3:0] output_length,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] SCAN_CHAR     = 3'd1;
    localparam [2:0] CHECK_Upper   = 3'd2;
    localparam [2:0] COPY_CHAR     = 3'd3;
    localparam [2:0] SKIP_CHAR     = 3'd4;
    localparam [2:0] PAD_OUTPUT    = 3'd5;
    localparam [2:0] FINISH        = 3'd6;
    
    reg [2:0] state, next_state;
    reg [3:0] idx_in;           // Current character index to read (0-15)
    reg [3:0] idx_out;          // Next position in output buffer to write (0-15)
    reg [7:0] char_data;        // Current character byte being processed
    reg [3:0] valid_count;      // Number of lowercase chars copied
    reg [3:0] pad_idx;          // Used for padding phase
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            output_string <= 128'd0;
            output_length <= 4'd0;
            done <= 1'b0;
            idx_in <= 4'd0;
            idx_out <= 4'd0;
            char_data <= 8'd0;
            valid_count <= 4'd0;
            pad_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx_in <= 4'd0;
                    idx_out <= 4'd0;
                    valid_count <= 4'd0;
                    pad_idx <= 4'd0;
                    output_length <= 4'd0;
                    // Initialize output_string to zeros
                    output_string <= 128'd0;
                    if (start && input_length > 4'd0) begin
                        state <= SCAN_CHAR;
                    end else if (start) begin
                        state <= FINISH;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                SCAN_CHAR: begin
                    if (idx_in < input_length && idx_in < 4'd16) begin
                        // Extract current character
                        case (idx_in)
                            4'd0: char_data <= input_string[7:0];
                            4'd1: char_data <= input_string[15:8];
                            4'd2: char_data <= input_string[23:16];
                            4'd3: char_data <= input_string[31:24];
                            4'd4: char_data <= input_string[39:32];
                            4'd5: char_data <= input_string[47:40];
                            4'd6: char_data <= input_string[55:48];
                            4'd7: char_data <= input_string[63:56];
                            4'd8: char_data <= input_string[71:64];
                            4'd9: char_data <= input_string[79:72];
                            4'd10: char_data <= input_string[87:80];
                            4'd11: char_data <= input_string[95:88];
                            4'd12: char_data <= input_string[103:96];
                            4'd13: char_data <= input_string[111:104];
                            4'd14: char_data <= input_string[119:112];
                            4'd15: char_data <= input_string[127:120];
                            default: char_data <= 8'd0;
                        endcase
                        state <= CHECK_Upper;
                    end else begin
                        state <= PAD_OUTPUT;
                    end
                end
                
                CHECK_Upper: begin
                    // Check if ASCII value is in range 65-90 (A-Z)
                    if (char_data >= 8'd65 && char_data <= 8'd90) begin
                        state <= SKIP_CHAR;
                    end else begin
                        state <= COPY_CHAR;
                    end
                end
                
                COPY_CHAR: begin
                    if (idx_out < 4'd16) begin
                        // Copy character to output buffer
                        case (idx_out)
                            4'd0:  output_string[7:0]   <= char_data;
                            4'd1:  output_string[15:8]  <= char_data;
                            4'd2:  output_string[23:16] <= char_data;
                            4'd3:  output_string[31:24] <= char_data;
                            4'd4:  output_string[39:32] <= char_data;
                            4'd5:  output_string[47:40] <= char_data;
                            4'd6:  output_string[55:48] <= char_data;
                            4'd7:  output_string[63:56] <= char_data;
                            4'd8:  output_string[71:64] <= char_data;
                            4'd9:  output_string[79:72] <= char_data;
                            4'd10: output_string[87:80] <= char_data;
                            4'd11: output_string[95:88] <= char_data;
                            4'd12: output_string[103:96] <= char_data;
                            4'd13: output_string[111:104] <= char_data;
                            4'd14: output_string[119:112] <= char_data;
                            4'd15: output_string[127:120] <= char_data;
                        endcase
                        idx_out <= idx_out + 4'd1;
                        valid_count <= valid_count + 4'd1;
                    end
                    idx_in <= idx_in + 4'd1;
                    state <= SCAN_CHAR;
                end
                
                SKIP_CHAR: begin
                    idx_in <= idx_in + 4'd1;
                    state <= SCAN_CHAR;
                end
                
                PAD_OUTPUT: begin
                    // Pad remaining positions with 0x00
                    if (pad_idx < 4'd16) begin
                        if (pad_idx >= idx_out) begin
                            case (pad_idx)
                                4'd0:  output_string[7:0]   <= 8'd0;
                                4'd1:  output_string[15:8]  <= 8'd0;
                                4'd2:  output_string[23:16] <= 8'd0;
                                4'd3:  output_string[31:24] <= 8'd0;
                                4'd4:  output_string[39:32] <= 8'd0;
                                4'd5:  output_string[47:40] <= 8'd0;
                                4'd6:  output_string[55:48] <= 8'd0;
                                4'd7:  output_string[63:56] <= 8'd0;
                                4'd8:  output_string[71:64] <= 8'd0;
                                4'd9:  output_string[79:72] <= 8'd0;
                                4'd10: output_string[87:80] <= 8'd0;
                                4'd11: output_string[95:88] <= 8'd0;
                                4'd12: output_string[103:96] <= 8'd0;
                                4'd13: output_string[111:104] <= 8'd0;
                                4'd14: output_string[119:112] <= 8'd0;
                                4'd15: output_string[127:120] <= 8'd0;
                            endcase
                        end
                        pad_idx <= pad_idx + 4'd1;
                        state <= PAD_OUTPUT;
                    end else begin
                        output_length <= valid_count;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule