module max_unique_chars (
    input clk,
    input rst_n,
    input start,
    input [3:0][63:0] word_array,
    output reg [63:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam COUNT_UNIQUES = 2'b01;
    localparam COMPARE = 2'b10;
    localparam DONE = 2'b11;

    // State registers
    reg [1:0] state;
    reg [2:0] byte_index;      // 0-7 for 8 bytes
    reg [3:0] compare_cycle;   // 0-15 for comparison cycles

    // Unique count registers
    reg [7:0] count0, count1, count2, count3;
    reg [255:0] seen0, seen1, seen2, seen3;  // 256-bit seen vectors

    // Comparison registers
    reg [3:0] current_tied;    // 4-bit vector for tied words
    reg [3:0] tied;            // Temporary tied vector
    reg [7:0] max_count;       // Maximum unique count found
    reg [7:0] min_byte;        // Minimum byte in lexicographical comparison
    reg [3:0] new_tied;        // New tied vector during comparison

    // Byte extraction variables
    reg [7:0] byte0, byte1, byte2, byte3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 64'b0;
            byte_index <= 3'b0;
            compare_cycle <= 4'b0;
            count0 <= 8'b0;
            count1 <= 8'b0;
            count2 <= 8'b0;
            count3 <= 8'b0;
            seen0 <= 256'b0;
            seen1 <= 256'b0;
            seen2 <= 256'b0;
            seen3 <= 256'b0;
            current_tied <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset all registers
                        byte_index <= 3'b0;
                        compare_cycle <= 4'b0;
                        count0 <= 8'b0;
                        count1 <= 8'b0;
                        count2 <= 8'b0;
                        count3 <= 8'b0;
                        seen0 <= 256'b0;
                        seen1 <= 256'b0;
                        seen2 <= 256'b0;
                        seen3 <= 256'b0;
                        current_tied <= 4'b0;
                        done <= 1'b0;
                        state <= COUNT_UNIQUES;
                    end
                end

                COUNT_UNIQUES: begin
                    // Extract current byte from each word (MSB first)
                    // word_array[word_index][ (7-byte_index)*8 +: 8 ]
                    case (byte_index)
                        3'd0: begin
                            byte0 = word_array[0][63:56];
                            byte1 = word_array[1][63:56];
                            byte2 = word_array[2][63:56];
                            byte3 = word_array[3][63:56];
                        end
                        3'd1: begin
                            byte0 = word_array[0][55:48];
                            byte1 = word_array[1][55:48];
                            byte2 = word_array[2][55:48];
                            byte3 = word_array[3][55:48];
                        end
                        3'd2: begin
                            byte0 = word_array[0][47:40];
                            byte1 = word_array[1][47:40];
                            byte2 = word_array[2][47:40];
                            byte3 = word_array[3][47:40];
                        end
                        3'd3: begin
                            byte0 = word_array[0][39:32];
                            byte1 = word_array[1][39:32];
                            byte2 = word_array[2][39:32];
                            byte3 = word_array[3][39:32];
                        end
                        3'd4: begin
                            byte0 = word_array[0][31:24];
                            byte1 = word_array[1][31:24];
                            byte2 = word_array[2][31:24];
                            byte3 = word_array[3][31:24];
                        end
                        3'd5: begin
                            byte0 = word_array[0][23:16];
                            byte1 = word_array[1][23:16];
                            byte2 = word_array[2][23:16];
                            byte3 = word_array[3][23:16];
                        end
                        3'd6: begin
                            byte0 = word_array[0][15:8];
                            byte1 = word_array[1][15:8];
                            byte2 = word_array[2][15:8];
                            byte3 = word_array[3][15:8];
                        end
                        3'd7: begin
                            byte0 = word_array[0][7:0];
                            byte1 = word_array[1][7:0];
                            byte2 = word_array[2][7:0];
                            byte3 = word_array[3][7:0];
                        end
                    endcase

                    // Update seen vectors and counts for word 0
                    if (!seen0[byte0]) begin
                        seen0[byte0] <= 1'b1;
                        count0 <= count0 + 1;
                    end

                    // Update seen vectors and counts for word 1
                    if (!seen1[byte1]) begin
                        seen1[byte1] <= 1'b1;
                        count1 <= count1 + 1;
                    end

                    // Update seen vectors and counts for word 2
                    if (!seen2[byte2]) begin
                        seen2[byte2] <= 1'b1;
                        count2 <= count2 + 1;
                    end

                    // Update seen vectors and counts for word 3
                    if (!seen3[byte3]) begin
                        seen3[byte3] <= 1'b1;
                        count3 <= count3 + 1;
                    end

                    // Increment byte index
                    byte_index <= byte_index + 1;

                    // Move to COMPARE state after processing all 8 bytes
                    if (byte_index == 3'd7) begin
                        state <= COMPARE;
                        compare_cycle <= 4'b0;
                    end
                end

                COMPARE: begin
                    if (compare_cycle == 4'b0) begin
                        // Find maximum count
                        max_count = count0;
                        tied = 4'b0001; // Start with word 0
                        
                        if (count1 > max_count) begin
                            max_count = count1;
                            tied = 4'b0010;
                        end else if (count1 == max_count) begin
                            tied = tied | 4'b0010;
                        end
                        
                        if (count2 > max_count) begin
                            max_count = count2;
                            tied = 4'b0100;
                        end else if (count2 == max_count) begin
                            tied = tied | 4'b0100;
                        end
                        
                        if (count3 > max_count) begin
                            max_count = count3;
                            tied = 4'b1000;
                        end else if (count3 == max_count) begin
                            tied = tied | 4'b1000;
                        end
                        
                        current_tied <= tied;
                        compare_cycle <= compare_cycle + 1;
                    end else if (compare_cycle >= 4'b1 && compare_cycle <= 4'b8) begin
                        // Lexicographical comparison
                        new_tied = 4'b0000;
                        min_byte = 8'hFF;

                        // Check word 0
                        if (current_tied[0]) begin
                            case (compare_cycle - 1)
                                4'd0: byte0 = word_array[0][63:56];
                                4'd1: byte0 = word_array[0][55:48];
                                4'd2: byte0 = word_array[0][47:40];
                                4'd3: byte0 = word_array[0][39:32];
                                4'd4: byte0 = word_array[0][31:24];
                                4'd5: byte0 = word_array[0][23:16];
                                4'd6: byte0 = word_array[0][15:8];
                                4'd7: byte0 = word_array[0][7:0];
                            endcase
                            
                            if (byte0 < min_byte) begin
                                min_byte = byte0;
                                new_tied[0] = 1'b1;
                            end else if (byte0 == min_byte) begin
                                new_tied[0] = 1'b1;
                            end
                        end

                        // Check word 1
                        if (current_tied[1]) begin
                            case (compare_cycle - 1)
                                4'd0: byte1 = word_array[1][63:56];
                                4'd1: byte1 = word_array[1][55:48];
                                4'd2: byte1 = word_array[1][47:40];
                                4'd3: byte1 = word_array[1][39:32];
                                4'd4: byte1 = word_array[1][31:24];
                                4'd5: byte1 = word_array[1][23:16];
                                4'd6: byte1 = word_array[1][15:8];
                                4'd7: byte1 = word_array[1][7:0];
                            endcase
                            
                            if (byte1 < min_byte) begin
                                min_byte = byte1;
                                new_tied = 4'b0010;
                            end else if (byte1 == min_byte) begin
                                new_tied[1] = 1'b1;
                            end
                        end

                        // Check word 2
                        if (current_tied[2]) begin
                            case (compare_cycle - 1)
                                4'd0: byte2 = word_array[2][63:56];
                                4'd1: byte2 = word_array[2][55:48];
                                4'd2: byte2 = word_array[2][47:40];
                                4'd3: byte2 = word_array[2][39:32];
                                4'd4: byte2 = word_array[2][31:24];
                                4'd5: byte2 = word_array[2][23:16];
                                4'd6: byte2 = word_array[2][15:8];
                                4'd7: byte2 = word_array[2][7:0];
                            endcase
                            
                            if (byte2 < min_byte) begin
                                min_byte = byte2;
                                new_tied = 4'b0100;
                            end else if (byte2 == min_byte) begin
                                new_tied[2] = 1'b1;
                            end
                        end

                        // Check word 3
                        if (current_tied[3]) begin
                            case (compare_cycle - 1)
                                4'd0: byte3 = word_array[3][63:56];
                                4'd1: byte3 = word_array[3][55:48];
                                4'd2: byte3 = word_array[3][47:40];
                                4'd3: byte3 = word_array[3][39:32];
                                4'd4: byte3 = word_array[3][31:24];
                                4'd5: byte3 = word_array[3][23:16];
                                4'd6: byte3 = word_array[3][15:8];
                                4'd7: byte3 = word_array[3][7:0];
                            endcase
                            
                            if (byte3 < min_byte) begin
                                min_byte = byte3;
                                new_tied = 4'b1000;
                            end else if (byte3 == min_byte) begin
                                new_tied[3] = 1'b1;
                            end
                        end

                        current_tied <= new_tied;

                        // Final selection in last comparison cycle
                        if (compare_cycle == 4'd8) begin
                            if (new_tied[0]) result <= word_array[0];
                            else if (new_tied[1]) result <= word_array[1];
                            else if (new_tied[2]) result <= word_array[2];
                            else if (new_tied[3]) result <= word_array[3];
                            
                            state <= DONE;
                            done <= 1'b1;
                        end else begin
                            compare_cycle <= compare_cycle + 1;
                        end
                    end
                end

                DONE: begin
                    if (start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end
endmodule