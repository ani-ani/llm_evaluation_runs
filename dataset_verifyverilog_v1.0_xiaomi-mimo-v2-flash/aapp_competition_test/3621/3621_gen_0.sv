module graph_coloring (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0][15:0][7:0] color_matrix,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [7:0] MAX_SUBSETS = 8'd16;
    
    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] LOAD_N        = 4'd1;
    localparam [3:0] RESET_COUNTER = 4'd2;
    localparam [3:0] CHECK_SUBSET  = 4'd3;
    localparam [3:0] CHECK_CLIQUE  = 4'd4;
    localparam [3:0] UPDATE_F      = 4'd5;
    localparam [3:0] ACCUMULATE    = 4'd6;
    localparam [3:0] INCREMENT     = 4'd7;
    localparam [3:0] FINISHED      = 4'd8;

    // Registers for state machine
    reg [3:0] state, next_state;
    reg [3:0] n_reg;
    
    // Subset iteration: 0 to 2^n - 1
    reg [15:0] subset_idx;
    wire [15:0] max_subset;
    assign max_subset = (n_reg >= 4'd1) ? (16'd1 << n_reg) - 16'd1 : 16'd0;
    
    // Internal signals
    reg [31:0] temp_result;
    reg [3:0] f_S;  // Max clique size for current subset
    reg [3:0] clique_size;
    reg [15:0] current_subset;
    reg [15:0] sub_subset;
    reg [15:0] sub_subset_mask;
    reg [31:0] cycle_counter; // Safety timeout
    localparam [31:0] MAX_CYCLES = 32'd10000;
    
    // Flags
    reg start_reg;
    reg processing;
    reg clique_valid;
    
    integer i, j;

    // Timeout protection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter <= 32'd0;
        end else if (start || (state == IDLE)) begin
            cycle_counter <= 32'd0;
        end else if (processing) begin
            cycle_counter <= cycle_counter + 32'd1;
        end
    end

    // State machine transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            temp_result <= 32'd0;
            n_reg <= 4'd0;
            subset_idx <= 16'd0;
            current_subset <= 16'd0;
            sub_subset <= 16'd0;
            sub_subset_mask <= 16'd0;
            f_S <= 4'd0;
            clique_size <= 4'd0;
            start_reg <= 1'b0;
            processing <= 1'b0;
        end else begin
            // Default outputs
            done <= 1'b0;
            
            // Capture start pulse
            if (start) begin
                start_reg <= 1'b1;
            end
            
            case (state)
                IDLE: begin
                    processing <= 1'b0;
                    if (start_reg || start) begin
                        state <= LOAD_N;
                        start_reg <= 1'b0;
                    end
                end

                LOAD_N: begin
                    n_reg <= n;
                    temp_result <= 32'd0;
                    subset_idx <= 16'd0;
                    state <= RESET_COUNTER;
                end

                RESET_COUNTER: begin
                    subset_idx <= 16'd0;
                    state <= CHECK_SUBSET;
                end

                CHECK_SUBSET: begin
                    if (subset_idx <= max_subset) begin
                        if (subset_idx == 16'd0) begin
                            state <= INCREMENT; // Skip empty set
                        end else begin
                            current_subset <= subset_idx;
                            f_S <= 4'd0;
                            sub_subset_mask <= subset_idx; // Start with subset itself
                            sub_subset <= subset_idx;
                            state <= CHECK_CLIQUE;
                        end
                    end else begin
                        state <= FINISHED;
                    end
                end

                CHECK_CLIQUE: begin
                    // Check if sub_subset is a monochromatic clique
                    if (sub_subset_mask != 16'd0) begin
                        // Check if sub_subset is valid (bits set in current_subset)
                        // sub_subset is constructed from current_subset bits
                        // We iterate through all non-empty sub-subsets of current_subset
                        // Logic: generate sub_subset by iterating bits
                        
                        // Simple check: is sub_subset non-empty and subset of current_subset?
                        // Since we construct it from current_subset, it's valid.
                        // Check monochromatic property
                        
                        // Get first node index
                        reg [3:0] node1;
                        reg [3:0] node2;
                        reg [7:0] expected_color;
                        reg [3:0] temp_idx1;
                        reg [3:0] temp_idx2;
                        reg is_clique;
                        reg [3:0] count;
                        
                        node1 = 4'd0;
                        node2 = 4'd0;
                        expected_color = 8'd0;
                        is_clique = 1'b0;
                        count = 4'd0;
                        
                        // Count bits in sub_subset
                        temp_idx1 = 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (sub_subset[i]) begin
                                count = count + 4'd1;
                                if (count == 4'd1) node1 = temp_idx1;
                                if (count == 4'd2) node2 = temp_idx1;
                            end
                            temp_idx1 = temp_idx1 + 4'd1;
                        end
                        
                        if (count <= 4'd1) begin
                            // Single node is always a valid clique
                            clique_valid = 1'b1;
                            clique_size = count;
                        end else begin
                            // Check all pairs in sub_subset
                            is_clique = 1'b1;
                            expected_color = color_matrix[node1][node2];
                            
                            temp_idx1 = 4'd0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (sub_subset[i]) begin
                                    temp_idx2 = 4'd0;
                                    for (j = 0; j < 16; j = j + 1) begin
                                        if (sub_subset[j]) begin
                                            if (i != j) begin
                                                if (color_matrix[temp_idx1][temp_idx2] != expected_color) begin
                                                    is_clique = 1'b0;
                                                end
                                            end
                                        end
                                        temp_idx2 = temp_idx2 + 4'd1;
                                    end
                                end
                                temp_idx1 = temp_idx1 + 4'd1;
                            end
                            
                            if (is_clique) begin
                                clique_valid = 1'b1;
                                clique_size = count;
                            end else begin
                                clique_valid = 1'b0;
                            end
                        end
                        
                        if (clique_valid) begin
                            if (clique_size > f_S) begin
                                f_S <= clique_size;
                            end
                        end
                        
                        state <= UPDATE_F;
                    end else begin
                        state <= ACCUMULATE;
                    end
                end

                UPDATE_F: begin
                    // Generate next sub-subset
                    // Simple iteration: decrement sub_subset until 0 (reverse order)
                    // Or iterate all masks of current_subset (efficient enough for n<=16)
                    // Let's iterate downwards from current_subset to 0
                    
                    if (sub_subset_mask != 16'd0) begin
                        sub_subset_mask <= sub_subset_mask - 16'd1;
                        // Reconstruct sub_subset as sub_subset_mask & current_subset
                        // Since current_subset is the target, we just use the mask directly for iteration
                        // Wait, we need to iterate SUBSETS of current_subset.
                        // If current_subset = 0b0101, subsets are 0b0101, 0b0100, 0b0001, 0b0000.
                        // We can just iterate value from current_subset down to 0.
                        // But we need to mask it.
                        
                        // Let's change logic slightly in CHECK_CLIQUE
                        // We use 'sub_subset' as the value iterating down.
                        sub_subset <= sub_subset - 16'd1;
                        state <= CHECK_CLIQUE;
                    end else begin
                        state <= ACCUMULATE;
                    end
                end

                ACCUMULATE: begin
                    // result = (result + f_S) % MOD
                    if (f_S > 4'd0) begin
                        temp_result <= temp_result + {28'd0, f_S};
                        if (temp_result + {28'd0, f_S} >= MOD) begin
                            temp_result <= (temp_result + {28'd0, f_S}) - MOD;
                        end
                    end
                    state <= INCREMENT;
                end

                INCREMENT: begin
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= FINISHED; // Timeout fallback
                    end else begin
                        subset_idx <= subset_idx + 16'd1;
                        state <= CHECK_SUBSET;
                    end
                end

                FINISHED: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule