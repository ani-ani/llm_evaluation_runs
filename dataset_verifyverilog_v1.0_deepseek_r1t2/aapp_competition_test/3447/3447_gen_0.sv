module t9_keypress #(
    parameter DICT_SIZE = 8,
    parameter MAX_WORD_LEN = 8,
    parameter MAX_QUERY_LEN = 16
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] dict_words [0:DICT_SIZE-1][0:MAX_WORD_LEN-1],
    input wire [3:0] dict_lengths [0:DICT_SIZE-1],
    input wire [7:0] query_word [0:MAX_QUERY_LEN-1],
    input wire [4:0] query_length,
    output reg [7:0] key_sequence [0:255],
    output reg [7:0] key_count,
    output reg done
);

// State declarations with explicit widths
localparam [2:0] IDLE          = 3'd0;
localparam [2:0] COMPUTE_COSTS = 3'd1;
localparam [2:0] DP_COMPUTE    = 3'd2;
localparam [2:0] BACKTRACK     = 3'd3;
localparam [2:0] OUTPUT        = 3'd4;

reg [2:0] state, next_state;

// T9 mapping lookup function
function automatic [3:0] char_to_digit(input [7:0] c);
    case (c)
        "a", "b", "c": char_to_digit = 4'd2;
        "d", "e", "f": char_to_digit = 4'd3;
        "g", "h", "i": char_to_digit = 4'd4;
        "j", "k", "l": char_to_digit = 4'd5;
        "m", "n", "o": char_to_digit = 4'd6;
        "p", "q", "r", "s": char_to_digit = 4'd7;
        "t", "u", "v": char_to_digit = 4'd8;
        "w", "x", "y", "z": char_to_digit = 4'd9;
        default: char_to_digit = 4'd0;
    endcase
endfunction

// DP arrays
reg [31:0] dp [0:MAX_QUERY_LEN];
reg [31:0] dp_prev [0:MAX_QUERY_LEN];
reg [31:0] dp_word_idx [0:Max_QUERY_LEN];
reg [31:0] dp_cycle_cost [0:MAX_QUERY_LEN];

// Word properties
reg [31:0] word_costs [0:DICT_SIZE-1];
reg [3:0] word_digit_seqs [0:DICT_SIZE-1][0:MAX_WORD_LEN-1];

// Counters and temporary registers
integer i, j, k;  // Size automatically handled
reg [31:0] min_cost, current_cost;
reg [31:0] backtrack_idx;
reg [7:0] output_idx;
reg [7:0] temp_key;
reg [7:0] out_buf [0:255];
reg [7:0] out_len;
reg [7:0] cycle_counter;  // Prevents infinite loops

// DP array initialization loop variables
integer init_i, init_j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialize ALL registers
        state <= IDLE;
        done <= 1'b0;
        key_count <= 8'd0;
        out_len <= 8'd0;
        cycle_counter <= 8'd0;
        
        // Initialize DP arrays
        for (init_i = 0; init_i <= MAX_QUERY_LEN; init_i = init_i + 1) begin
            dp[init_i] <= 32'd9999;  // High initial cost
            dp_prev[init_i] <= 32'd0;
            dp_word_idx[init_i] <= 32'd0;
            dp_cycle_cost[init_i] <= 32'd0;
        end
        dp[0] <= 32'd0;  // Starting condition
        
        // Initialize word properties
        for (init_i = 0; init_i < DICT_SIZE; init_i = init_i + 1) begin
            word_costs[init_i] <= 32'd0;
            for (init_j = 0; init_j < MAX_WORD_LEN; init_j = init_j + 1) begin
                word_digit_seqs[init_i][init_j] <= 4'd0;
            end
        end
        
        // Initialize output buffers
        for (init_i = 0; init_i < 256; init_i = init_i + 1) begin
            key_sequence[init_i] <= 8'd0;
            out_buf[init_i] <= 8'd0;
        end
        
        i <= 0;
        j <= 0;
        k <= 0;
        min_cost <= 32'd0;
        current_cost <= 32'd0;
        backtrack_idx <= 32'd0;
        output_idx <= 8'd0;
        temp_key <= 8'd0;
    end else begin
        cycle_count <= cycle_counter + 8'd1;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Initialize only critical variables on start
                    state <= COMPUTE_COSTS;
                    i <= 0;
                    j <= 0;
                    cycle_counter <= 8'd0;
                end
            end
            
            COMPUTE_COSTS: begin
                if (cycle_counter > 1000) begin  // Timeout protection
                    state <= IDLE;
                    done <= 1'b1;
                end else if (i < DICT_SIZE) begin
                    if (j < dict_lengths[i]) begin
                        word_digit_seqs[i][j] <= char_to_digit(dict_words[i][j]);
                        j <= j + 1;
                    end else begin
                        word_costs[i] <= dict_lengths[i];
                        i <= i + 1;
                        j <= 0;
                        if (i == DICT_SIZE - 1) begin
                            state <= DP_COMPUTE;
                            i <= 0;
                            j <= 0;
                        end
                    end
                end
            end
            
            DP_COMPUTE: begin
                if (cycle_counter > 2000) begin
                    state <= IDLE;
                    done <= 1'b1;
                end else if (i <= query_length) begin
                    if (j < DICT_SIZE) begin
                        if (i + dict_lengths[j] <= query_length) begin
                            current_cost = dp[i] + word_costs[j];
                            if (i > 0) current_cost = current_cost + 32'd1;
                            
                            if (current_cost < dp[i + dict_lengths[j]]) begin
                                dp[i + dict_lengths[j]] <= current_cost;
                                dp_prev[i + dict_lengths[j]] <= i;
                                dp_word_idx[i + dict_lengths[j]] <= j;
                            end
                        end
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        i <= i + 1;
                    end
                end else begin
                    state <= BACKTRACK;
                    backtrack_idx <= query_length;
                    out_len <= 8'd0;
                end
            end
            
            BACKTRACK: begin
                if (backtrack_idx > 0) begin
                    if (out_len < 250) begin
                        if (dp_prev[backtrack_idx] > 0) begin
                            out_buf[out_len] <= "R";
                            out_len <= out_len + 8'd1;
                        end
                        
                        j <= dict_lengths[dp_word_idx[backtrack_idx]] - 1;
                        while (j >= 0 && out_len < 250) begin
                            temp_key = word_digit_seqs[dp_word_idx[backtrack_idx]][j] + 8'h30;
                            out_buf[out_len] <= temp_key;
                            out_len <= out_len + 8'd1;
                            j <= j - 1;
                        end
                        
                        backtrack_idx <= dp_prev[backtrack_idx];
                    end else begin
                        state <= OUTPUT;
                        output_idx <= 8'd0;
                    end
                end else begin
                    state <= OUTPUT;
                    output_idx <= 8'd0;
                end
            end
            
            OUTPUT: begin
                if (output_idx < out_len) begin
                    key_sequence[output_idx] <= out_buf[output_idx];
                    output_idx <= output_idx + 8'd1;
                    key_count <= out_len;
                end else begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule