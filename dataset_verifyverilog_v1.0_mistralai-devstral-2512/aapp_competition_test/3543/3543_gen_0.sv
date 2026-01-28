module KeystrokeCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] dict_word_addr [0:15],
    input wire [7:0] dict_word [0:15],
    input wire [4:0] target_len,
    input wire [7:0] target_word [0:15],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Internal registers
    reg [15:0] min_keystrokes;
    reg [15:0] current_cost;
    reg [4:0] l_counter;
    reg [4:0] word_counter;
    reg [4:0] dict_word_len;
    reg [7:0] dict_char;
    reg [7:0] target_char;
    reg prefix_match;
    reg [15:0] word_keystrokes;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            min_keystrokes <= 16'd0;
            l_counter <= 5'd0;
            word_counter <= 5'd0;
            prefix_match <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        min_keystrokes <= target_len + 16'd1; // Initialize with no-autocorrect cost
                        l_counter <= 5'd0;
                        word_counter <= 5'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Reset prefix match for new L
                    if (l_counter == 5'd0 && word_counter == 5'd0) begin
                        prefix_match <= 1'b1; // Start with match true
                    end
                    
                    // Check if current prefix matches
                    if (prefix_match) begin
                        dict_char <= dict_word[word_counter][l_counter];
                        target_char <= target_word[l_counter];
                        
                        if (dict_char != target_char) begin
                            prefix_match <= 1'b0;
                        end
                    end
                    
                    // Calculate word length
                    if (dict_word[word_counter][l_counter] == 8'd0) begin
                        dict_word_len <= l_counter;
                    end else if (l_counter == 5'd15) begin
                        dict_word_len <= 5'd16;
                    end
                    
                    // Compute cost for this word and prefix length
                    if (prefix_match && (dict_word[word_counter][l_counter] == 8'd0 || l_counter == 5'd15)) begin
                        word_keystrokes <= target_len + 16'd1 + dict_word_len - (l_counter << 1);
                        
                        if (word_keystrokes < min_keystrokes) begin
                            min_keystrokes <= word_keystrokes;
                        end
                    end
                    
                    // Move to next word or next L
                    if (word_counter == 5'd15) begin
                        word_counter <= 5'd0;
                        prefix_match <= 1'b1;
                        
                        if (l_counter == target_len) begin
                            state <= FINISH;
                        end else begin
                            l_counter <= l_counter + 5'd1;
                        end
                    end else begin
                        word_counter <= word_counter + 5'd1;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= min_keystrokes;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule