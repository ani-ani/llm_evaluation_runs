module slavko_word (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    output reg [79:0] slavko_word_out,
    output reg [2:0] length_out,
    output reg winnable,
    output reg done
);

    // States
    localparam IDLE = 0;
    localparam LOAD = 1;
    localparam PLAY = 2;
    localparam COMPARE = 3;
    localparam FINISH = 4;

    reg [2:0] state;
    reg [7:0] buffer [0:7];
    reg [4:0] freq [0:25];
    reg [79:0] s_word;
    reg [79:0] m_word;
    reg [2:0] n_chars;
    reg [2:0] turns;
    reg [2:0] step; // Sub-state counter for PLAY
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            winnable <= 0;
            n_chars <= 0;
            for (i = 0; i < 26; i = i + 1) freq[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= LOAD;
                        n_chars <= 0;
                        // Clear freq
                        for (i = 0; i < 26; i = i + 1) freq[i] <= 0;
                    end
                end

                LOAD: begin
                    // Store char and update freq
                    // Assuming 'start' stays high for N cycles or we detect end.
                    // Prompt says "Accept N characters". We assume N=8 or external stop.
                    // Here we assume we load exactly 8 chars or until user stops.
                    // To keep it simple: Load 8 chars or stop if start=0 and n>0.
                    // Let's load 8 chars.
                    
                    if (n_chars < 8) begin
                        buffer[n_chars] <= char_in;
                        if (char_in >= 8'h61 && char_in <= 8'h7A) begin
                            freq[char_in - 8'h61] <= freq[char_in - 8'h61] + 1;
                        end
                        n_chars <= n_chars + 1;
                    end else begin
                        // If full, or if external start drops (indicating end of stream)
                        // We proceed. 
                        // If we assume fixed N=8, we just go to PLAY.
                        state <= PLAY;
                        turns <= n_chars >> 1;
                        s_word <= 0;
                        m_word <= 0;
                        step <= 0; // 0: Mirko, 1: Slavko
                    end
                    
                    // Handle early termination if start drops
                    if (!start && n_chars > 0) begin
                        state <= PLAY;
                        turns <= n_chars >> 1;
                        s_word <= 0;
                        m_word <= 0;
                        step <= 0;
                    end
                end

                PLAY: begin
                    if (turns == 0) begin
                        state <= COMPARE;
                    end else begin
                        if (step == 0) begin
                            // --- MIRKO TURN ---
                            // Find rightmost available index
                            // Logic: Scan i from 7 to 0. Check if freq[buffer[i]] > 0.
                            // Note: We don't need a 'taken' array if we just check freq.
                            // Because freq reflects total remaining.
                            // If Mirko takes 'a' at index 7, freq['a'] decrements.
                            // Next time, if index 6 is 'a', freq['a'] might be 0 (if only 1 total).
                            // Correct.
                            
                            if (freq[buffer[7]-8'h61] > 0) begin
                                freq[buffer[7]-8'h61] <= freq[buffer[7]-8'h61] - 1;
                                m_word <= {m_word[71:0], buffer[7]};
                            end else if (freq[buffer[6]-8'h61] > 0 && n_chars > 6) begin
                                freq[buffer[6]-8'h61] <= freq[buffer[6]-8'h61] - 1;
                                m_word <= {m_word[71:0], buffer[6]};
                            end else if (freq[buffer[5]-8'h61] > 0 && n_chars > 5) begin
                                freq[buffer[5]-8'h61] <= freq[buffer[5]-8'h61] - 1;
                                m_word <= {m_word[71:0], buffer[5]};
                            end else if (freq[buffer[4]-8'h61] > 0 && n_chars > 4) begin
                                freq[buffer[4]-8'h61] <= freq[buffer[4]-8'h61] - 1;
                                m_word <= {m_word[71:0], buffer[4]};
                            end else if (freq[buffer[3]-8'h61] > 0 && n_chars > 3) begin
                                freq[buffer[3]-8'h61] <= freq[buffer[3]-8'h61] - 1;
                                m_word <= {m_word[71:0], buffer[3]};
                            end else if (freq[buffer[2]-8'h61] > 0 && n_chars > 2) begin
                                freq[buffer[2]-8'h61] <= freq[buffer[2]-8'h61] - 1;
                                m_word <= {m_word[71:0], buffer[2]};
                            end else if (freq[buffer[1]-8'h61] > 0 && n_chars > 1) begin
                                freq[buffer[1]-8'h61] <= freq[buffer[1]-8'h61] - 1;
                                m_word <= {m_word[71:0], buffer[1]};
                            end else if (freq[buffer[0]-8'h61] > 0 && n_chars > 0) begin
                                freq[buffer[0]-8'h61] <= freq[buffer[0]-8'h61] - 1;
                                m_word <= {m_word[71:0], buffer[0]};
                            end
                            
                            step <= 1; // Go to Slavko step
                            
                        end else begin // step == 1, SLAVKO TURN
                            // Find smallest available char
                            // Unrolled check a-z
                            if (freq[0] > 0) begin
                                freq[0] <= freq[0] - 1;
                                s_word <= {s_word[71:0], 8'h61};
                            end else if (freq[1] > 0) begin
                                freq[1] <= freq[1] - 1;
                                s_word <= {s_word[71:0], 8'h62};
                            end else if (freq[2] > 0) begin
                                freq[2] <= freq[2] - 1;
                                s_word <= {s_word[71:0], 8'h63};
                            end else if (freq[3] > 0) begin
                                freq[3] <= freq[3] - 1;
                                s_word <= {s_word[71:0], 8'h64};
                            end else if (freq[4] > 0) begin
                                freq[4] <= freq[4] - 1;
                                s_word <= {s_word[71:0], 8'h65};
                            end else if (freq[5] > 0) begin
                                freq[5] <= freq[5] - 1;
                                s_word <= {s_word[71:0], 8'h66};
                            end else if (freq[6] > 0) begin
                                freq[6] <= freq[6] - 1;
                                s_word <= {s_word[71:0], 8'h67};
                            end else if (freq[7] > 0) begin
                                freq[7] <= freq[7] - 1;
                                s_word <= {s_word[71:0], 8'h68};
                            end else if (freq[8] > 0) begin
                                freq[8] <= freq[8] - 1;
                                s_word <= {s_word[71:0], 8'h69};
                            end else if (freq[9] > 0) begin
                                freq[9] <= freq[9] - 1;
                                s_word <= {s_word[71:0], 8'h6a};
                            end else if (freq[10] > 0) begin
                                freq[10] <= freq[10] - 1;
                                s_word <= {s_word[71:0], 8'h6b};
                            end else if (freq[11] > 0) begin
                                freq[11] <= freq[11] - 1;
                                s_word <= {s_word[71:0], 8'h6c};
                            end else if (freq[12] > 0) begin
                                freq[12] <= freq[12] - 1;
                                s_word <= {s_word[71:0], 8'h6d};
                            end else if (freq[13] > 0) begin
                                freq[13] <= freq[13] - 1;
                                s_word <= {s_word[71:0], 8'h6e};
                            end else if (freq[14] > 0) begin
                                freq[14] <= freq[14] - 1;
                                s_word <= {s_word[71:0], 8'h6f};
                            end else if (freq[15] > 0) begin
                                freq[15] <= freq[15] - 1;
                                s_word <= {s_word[71:0], 8'h70};
                            end else if (freq[16] > 0) begin
                                freq[16] <= freq[16] - 1;
                                s_word <= {s_word[71:0], 8'h71};
                            end else if (freq[17] > 0) begin
                                freq[17] <= freq[17] - 1;
                                s_word <= {s_word[71:0], 8'h72};
                            end else if (freq[18] > 0) begin
                                freq[18] <= freq[18] - 1;
                                s_word <= {s_word[71:0], 8'h73};
                            end else if (freq[19] > 0) begin
                                freq[19] <= freq[19] - 1;
                                s_word <= {s_word[71:0], 8'h74};
                            end else if (freq[20] > 0) begin
                                freq[20] <= freq[20] - 1;
                                s_word <= {s_word[71:0], 8'h75};
                            end else if (freq[21] > 0) begin
                                freq[21] <= freq[21] - 1;
                                s_word <= {s_word[71:0], 8'h76};
                            end else if (freq[22] > 0) begin
                                freq[22] <= freq[22] - 1;
                                s_word <= {s_word[71:0], 8'h77};
                            end else if (freq[23] > 0) begin
                                freq[23] <= freq[23] - 1;
                                s_word <= {s_word[71:0], 8'h78};
                            end else if (freq[24] > 0) begin
                                freq[24] <= freq[24] - 1;
                                s_word <= {s_word[71:0], 8'h79};
                            end else if (freq[25] > 0) begin
                                freq[25] <= freq[25] - 1;
                                s_word <= {s_word[71:0], 8'h7a};
                            end

                            step <= 0;
                            turns <= turns - 1;
                        end
                    end
                end

                COMPARE: begin
                    // Check win condition
                    // Since s_word and m_word are packed MSB first, numerical comparison is lexicographical.
                    if (s_word < m_word) winnable <= 1;
                    else winnable <= 0;
                    
                    slavko_word_out <= s_word;
                    length_out <= n_chars >> 1;
                    done <= 1;
                    state <= FINISH;
                end

                FINISH: begin
                    // Done
                end
            endcase
        end
    end

endmodule