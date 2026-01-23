module camel_race_bets (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [4:0] a [0:31],
    input [4:0] b [0:31],
    input [4:0] c [0:31],
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SETUP = 2'b01;
    localparam CHECK_PAIRS = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state, next_state;
    
    // Index registers
    reg [4:0] i, next_i; // Camel i (1 to n-1)
    reg [4:0] j, next_j; // Camel j (i+1 to n)
    
    // Counter
    reg [31:0] count, next_count;
    
    // Lookup tables: camel -> position
    reg [4:0] pos_a [0:31];
    reg [4:0] pos_b [0:31];
    reg [4:0] pos_c [0:31];
    
    // Setup index for building lookup tables
    reg [4:0] setup_idx, next_setup_idx;
    
    // Combinational logic for checking pair consistency
    wire pair_consistent;
    assign pair_consistent = (pos_a[i] < pos_a[j]) && 
                             (pos_b[i] < pos_b[j]) && 
                             (pos_c[i] < pos_c[j]);

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 5'd0;
            j <= 5'd0;
            count <= 32'd0;
            setup_idx <= 5'd0;
        end else begin
            state <= next_state;
            i <= next_i;
            j <= next_j;
            count <= next_count;
            setup_idx <= next_setup_idx;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_i = i;
        next_j = j;
        next_count = count;
        next_setup_idx = setup_idx;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SETUP;
                    next_setup_idx = 5'd0;
                    next_count = 32'd0;
                end
            end
            
            SETUP: begin
                // Build position lookup tables
                // Takes 32 cycles
                if (setup_idx < 5'd31 && setup_idx < n) begin
                    next_setup_idx = setup_idx + 5'd1;
                end else begin
                    next_state = CHECK_PAIRS;
                    next_i = 5'd1; // Start from camel 1
                    next_j = 5'd2; // Start from camel 2
                end
            end
            
            CHECK_PAIRS: begin
                if (i < n) begin
                    if (j < n) begin
                        // Check current pair
                        if (pair_consistent) begin
                            next_count = count + 32'd1;
                        end
                        next_j = j + 5'd1;
                    end else begin
                        // Inner loop done, move to next i
                        next_i = i + 5'd1;
                        next_j = i + 5'd2; // j starts at i+1
                    end
                end else begin
                    // All pairs processed
                    next_state = DONE;
                end
            end
            
            DONE: begin
                // Wait for next start or reset
                if (start) begin
                    next_state = SETUP;
                    next_setup_idx = 5'd0;
                    next_count = 32'd0;
                    next_i = 5'd0;
                    next_j = 5'd0;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            if (state == SETUP && next_state == CHECK_PAIRS) begin
                // Initialize lookup tables during setup
                // Synthesis will infer proper initialization
                // For dynamic initialization, we need combinational lookup
            end
            
            if (state == CHECK_PAIRS && next_state == DONE) begin
                result <= next_count;
                done <= 1'b1;
            end else if (state == DONE && next_state != DONE && next_state != IDLE) begin
                done <= 1'b0;
            end else if (state == IDLE && next_state == SETUP) begin
                done <= 1'b0;
            end
        end
    end

    // Lookup table update logic (combinational for dynamic indexing)
    // We need to populate pos_a, pos_b, pos_c based on input arrays
    integer idx;
    always @(*) begin
        // Default: maintain values
        // This will be resolved in synthesis
    end
    
    // Combinational lookup table construction
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Clear tables
            for (idx = 0; idx < 32; idx = idx + 1) begin
                pos_a[idx] <= 5'd0;
                pos_b[idx] <= 5'd0;
                pos_c[idx] <= 5'd0;
            end
        end else if (state == SETUP) begin
            // Populate tables based on position index
            // Input a[p] gives camel at position p
            // We need camel -> position mapping
            if (setup_idx < n) begin
                pos_a[a[setup_idx]] <= setup_idx;
                pos_b[b[setup_idx]] <= setup_idx;
                pos_c[c[setup_idx]] <= setup_idx;
            end
        end
    end

endmodule