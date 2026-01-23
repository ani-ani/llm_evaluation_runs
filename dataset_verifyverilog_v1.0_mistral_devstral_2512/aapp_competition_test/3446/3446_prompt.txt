module optimal_assembly (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Configuration: symbols (8 characters, each 8 bits)
    input wire [7:0] symbol_in [0:7],
    
    // Configuration: time table (8x8, each 32 bits)
    input wire [31:0] time_table_in [0:7][0:7],
    
    // Configuration: result table (8x8, each 8 bits, representing symbol index)
    input wire [7:0] result_table_in [0:7][0:7],
    
    // String to assemble: 10 symbols, each 8 bits (indices)
    input wire [7:0] string_in [0:9],
    input wire [3:0] length_in,
    
    // Output
    output reg [31:0] result_time,
    output reg [7:0] result_symbol,
    output reg done
);

// Parameters
parameter NUM_SYMBOLS = 8;
parameter MAX_LENGTH = 10;
parameter INF = 32'hFFFFFFFF;

// State definitions
localparam S_IDLE = 0;
localparam S_INIT_ALL = 1;
localparam S_INIT_DIAG = 2;
localparam S_COMP_READ = 3;
localparam S_COMP_WRITE = 4;
localparam S_FIND_BEST = 5;
localparam S_OUTPUT = 6;

// Registers for state and counters
reg [2:0] state;
reg [2:0] next_state;

reg [3:0] init_i, init_j, init_t;  // for initialization
reg [3:0] comp_length, comp_start, comp_split, comp_left, comp_right; // for computation
reg [31:0] dp_left_val, dp_right_val; // stored read values

// DP table
reg [31:0] dp [0:MAX_LENGTH-1][0:MAX_LENGTH-1][0:NUM_SYMBOLS-1];

// Latched configuration and string
reg [7:0] latch_symbol [0:7];
reg [31:0] latch_time_table [0:7][0:7];
reg [7:0] latch_result_table [0:7][0:7];
reg [7:0] latch_string [0:9];
reg [3:0] latch_length;

// Combinational next state logic
always @(*) begin
    case (state)
        S_IDLE: 
            if (start) 
                next_state = S_INIT_ALL;
            else 
                next_state = S_IDLE;
        S_INIT_ALL: 
            if (init_i == MAX_LENGTH-1 && init_j == MAX_LENGTH-1 && init_t == NUM_SYMBOLS-1)
                next_state = S_INIT_DIAG;
            else
                next_state = S_INIT_ALL;
        S_INIT_DIAG: 
            if (init_i == latch_length - 1 && init_t == NUM_SYMBOLS-1)
                if (latch_length == 1)
                    next_state = S_FIND_BEST;
                else
                    next_state = S_COMP_READ;
            else
                next_state = S_INIT_DIAG;
        S_COMP_READ: 
            next_state = S_COMP_WRITE;
        S_COMP_WRITE: 
            // After writing, increment counters and decide next state
            if (comp_right < NUM_SYMBOLS-1)
                next_state = S_COMP_READ;
            else if (comp_left < NUM_SYMBOLS-1)
                next_state = S_COMP_READ;
            else if (comp_split < comp_start + comp_length - 2)
                next_state = S_COMP_READ;
            else if (comp_start < latch_length - comp_length)
                next_state = S_COMP_READ;
            else if (comp_length < latch_length)
                next_state = S_COMP_READ;
            else
                next_state = S_FIND_BEST;
        S_FIND_BEST: 
            if (init_t == NUM_SYMBOLS-1)
                next_state = S_OUTPUT;
            else
                next_state = S_FIND_BEST;
        S_OUTPUT: 
            next_state = S_IDLE;
        default: next_state = S_IDLE;
    endcase
end

// Sequential state and counters update
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        // Reset counters
        init_i <= 0;
        init_j <= 0;
        init_t <= 0;
        comp_length <= 0;
        comp_start <= 0;
        comp_split <= 0;
        comp_left <= 0;
        comp_right <= 0;
        done <= 0;
        result_time <= 0;
        result_symbol <= 0;
    end else begin
        state <= next_state;
        
        case (state)
            S_IDLE: begin
                done <= 0;
                if (start) begin
                    // Latch configuration and string
                    latch_symbol <= symbol_in;
                    latch_time_table <= time_table_in;
                    latch_result_table <= result_table_in;
                    latch_string <= string_in;
                    latch_length <= length_in;
                    // Reset counters
                    init_i <= 0;
                    init_j <= 0;
                    init_t <= 0;
                    comp_length <= 2; // Will be used only if length>=2
                    comp_start <= 0;
                    comp_split <= 0;
                    comp_left <= 0;
                    comp_right <= 0;
                end
            end
            
            S_INIT_ALL: begin
                // Initialize all DP entries to INF
                dp[init_i][init_j][init_t] <= INF;
                // Increment counters
                if (init_t < NUM_SYMBOLS-1) begin
                    init_t <= init_t + 1;
                end else begin
                    init_t <= 0;
                    if (init_j < MAX_LENGTH-1) begin
                        init_j <= init_j + 1;
                    end else begin
                        init_j <= 0;
                        if (init_i < MAX_LENGTH-1) begin
                            init_i <= init_i + 1;
                        end else begin
                            init_i <= 0;
                        end
                    end
                end
            end
            
            S_INIT_DIAG: begin
                // Initialize diagonal for the string
                if (latch_string[init_i] == init_t) 
                    dp[init_i][init_i][init_t] <= 0;
                else
                    dp[init_i][init_i][init_t] <= INF;
                
                // Increment counters
                if (init_t < NUM_SYMBOLS-1) begin
                    init_t <= init_t + 1;
                end else begin
                    init_t <= 0;
                    if (init_i < latch_length - 1) begin
                        init_i <= init_i + 1;
                    end else begin
                        init_i <= 0;
                    end
                end
            end
            
            S_COMP_READ: begin
                // Read dp_left and dp_right
                dp_left_val <= dp[comp_start][comp_split][comp_left];
                dp_right_val <= dp[comp_split+1][comp_start+comp_length-1][comp_right];
            end
            
            S_COMP_WRITE: begin
                // Compute and write if both values are not INF
                if (dp_left_val != INF && dp_right_val != INF) begin
                    // Compute time
                    reg [31:0] time_val = dp_left_val + dp_right_val + latch_time_table[comp_left][comp_right];
                    reg [7:0] result_idx = latch_result_table[comp_left][comp_right];
                    // Update dp for the combined interval
                    if (time_val < dp[comp_start][comp_start+comp_length-1][result_idx])
                        dp[comp_start][comp_start+comp_length-1][result_idx] <= time_val;
                end
                
                // Increment counters
                if (comp_right < NUM_SYMBOLS-1) begin
                    comp_right <= comp_right + 1;
                end else begin
                    comp_right <= 0;
                    if (comp_left < NUM_SYMBOLS-1) begin
                        comp_left <= comp_left + 1;
                    end else begin
                        comp_left <= 0;
                        if (comp_split < comp_start + comp_length - 2) begin
                            comp_split <= comp_split + 1;
                        end else begin
                            comp_split <= comp_start;
                            if (comp_start < latch_length - comp_length) begin
                                comp_start <= comp_start + 1;
                            end else begin
                                comp_start <= 0;
                                if (comp_length < latch_length) begin
                                    comp_length <= comp_length + 1;
                                end else begin
                                    comp_length <= 0;
                                end
                            end
                        end
                    end
                end
            end
            
            S_FIND_BEST: begin
                // Find the best result for the whole string
                // We use init_t as the symbol index
                if (init_t == 0) begin
                    // First symbol, initialize best
                    result_time <= dp[0][latch_length-1][0];
                    result_symbol <= latch_symbol[0];
                end else begin
                    if (dp[0][latch_length-1][init_t] < result_time) begin
                        result_time <= dp[0][latch_length-1][init_t];
                        result_symbol <= latch_symbol[init_t];
                    end
                end
                init_t <= init_t + 1;
            end
            
            S_OUTPUT: begin
                done <= 1;
                // result_time and result_symbol are already set
                // Reset counters for next use
                init_t <= 0;
            end
            
        endcase
    end
end

endmodule