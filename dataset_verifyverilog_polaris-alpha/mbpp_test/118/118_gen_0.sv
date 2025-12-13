module string_splitter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [127:0] str_in,
    output reg  [511:0] words_out,
    output reg  [3:0]   word_count,
    output reg          done
);

    // Internal registers
    reg        processing;
    reg [4:0]  cycle_cnt;          // counts 0..15
    reg [1:0]  word_idx;           // 0..3
    reg [3:0]  pos_in_word [0:3];  // position counters for each word

    // Extract current byte from str_in based on cycle_cnt
    wire [7:0] curr_char;
    assign curr_char = str_in[127 - cycle_cnt*8 -: 8];

    integer i;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            processing  <= 1'b0;
            cycle_cnt   <= 5'd0;
            word_idx    <= 2'd0;
            word_count  <= 4'd0;
            done        <= 1'b0;
            words_out   <= 512'd0;
            for (i = 0; i < 4; i = i + 1) begin
                pos_in_word[i] <= 4'd0;
            end
        end else begin
            done <= 1'b0; // default

            if (!processing) begin
                // Wait for start pulse
                if (start) begin
                    processing <= 1'b1;
                    cycle_cnt  <= 5'd0;
                    word_idx   <= 2'd0;
                    word_count <= 4'd0;
                    words_out  <= 512'd0;
                    for (i = 0; i < 4; i = i + 1) begin
                        pos_in_word[i] <= 4'd0;
                    end
                end
            end else begin
                // Processing active

                if (cycle_cnt < 5'd16) begin
                    if (curr_char == 8'h20) begin
                        // Space character: possible word boundary
                        if (word_idx < 2'd4) begin
                            if (pos_in_word[word_idx] != 4'd0) begin
                                // Completed a word, prepare for next if available
                                word_idx <= word_idx + 2'd1;
                            end
                        end
                    end else begin
                        // Non-space character: part of a word
                        if (word_idx < 2'd4) begin
                            if (pos_in_word[word_idx] == 4'd0) begin
                                // Starting a new word
                                word_count <= (word_count < 4) ? (word_count + 4'd1) : word_count;
                            end
                            if (pos_in_word[word_idx] < 4'd16) begin
                                // Store character into appropriate word slice
                                case (word_idx)
                                    2'd0: begin
                                        words_out[127 - pos_in_word[0]*8 -: 8] <= curr_char;
                                    end
                                    2'd1: begin
                                        words_out[255 - pos_in_word[1]*8 -: 8] <= curr_char;
                                    end
                                    2'd2: begin
                                        words_out[383 - pos_in_word[2]*8 -: 8] <= curr_char;
                                    end
                                    2'd3: begin
                                        words_out[511 - pos_in_word[3]*8 -: 8] <= curr_char;
                                    end
                                endcase
                                pos_in_word[word_idx] <= pos_in_word[word_idx] + 4'd1;
                            end
                        end
                    end

                    cycle_cnt <= cycle_cnt + 5'd1;
                end

                // After processing 16 characters
                if (cycle_cnt == 5'd16) begin
                    processing <= 1'b0;
                    done       <= 1'b1; // Assert done for one cycle
                end
            end
        end
    end

endmodule