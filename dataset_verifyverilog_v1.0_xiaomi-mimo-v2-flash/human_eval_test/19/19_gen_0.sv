module Sorter(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    output reg [319:0] sorted_words,
    output reg [2:0] word_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] COLLECT    = 3'd1;
    localparam [2:0] CONVERT    = 3'd2;
    localparam [3:0] SORTING    = 4'd3;
    localparam [2:0] PACK       = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] word_idx;
    reg [2:0] char_idx;
    reg [4:0] word_buffer [0:7];
    reg [3:0] values [0:7];
    reg [3:0] sorted_values [0:7];
    reg [2:0] sort_count;
    reg [2:0] i_idx, j_idx;
    reg [1:0] pack_state;
    reg [2:0] pack_idx;
    reg [4:0] pack_temp;
    reg [2:0] cycle_counter;
    
    // Word memory for output
    reg [39:0] word_mem [0:7];
    
    // ASCII mapping
    wire [3:0] ascii_value;
    assign ascii_value = (char_in == 8'h30) ? 4'd0 :
                         (char_in == 8'h31) ? 4'd1 :
                         (char_in == 8'h32) ? 4'd2 :
                         (char_in == 8'h33) ? 4'd3 :
                         (char_in == 8'h34) ? 4'd4 :
                         (char_in == 8'h35) ? 4'd5 :
                         (char_in == 8'h36) ? 4'd6 :
                         (char_in == 8'h37) ? 4'd7 :
                         (char_in == 8'h38) ? 4'd8 :
                         (char_in == 8'h39) ? 4'd9 : 4'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            word_count <= 3'd0;
            sorted_words <= 320'd0;
            word_idx <= 3'd0;
            char_idx <= 3'd0;
            sort_count <= 3'd0;
            i_idx <= 3'd0;
            j_idx <= 3'd0;
            pack_state <= 2'd0;
            pack_idx <= 3'd0;
            cycle_counter <= 3'd0;
            // Initialize arrays
            begin : init_arrays
                integer k;
                for (k = 0; k < 8; k = k + 1) begin
                    word_buffer[k] <= 5'd0;
                    values[k] <= 4'd0;
                    sorted_values[k] <= 4'd0;
                    word_mem[k] <= 40'd0;
                end
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    word_count <= 3'd0;
                    sorted_words <= 320'd0;
                    word_idx <= 3'd0;
                    char_idx <= 3'd0;
                    sort_count <= 3'd0;
                    i_idx <= 3'd0;
                    j_idx <= 3'd0;
                    pack_state <= 2'd0;
                    pack_idx <= 3'd0;
                    cycle_counter <= 3'd0;
                    if (start) begin
                        word_idx <= 3'd0;
                        char_idx <= 3'd0;
                    end
                end

                COLLECT: begin
                    if (char_valid) begin
                        if (char_in == 8'h20 || char_in == 8'h0A || char_in == 8'h0D) begin
                            // Space or newline
                            if (char_idx > 3'd0 && word_idx < 3'd8) begin
                                word_idx <= word_idx + 3'd1;
                            end
                            char_idx <= 3'd0;
                        end else if (char_idx < 3'd5 && word_idx < 3'd8) begin
                            word_buffer[word_idx][char_idx*8 +: 8] <= char_in;
                            char_idx <= char_idx + 3'd1;
                        end
                    end
                    // Update word_count based on collected words
                    word_count <= word_idx + (char_idx > 3'd0 ? 3'd1 : 3'd0);
                end

                CONVERT: begin
                    // Convert stored ASCII words to numeric values
                    begin : convert_loop
                        integer w;
                        for (w = 0; w < 8; w = w + 1) begin
                            if (w < word_count) begin
                                case (word_buffer[w][7:0])
                                    8'h30: values[w] <= 4'd0;
                                    8'h31: values[w] <= 4'd1;
                                    8'h32: values[w] <= 4'd2;
                                    8'h33: values[w] <= 4'd3;
                                    8'h34: values[w] <= 4'd4;
                                    8'h35: values[w] <= 4'd5;
                                    8'h36: values[w] <= 4'd6;
                                    8'h37: values[w] <= 4'd7;
                                    8'h38: values[w] <= 4'd8;
                                    8'h39: values[w] <= 4'd9;
                                    default: values[w] <= 4'd0;
                                endcase
                            end else begin
                                values[w] <= 4'd0;
                            end
                        end
                    end
                    // Copy to sorted_values for sorting
                    begin : copy_to_sort
                        integer c;
                        for (c = 0; c < 8; c = c + 1) begin
                            sorted_values[c] <= values[c];
                        end
                    end
                    sort_count <= 3'd0;
                    i_idx <= 3'd0;
                    j_idx <= 3'd0;
                end

                SORTING: begin
                    cycle_counter <= cycle_counter + 3'd1;
                    // Bubble sort: compare adjacent elements
                    if (j_idx < word_count - 3'd1) begin
                        if (sorted_values[j_idx] > sorted_values[j_idx + 3'd1]) begin
                            // Swap
                            sorted_values[j_idx] <= sorted_values[j_idx + 3'd1];
                            sorted_values[j_idx + 3'd1] <= sorted_values[j_idx];
                        end
                        j_idx <= j_idx + 3'd1;
                    end else begin
                        // Completed pass
                        i_idx <= i_idx + 3'd1;
                        j_idx <= 3'd0;
                        if (i_idx >= word_count - 3'd1 || cycle_counter >= 3'd6) begin
                            // Sorting complete
                            i_idx <= 3'd0;
                            j_idx <= 3'd0;
                        end
                    end
                end

                PACK: begin
                    // Map sorted values back to ASCII words and pack
                    case (pack_state)
                        2'd0: begin
                            // Convert numeric to ASCII string
                            if (pack_idx < word_count) begin
                                case (sorted_values[pack_idx])
                                    4'd0: word_mem[pack_idx] <= {8'h30, 8'h30, 8'h30, 8'h30, 8'h30};
                                    4'd1: word_mem[pack_idx] <= {8'h31, 8'h30, 8'h30, 8'h30, 8'h30};
                                    4'd2: word_mem[pack_idx] <= {8'h32, 8'h30, 8'h30, 8'h30, 8'h30};
                                    4'd3: word_mem[pack_idx] <= {8'h33, 8'h30, 8'h30, 8'h30, 8'h30};
                                    4'd4: word_mem[pack_idx] <= {8'h34, 8'h30, 8'h30, 8'h30, 8'h30};
                                    4'd5: word_mem[pack_idx] <= {8'h35, 8'h30, 8'h30, 8'h30, 8'h30};
                                    4'd6: word_mem[pack_idx] <= {8'h36, 8'h30, 8'h30, 8'h30, 8'h30};
                                    4'd7: word_mem[pack_idx] <= {8'h37, 8'h30, 8'h30, 8'h30, 8'h30};
                                    4'd8: word_mem[pack_idx] <= {8'h38, 8'h30, 8'h30, 8'h30, 8'h30};
                                    4'd9: word_mem[pack_idx] <= {8'h39, 8'h30, 8'h30, 8'h30, 8'h30};
                                    default: word_mem[pack_idx] <= 40'd0;
                                endcase
                                pack_idx <= pack_idx + 3'd1;
                            end else begin
                                pack_state <= 2'd1;
                                pack_idx <= 3'd0;
                            end
                        end
                        2'd1: begin
                            // Pack into 320-bit output
                            sorted_words <= {word_mem[7], word_mem[6], word_mem[5], word_mem[4],
                                            word_mem[3], word_mem[2], word_mem[1], word_mem[0]};
                            pack_state <= 2'd2;
                        end
                        2'd2: begin
                            // Done
                            pack_state <= 2'd0;
                        end
                    endcase
                end

                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COLLECT;
                else
                    next_state = IDLE;
            end

            COLLECT: begin
                // Wait for end of input (no more chars or word limit reached)
                // Transition when we've seen a final delimiter or timeout
                if (char_valid && (char_in == 8'h20 || char_in == 8'h0A || char_in == 8'h0D) && word_count > 3'd0)
                    next_state = CONVERT;
                else if (word_idx >= 3'd7 && char_idx >= 3'd5)
                    next_state = CONVERT;
                else if (cycle_counter >= 3'd5)
                    next_state = CONVERT;
                else
                    next_state = COLLECT;
            end

            CONVERT: next_state = SORTING;

            SORTING: begin
                if (word_count <= 3'd1)
                    next_state = PACK;
                else if (i_idx >= word_count - 3'd1 || cycle_counter >= 3'd6)
                    next_state = PACK;
                else
                    next_state = SORTING;
            end

            PACK: begin
                if (pack_state == 2'd2)
                    next_state = FINISH;
                else
                    next_state = PACK;
            end

            FINISH: next_state = IDLE;

            default: next_state = IDLE;
        endcase
    end

endmodule