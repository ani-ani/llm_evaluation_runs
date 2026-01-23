module max_subset_sum(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] K,
    input [31:0] data_in,
    input [3:0] write_idx,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // Parameters
    parameter MOD = 32'd1000000007;
    parameter MAX_N = 16;
    
    // Memory for array values
    reg [31:0] array_reg [0:15];
    
    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD_ARRAY = 3'b001;
    localparam GENERATE_COMBOS = 3'b010;
    localparam FIND_MAX = 3'b011;
    localparam ACCUMULATE = 3'b100;
    localparam MODULO = 3'b101;
    localparam DONE = 3'b110;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [3:0] load_count;
    reg [15:0] combo_mask;  // Bitmask for current combination
    reg [31:0] accumulator;
    reg [3:0] scan_idx;     // Index for scanning selected elements
    reg [31:0] current_max; // Current maximum in the combination
    reg [31:0] temp_sum;    // Temporary sum for modulo operation
    
    // Helper variables for combination generation
    reg [4:0] ones_count;   // Count of set bits in mask
    reg [4:0] trailing_zeros;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD_ARRAY;
                else
                    next_state = IDLE;
            end
            
            LOAD_ARRAY: begin
                if (load_count == N)
                    next_state = GENERATE_COMBOS;
                else
                    next_state = LOAD_ARRAY;
            end
            
            GENERATE_COMBOS: begin
                if (combo_mask == 0 && load_count > 0) begin
                    // All combinations processed
                    next_state = DONE;
                end else begin
                    next_state = FIND_MAX;
                end
            end
            
            FIND_MAX: begin
                if (scan_idx >= N) begin
                    next_state = ACCUMULATE;
                end else begin
                    next_state = FIND_MAX;
                end
            end
            
            ACCUMULATE: begin
                next_state = MODULO;
            end
            
            MODULO: begin
                if (accumulator >= MOD)
                    next_state = MODULO;
                else
                    next_state = GENERATE_COMBOS;
            end
            
            DONE: begin
                next_state = DONE;  // Stay in DONE until reset
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output and datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            done <= 1'b0;
            busy <= 1'b0;
            result <= 32'b0;
            load_count <= 4'b0;
            combo_mask <= 16'b0;
            accumulator <= 32'b0;
            scan_idx <= 4'b0;
            current_max <= 32'b0;
            temp_sum <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    load_count <= 4'b0;
                    accumulator <= 32'b0;
                end
                
                LOAD_ARRAY: begin
                    busy <= 1'b1;
                    // Store value at specified index
                    if (load_count < N) begin
                        array_reg[write_idx] <= data_in;
                        load_count <= load_count + 1;
                    end
                    // Initialize combination mask (first combination: K ones at the end)
                    if (load_count == N - 1) begin
                        combo_mask <= (1 << K) - 1;  // K ones at LSB
                        // Track if we've generated any combinations yet
                        load_count <= load_count + 1;  // Mark as loaded
                    end
                end
                
                GENERATE_COMBOS: begin
                    // Generate next combination using Gosper's hack
                    if (combo_mask != 0 && combo_mask < (1 << N)) begin
                        // Find next combination with same number of set bits
                        // Gosper's hack:
                        // c = x & -x  (isolate lowest set bit)
                        // r = x + c   (add lowest set bit)
                        // next = (((r ^ x) >> 2) / c) | r
                        // But we need to handle the case where we exceed N bits
                        
                        // Simplified: Find next valid combination
                        // Start from current and increment, but maintain K ones
                        
                        // Use a simpler approach: generate next mask
                        reg [15:0] c;
                        reg [15:0] r;
                        reg [15:0] next_mask;
                        
                        c = combo_mask & -combo_mask;
                        r = combo_mask + c;
                        next_mask = (((r ^ combo_mask) >> 2) / c) | r;
                        
                        // Check if next_mask has more than N bits set or exceeds N bits
                        if (next_mask >= (1 << N)) begin
                            combo_mask <= 16'b0;  // Signal done
                        end else begin
                            combo_mask <= next_mask;
                        end
                        
                        // Reset scan for finding max
                        scan_idx <= 4'b0;
                        current_max <= 32'b0;
                    end else if (combo_mask == 16'b0) begin
                        // Already done or first time entering
                        if (load_count > N) begin  // We've loaded and initialized
                            combo_mask <= 16'b0;   // Signal completion
                        end
                    end
                end
                
                FIND_MAX: begin
                    // Scan through bits of combo_mask
                    if (scan_idx < N) begin
                        if (combo_mask[scan_idx]) begin
                            // This element is selected
                            if (array_reg[scan_idx] > current_max) begin
                                current_max <= array_reg[scan_idx];
                            end
                        end
                        scan_idx <= scan_idx + 1;
                    end
                end
                
                ACCUMULATE: begin
                    // Add current max to accumulator
                    temp_sum <= accumulator + current_max;
                end
                
                MODULO: begin
                    // Subtract-based modulo
                    if (temp_sum >= MOD) begin
                        temp_sum <= temp_sum - MOD;
                    end else begin
                        accumulator <= temp_sum;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    result <= accumulator;
                end
            endcase
        end
    end
    
endmodule
