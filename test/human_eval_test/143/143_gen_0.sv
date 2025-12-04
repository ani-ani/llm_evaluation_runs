module prime_length_filter (
    input              clk,
    input              rst_n,
    input              start,
    input      [2:0]   word_count,
    input      [7:0]   words [0:7][0:7],
    output reg [63:0]  filtered_sentence,
    output reg [2:0]   word_lengths [0:7],
    output reg         done
);

    // Internal registers
    reg        prev_start;
    reg [2:0]  cycle_cnt;
    reg [2:0]  src_idx;
    reg [2:0]  dst_idx;
    reg [5:0]  bit_pos;      // up to 63 for filtered_sentence index

    // Latched input storage
    reg [2:0]  latched_word_count;
    reg [7:0]  latched_words [0:7][0:7];

    // Edge detection for start
    wire start_rise = start & ~prev_start;

    // Combinational function: count non-zero chars in an 8-char word
    function automatic [2:0] count_len;
        input [7:0] w [0:7];
        integer i;
        reg [2:0] cnt;
    begin
        cnt = 3'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (w[i] != 8'd0)
                cnt = cnt + 3'd1;
        end
        count_len = cnt;
    end
    endfunction

    // Combinational function: prime check for 2,3,5,7
    function automatic is_prime_len;
        input [2:0] len;
    begin
        case (len)
            3'd2, 3'd3, 3'd5, 3'd7: is_prime_len = 1'b1;
            default:                is_prime_len = 1'b0;
        endcase
    end
    endfunction

    integer i, j;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Asynchronous reset
            prev_start         <= 1'b0;
            cycle_cnt          <= 3'd0;
            src_idx            <= 3'd0;
            dst_idx            <= 3'd0;
            bit_pos            <= 6'd0;
            filtered_sentence  <= 64'd0;
            done               <= 1'b0;

            for (i = 0; i < 8; i = i + 1) begin
                word_lengths[i] <= 3'd0;
                for (j = 0; j < 8; j = j + 1) begin
                    latched_words[i][j] <= 8'd0;
                end
            end
            latched_word_count <= 3'd0;
        end else begin
            // Track previous start for edge detection
            prev_start <= start;

            // Start of new processing window on rising edge of start
            if (start_rise) begin
                // Latch inputs
                latched_word_count <= word_count;
                for (i = 0; i < 8; i = i + 1) begin
                    for (j = 0; j < 8; j = j + 1) begin
                        latched_words[i][j] <= words[i][j];
                    end
                end

                // Initialize state for new operation
                cycle_cnt         <= 3'd0;
                src_idx           <= 3'd0;
                dst_idx           <= 3'd0;
                bit_pos           <= 6'd0;
                filtered_sentence <= 64'd0;
                done              <= 1'b0;

                for (i = 0; i < 8; i = i + 1) begin
                    word_lengths[i] <= 3'd0;
                end
            end else begin
                // Processing window active while cycle_cnt < 8
                if (cycle_cnt < 3'd7) begin
                    // We are in cycles 0-6 here; cycle 7 will be handled next path

                    // Process at most one word per cycle
                    if (src_idx < latched_word_count) begin
                        reg [2:0] len;
                        len = count_len(latched_words[src_idx]);

                        if (is_prime_len(len)) begin
                            // Record length for this accepted word
                            word_lengths[dst_idx] <= len;

                            // Append word characters to filtered_sentence in-order
                            for (j = 0; j < 8; j = j + 1) begin
                                if (latched_words[src_idx][j] != 8'd0 && bit_pos < 6'd64) begin
                                    filtered_sentence[bit_pos +: 8] <= latched_words[src_idx][j];
                                    bit_pos <= bit_pos + 6'd8;
                                end
                            end

                            dst_idx <= dst_idx + 3'd1;
                        end

                        src_idx <= src_idx + 3'd1;
                    end

                    cycle_cnt <= cycle_cnt + 3'd1;
                    done      <= 1'b0;
                end else if (cycle_cnt == 3'd7) begin
                    // 8th cycle (cycle_cnt=7): finalize and assert done

                    // Optional final processing if words left (not required by spec),
                    // but we keep outputs stable and just assert done.
                    cycle_cnt <= cycle_cnt + 3'd1; // moves to 8 (saturated usage)
                    done      <= 1'b1;
                end else begin
                    // After 8 cycles, hold done and outputs stable until next start
                    done <= 1'b1;
                end
            end
        end
    end

endmodule