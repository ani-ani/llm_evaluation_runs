module pattern_sorter #(
    parameter NUM_PATTERNS = 4,
    parameter PATTERN_LENGTH = 8,
    parameter DATA_WIDTH = 2,
    parameter SCORE_WIDTH = 8,
    parameter N_WIDTH = 20
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [N_WIDTH-1:0] n,
    input wire [DATA_WIDTH*PATTERN_LENGTH-1:0] patterns_in [0:NUM_PATTERNS-1],
    output reg done,
    output reg [DATA_WIDTH*PATTERN_LENGTH-1:0] patterns_out [0:NUM_PATTERNS-1]
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD = 4'd1;
    localparam [3:0] COMPUTE_BORDER = 4'd2;
    localparam [3:0] SUM_BORDERS = 4'd3;
    localparam [3:0] STORE_SCORE = 4'd4;
    localparam [3:0] SORT = 4'd5;
    localparam [3:0] SWAP = 4'd6;
    localparam [3:0] FINISH = 4'd7;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] counter;
    reg [7:0] pat_idx;
    reg [7:0] char_idx;
    reg [7:0] border_idx;
    reg [7:0] i_reg;
    reg [7:0] j_reg;
    reg [7:0] temp_score;
    reg [7:0] swap_idx;
    reg [7:0] sort_pass;
    
    // Storage arrays
    reg [DATA_WIDTH*PATTERN_LENGTH-1:0] pat_reg [0:NUM_PATTERNS-1];
    reg [SCORE_WIDTH-1:0] scores [0:NUM_PATTERNS-1];
    reg [SCORE_WIDTH-1:0] pi [0:PATTERN_LENGTH-1];  // KMP prefix function
    reg [DATA_WIDTH-1:0] current_pattern [0:PATTERN_LENGTH-1];
    reg [DATA_WIDTH*PATTERN_LENGTH-1:0] temp_pat;
    reg [SCORE_WIDTH-1:0] temp_score_reg;
    
    // Helper signals
    reg [7:0] i, k;
    reg [DATA_WIDTH-1:0] current_char;
    reg [DATA_WIDTH-1:0] char_at_k;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            counter <= 8'd0;
            pat_idx <= 8'd0;
            char_idx <= 8'd0;
            border_idx <= 8'd0;
            i_reg <= 8'd0;
            j_reg <= 8'd0;
            temp_score <= 8'd0;
            swap_idx <= 8'd0;
            sort_pass <= 8'd0;
            temp_score_reg <= 8'd0;
            temp_pat <= 0;
            current_char <= 2'd0;
            char_at_k <= 2'd0;
            
            // Initialize arrays
            for (i = 0; i < NUM_PATTERNS; i = i + 1) begin
                pat_reg[i] <= 0;
                scores[i] <= 0;
                patterns_out[i] <= 0;
            end
            for (k = 0; k < PATTERN_LENGTH; k = k + 1) begin
                pi[k] <= 0;
                current_pattern[k] <= 0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 8'd0;
                    pat_idx <= 8'd0;
                    char_idx <= 8'd0;
                    border_idx <= 8'd0;
                    i_reg <= 8'd0;
                    j_reg <= 8'd0;
                    temp_score <= 8'd0;
                    swap_idx <= 8'd0;
                    sort_pass <= 8'd0;
                    temp_score_reg <= 8'd0;
                    temp_pat <= 0;
                    current_char <= 2'd0;
                    char_at_k <= 2'd0;
                    
                    // Initialize arrays
                    for (i = 0; i < NUM_PATTERNS; i = i + 1) begin
                        pat_reg[i] <= 0;
                        scores[i] <= 0;
                        patterns_out[i] <= 0;
                    end
                    for (k = 0; k < PATTERN_LENGTH; k = k + 1) begin
                        pi[k] <= 0;
                        current_pattern[k] <= 2'd0;
                    end
                end
                
                LOAD: begin
                    // Load pattern from input array
                    pat_reg[pat_idx] <= patterns_in[pat_idx];
                    // Extract individual characters
                    for (k = 0; k < PATTERN_LENGTH; k = k + 1) begin
                        current_pattern[k] <= patterns_in[pat_idx][DATA_WIDTH*k+:DATA_WIDTH];
                    end
                end
                
                COMPUTE_BORDER: begin
                    // KMP prefix function computation
                    if (char_idx == 0) begin
                        pi[0] <= 0;
                        i_reg <= 8'd1;
                        j_reg <= 8'd0;
                    end else if (i_reg < PATTERN_LENGTH) begin
                        current_char <= current_pattern[i_reg];
                        char_at_k <= current_pattern[j_reg];
                        
                        if (j_reg > 0 && current_char != char_at_k) begin
                            j_reg <= pi[j_reg-1];
                        end else if (current_char == char_at_k) begin
                            j_reg <= j_reg + 8'd1;
                        end
                        
                        pi[i_reg] <= j_reg;
                        i_reg <= i_reg + 8'd1;
                    end
                end
                
                SUM_BORDERS: begin
                    // Sum lengths of all proper borders
                    if (border_idx < PATTERN_LENGTH) begin
                        temp_score <= temp_score + pi[border_idx];
                        border_idx <= border_idx + 8'd1;
                    end
                end
                
                STORE_SCORE: begin
                    scores[pat_idx] <= temp_score;
                    temp_score <= 8'd0;
                end
                
                SORT: begin
                    // Bubble sort pass
                    if (swap_idx < NUM_PATTERNS - sort_pass - 1) begin
                        if (scores[swap_idx] > scores[swap_idx + 1]) begin
                            temp_score_reg <= scores[swap_idx];
                            temp_pat <= pat_reg[swap_idx];
                            swap_idx <= swap_idx + 8'd1;
                        end else begin
                            swap_idx <= swap_idx + 8'd1;
                        end
                    end else begin
                        swap_idx <= 8'd0;
                        sort_pass <= sort_pass + 8'd1;
                    end
                end
                
                SWAP: begin
                    // Perform swap
                    scores[swap_idx] <= scores[swap_idx + 1];
                    scores[swap_idx + 1] <= temp_score_reg;
                    pat_reg[swap_idx] <= pat_reg[swap_idx + 1];
                    pat_reg[swap_idx + 1] <= temp_pat;
                end
                
                FINISH: begin
                    // Output sorted patterns
                    for (k = 0; k < NUM_PATTERNS; k = k + 1) begin
                        patterns_out[k] <= pat_reg[k];
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            
            LOAD: begin
                next_state = COMPUTE_BORDER;
            end
            
            COMPUTE_BORDER: begin
                if (i_reg >= PATTERN_LENGTH) next_state = SUM_BORDERS;
            end
            
            SUM_BORDERS: begin
                if (border_idx >= PATTERN_LENGTH) next_state = STORE_SCORE;
            end
            
            STORE_SCORE: begin
                if (pat_idx < NUM_PATTERNS - 1) begin
                    next_state = LOAD;
                end else begin
                    next_state = SORT;
                end
            end
            
            SORT: begin
                if (swap_idx < NUM_PATTERNS - sort_pass - 1) begin
                    if (scores[swap_idx] > scores[swap_idx + 1]) begin
                        next_state = SWAP;
                    end
                end else if (sort_pass < NUM_PATTERNS - 1) begin
                    next_state = SORT;
                end else begin
                    next_state = FINISH;
                end
            end
            
            SWAP: begin
                next_state = SORT;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Update indices
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pat_idx <= 8'd0;
            char_idx <= 8'd0;
            border_idx <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    pat_idx <= 8'd0;
                    char_idx <= 8'd0;
                    border_idx <= 8'd0;
                end
                STORE_SCORE: begin
                    if (pat_idx < NUM_PATTERNS - 1) begin
                        pat_idx <= pat_idx + 8'd1;
                    end
                    char_idx <= 8'd0;
                    border_idx <= 8'd0;
                end
                COMPUTE_BORDER: begin
                    char_idx <= char_idx + 8'd1;
                end
                default: begin
                    // Keep indices
                end
            endcase
        end
    end

endmodule