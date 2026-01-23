module GemIslandSim #(
    parameter MAX_N = 8,
    parameter MAX_D = 16,
    parameter MAX_R = 8,
    parameter DATA_WIDTH = 8,
    parameter RESULT_WIDTH = 32
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input [3:0] n,
    input [7:0] d,
    input [3:0] r,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] 
        IDLE          = 4'd0,
        INIT          = 4'd1,
        SIMULATE      = 4'd2,
        WAIT_SPLIT    = 4'd3,
        SPLIT_GEMS    = 4'd4,
        SORT_PREP     = 4'd5,
        FIND_MAX      = 4'd6,
        ACCUM_MAX     = 4'd7,
        FINISH        = 4'd8;

    reg [3:0] state, next_state;
    
    // Data storage
    reg [DATA_WIDTH-1:0] counts [0:MAX_N-1];  // Gem counts
    
    // Control counters
    reg [7:0] night_counter;      // Tracks current night
    reg [3:0] inhabitant_counter; // For initialization
    reg [3:0] split_idx;          // Selected inhabitant
    reg [3:0] sort_counter;       // Tracks sorted elements
    
    // Working registers
    reg [15:0] total_gems;        // Total gems before split
    reg [15:0] cumulative_sum;    // Cumulative sum for split
    reg [7:0]  current_max;       // Current max value
    reg [3:0]  max_index;         // Index of current max
    reg [3:0]  max_search_idx;    // For max search iteration
    
    // LFSR for random number
    reg [15:0] lfsr;
    reg [15:0] rand_num;          // Generated random number
    
    integer i;  // Loop variable

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            
            // Initialize all registers
            result <= 32'd0;
            done <= 1'b0;
            night_counter <= 8'd0;
            inhabitant_counter <= 4'd0;
            split_idx <= 4'd0;
            sort_counter <= 4'd0;
            total_gems <= 16'd0;
            cumulative_sum <= 16'd0;
            current_max <= 8'd0;
            max_index <= 4'd0;
            max_search_idx <= 4'd0;
            lfsr <= 16'h0001;
            rand_num <= 16'd0;
            
            // Initialize gem counts to 0
            for (i = 0; i < MAX_N; i = i + 1) begin
                counts[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            // Default done deassertion
            if (state != FINISH) done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                INIT: begin
                    inhabitant_counter <= inhabitant_counter + 4'd1;
                    
                    // Initialize gem counts
                    for (i = 0; i < MAX_N; i = i + 1) begin
                        if (i < n) counts[i] <= 8'd1;
                        else counts[i] <= 8'd0;
                    end
                    
                    night_counter <= 8'd0;
                    next_state <= SIMULATE;
                end
                
                SIMULATE: begin
                    if (night_counter < d) begin
                        next_state <= WAIT_SPLIT;
                        // Calculate total gems: current night gems = n + night_counter
                        total_gems <= n + night_counter;
                    end else begin
                        // Done with simulation, prepare sort
                        sort_counter <= 4'd0;
                        next_state <= SORT_PREP;
                    end
                end
                
                WAIT_SPLIT: begin
                    // Generate LFSR next state
                    lfsr <= lfsr_next;
                    // Calculate random number in range (modulus operation)
                    rand_num <= rand_mod_result;
                    next_state <= SPLIT_GEMS;
                    cumulative_sum <= 16'd0;
                    split_idx <= 4'd0;
                end
                
                SPLIT_GEMS: begin
                    if (split_idx < MAX_N) begin
                        cumulative_sum <= cumulative_sum + counts[split_idx];
                        if (cumulative_sum < rand_num) begin
                            split_idx <= split_idx + 4'd1;
                            next_state <= SPLIT_GEMS;
                        end else begin
                            // Found the inhabitant to increment
                            counts[split_idx] <= counts[split_idx] + 8'd1;
                            night_counter <= night_counter + 8'd1;
                            next_state <= SIMULATE;
                        end
                    end else begin
                        // Fallback if not found (should never happen)
                        night_counter <= night_counter + 8'd1;
                        next_state <= SIMULATE;
                    end
                end
                
                SORT_PREP: begin
                    if (sort_counter < r) begin
                        // Find next max value
                        current_max <= 8'd0;
                        max_index <= 4'd0;
                        max_search_idx <= 4'd0;
                        next_state <= FIND_MAX;
                    end else begin
                        next_state <= FINISH;
                    end
                end
                
                FIND_MAX: begin
                    if (max_search_idx < MAX_N) begin
                        if (counts[max_search_idx] > current_max) begin
                            current_max <= counts[max_search_idx];
                            max_index <= max_search_idx;
                        end
                        max_search_idx <= max_search_idx + 4'd1;
                        next_state <= FIND_MAX;
                    end else begin
                        next_state <= ACCUM_MAX;
                    end
                end
                
                ACCUM_MAX: begin
                    // Add current max to result and set to zero
                    result <= result + current_max;
                    counts[max_index] <= 8'd0;
                    sort_counter <= sort_counter + 4'd1;
                    next_state <= SORT_PREP;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    // LFSR update logic
    wire [15:0] lfsr_next;
    assign lfsr_next = {lfsr[14:0], lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3]};
    
    // Random number in [1, total_gems]
    wire [15:0] rand_mod_result;
    assign rand_mod_result = (lfsr % total_gems) + 16'd1;
    
endmodule