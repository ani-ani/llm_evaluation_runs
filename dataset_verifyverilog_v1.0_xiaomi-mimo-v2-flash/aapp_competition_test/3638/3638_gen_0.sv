module ProbabilityPredictor (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [19:0] n,
    input wire [3:0] len,
    input wire [29:0] seq_0,
    input wire [29:0] seq_1,
    input wire [29:0] seq_2,
    input wire [29:0] seq_3,
    input wire [29:0] seq_4,
    input wire [29:0] seq_5,
    input wire [29:0] seq_6,
    input wire [29:0] seq_7,
    input wire [29:0] seq_8,
    input wire [29:0] seq_9,
    output reg [3:0] result_idx,
    output reg valid,
    output reg done
);

    // --- Parameters & Constants ---
    localparam [31:0] ONE_FIXED = 32'h00010000;      // 1.0 in Q16.16
    localparam [31:0] INV3_FIXED = 32'h00005555;     // 1/3 in Q16.16 (approx 21845)
    localparam [31:0] ONE_MINUS_INV3 = 32'h0000AAAA; // 2/3 in Q16.16 (approx 43690)
    localparam [7:0] MAX_SEQ_LEN = 8'd10;
    localparam [7:0] MAX_S = 8'd10;
    localparam [7:0] MAX_CYCLES = 8'd200;           // Bound for computation
    
    // --- State Declarations ---
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] CALC_PROB_L    = 3'd1;  // Calculate (1/3)^L
    localparam [2:0] CALC_EXPONENT  = 3'd2;  // Calculate exponent (n - L + 1)
    localparam [2:0] CALC_RESULT    = 3'd3;  // Compute 1 - (1-P)^exponent
    localparam [2:0] STORE_RESULT   = 3'd4;  // Store in array
    localparam [2:0] SORT_START     = 3'd5;  // Initiate sort
    localparam [2:0] OUTPUT_RESULTS = 3'd6;  // Output sorted indices
    localparam [2:0] FINISH         = 3'd7;

    // --- Registers & Wires ---
    reg [2:0] state, next_state;
    reg [7:0] cycle_counter;
    
    // Control Registers
    reg [3:0] seq_idx;                 // Current sequence index (0-9)
    reg [3:0] s_count;                 // Total valid sequences (parsed from inputs)
    reg [31:0] prob_array [0:9];       // Storing computed probabilities
    reg [3:0] index_array [0:9];       // Storing original indices for sorting
    
    // Calculation Registers
    reg [31:0] prob_L_reg;             // (1/3)^L
    reg [31:0] prob_survival_reg;      // 1 - (1/3)^L
    reg [19:0] exponent_val;           // n - L + 1
    reg [31:0] base_reg;               // Base for exponentiation
    reg [31:0] result_reg;             // Current computed probability
    reg [19:0] loop_counter;           // For iterative exponentiation
    
    // Sorting State
    reg [3:0] sort_i, sort_j;          // Bubble sort indices
    reg sort_done_flag;
    reg [3:0] temp_idx;
    reg [31:0] temp_prob;
    
    // --- Helper Logic: Count Valid Sequences ---
    wire [3:0] valid_s;
    assign valid_s = (seq_9 != 30'd0) ? 4'd10 : 
                     (seq_8 != 30'd0) ? 4'd9 : 
                     (seq_7 != 30'd0) ? 4'd8 : 
                     (seq_6 != 30'd0) ? 4'd7 : 
                     (seq_5 != 30'd0) ? 4'd6 : 
                     (seq_4 != 30'd0) ? 4'd5 : 
                     (seq_3 != 30'd0) ? 4'd4 : 
                     (seq_2 != 30'd0) ? 4'd3 : 
                     (seq_1 != 30'd0) ? 4'd2 : 
                     (seq_0 != 30'd0) ? 4'd1 : 4'd0;

    // --- State Transition ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_counter <= 8'd0;
            seq_idx <= 4'd0;
            s_count <= 4'd0;
            prob_L_reg <= 32'd0;
            prob_survival_reg <= 32'd0;
            exponent_val <= 20'd0;
            base_reg <= 32'd0;
            result_reg <= 32'd0;
            loop_counter <= 20'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            sort_done_flag <= 1'b0;
            result_idx <= 4'd0;
            valid <= 1'b0;
            done <= 1'b0;
            // Initialize arrays
            for (int i = 0; i < 10; i = i + 1) begin
                prob_array[i] <= 32'd0;
                index_array[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    seq_idx <= 4'd0;
                    if (start) begin
                        s_count <= valid_s;
                    end
                end

                CALC_PROB_L: begin
                    // Calculate (1/3)^L iteratively
                    // Start with 1.0, multiply by INV3_FIXED 'len' times
                    if (cycle_counter == 8'd0) begin
                        prob_L_reg <= ONE_FIXED;
                    end else if (cycle_counter < len) begin
                        // prob_L_reg = prob_L_reg * INV3_FIXED >> 16 (Q16.16 mult)
                        prob_L_reg <= prob_L_reg[31:0] * INV3_FIXED[31:0] >> 16;
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                end

                CALC_EXPONENT: begin
                    // exponent = n - len + 1
                    exponent_val <= n - {16'd0, len} + 20'd1;
                    // prob_survival = 1 - prob_L
                    prob_survival_reg <= ONE_FIXED - prob_L_reg;
                    cycle_counter <= 8'd0;
                    // Initialize base for exponentiation
                    base_reg <= prob_survival_reg;
                    result_reg <= ONE_FIXED; // Start with 1.0
                end

                CALC_RESULT: begin
                    // Compute P = 1 - (1-P_L)^exponent
                    // Binary exponentiation or iterative multiply
                    // P_survival^n = result_reg
                    
                    if (cycle_counter < 20'd20) begin // Unroll/Iterate up to 20 bits of exponent
                        if (exponent_val[0]) begin
                            result_reg <= result_reg[31:0] * base_reg[31:0] >> 16;
                        end
                        exponent_val <= exponent_val >> 1;
                        base_reg <= base_reg[31:0] * base_reg[31:0] >> 16;
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Final result adjustment: 1 - survival_power
                    if (cycle_counter == 8'd20) begin
                        result_reg <= ONE_FIXED - result_reg;
                    end
                end

                STORE_RESULT: begin
                    prob_array[seq_idx] <= result_reg;
                    index_array[seq_idx] <= seq_idx;
                    seq_idx <= seq_idx + 4'd1;
                end

                SORT_START: begin
                    // Bubble Sort Initialization
                    sort_i <= 4'd0;
                    sort_j <= 4'd0;
                    sort_done_flag <= 1'b0;
                end

                OUTPUT_RESULTS: begin
                    // Output one result per cycle
                    valid <= 1'b1;
                    result_idx <= index_array[result_idx];
                    result_idx <= result_idx + 4'd1; // Increment output counter
                    if (result_idx >= s_count - 4'd1) begin
                        done <= 1'b1;
                        valid <= 1'b0;
                    end
                end
                
                FINISH: begin
                    // Wait state
                end
            endcase
        end
    end

    // --- Next State Logic ---
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && s_count > 4'd0) next_state = CALC_PROB_L;
                else next_state = IDLE;
            end
            
            CALC_PROB_L: begin
                // Wait for 'len' cycles
                if (cycle_counter >= len && len != 4'd0) next_state = CALC_EXPONENT;
                else if (len == 4'd0) next_state = CALC_EXPONENT; // Edge case
                else next_state = CALC_PROB_L;
            end

            CALC_EXPONENT: begin
                next_state = CALC_RESULT;
            end

            CALC_RESULT: begin
                // Approx 20 cycles for exponentiation
                if (cycle_counter > 8'd20) next_state = STORE_RESULT;
                else next_state = CALC_RESULT;
            end

            STORE_RESULT: begin
                if (seq_idx < s_count) next_state = CALC_PROB_L; // Process next seq
                else next_state = SORT_START;
            end

            SORT_START: begin
                // Execute bubble sort logic in combinational block or sequential
                // For determinism in sequential logic:
                // Simple sort: Iterate through array, swap if needed
                // We'll use the cycle counter to track sort steps or implement a flag
                if (sort_done_flag) next_state = OUTPUT_RESULTS;
                else next_state = SORT_START; // Keep in this state until sorted
            end

            OUTPUT_RESULTS: begin
                if (result_idx >= s_count && !done) next_state = FINISH; // Finished output
                else next_state = OUTPUT_RESULTS;
            end

            FINISH: next_state = FINISH;
            
            default: next_state = IDLE;
        endcase
    end

    // --- Combinational Bubble Sort Logic ---
    // Runs when in SORT_START state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            sort_done_flag <= 1'b0;
        end else if (state == SORT_START) begin
            if (!sort_done_flag) begin
                if (sort_j < s_count - 4'd1) begin
                    // Compare and Swap
                    if (prob_array[sort_j] < prob_array[sort_j + 4'd1]) begin
                        // Swap Probabilities
                        temp_prob <= prob_array[sort_j];
                        prob_array[sort_j] <= prob_array[sort_j + 4'd1];
                        prob_array[sort_j + 4'd1] <= temp_prob;
                        // Swap Indices
                        temp_idx <= index_array[sort_j];
                        index_array[sort_j] <= index_array[sort_j + 4'd1];
                        index_array[sort_j + 4'd1] <= temp_idx;
                    end
                    sort_j <= sort_j + 4'd1;
                end else begin
                    sort_j <= 4'd0;
                    sort_i <= sort_i + 4'd1;
                    if (sort_i >= s_count - 4'd2) begin
                        sort_done_flag <= 1'b1;
                    end
                end
            end
        end
    end

endmodule