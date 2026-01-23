module BookPresentationMinimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] B,
    input wire [3:0] G,
    input wire [5:0] edge_count,
    input wire [3:0] edges_boy [0:15],
    input wire [3:0] edges_girl [0:15],
    output reg [4:0] result,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_BOYS = 4'd4;
    localparam [3:0] MAX_GIRLS = 4'd4;
    localparam [5:0] MAX_EDGES = 6'd16;
    localparam [4:0] MAX_VERTICES = 5'd8; // B + G

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_SUBSET = 3'd1;
    localparam [2:0] CHECK_EDGE = 3'd2;
    localparam [2:0] UPDATE_MIN = 3'd3;
    localparam [2:0] NEXT_SUBSET = 3'd4;
    localparam [2:0] FINISHED = 3'd5;

    // Registers and wires
    reg [2:0] state, next_state;
    reg [5:0] total_vertices; // B + G
    reg [7:0] max_subsets;    // 2^(total_vertices)
    reg [7:0] subset_counter; // current subset index (0 to max_subsets-1)
    reg [7:0] subset;         // the current subset bitmap
    reg [7:0] temp_subset;    // temporary subset during iteration
    reg [4:0] current_size;   // popcount of current subset
    reg [5:0] edge_idx;       // current edge index to check
    reg [5:0] min_cover;      // minimum cover found so far
    reg [2:0] cycle_counter;  // prevents infinite loops in states
    reg found_uncovered;      // flag for edge checking
    reg [4:0] popcount_val;   // computed popcount
    reg [4:0] i_counter;      // loop counter for popcount
    reg [4:0] bit_idx;        // bit index for subset generation

    // Helper signals
    wire [3:0] boy_idx = edges_boy[edge_idx];
    wire [3:0] girl_idx = edges_girl[edge_idx];
    wire boy_in_subset = subset[boy_idx];
    wire girl_in_subset = subset[total_vertices + girl_idx];
    wire edge_covered = boy_in_subset | girl_in_subset;

    // Compute total vertices and max subsets
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_vertices <= 6'd0;
            max_subsets <= 8'd0;
        end else begin
            if (start) begin
                total_vertices <= B + G;
                case (B + G)
                    4'd0: max_subsets <= 8'd1;
                    4'd1: max_subsets <= 8'd2;
                    4'd2: max_subsets <= 8'd4;
                    4'd3: max_subsets <= 8'd8;
                    4'd4: max_subsets <= 8'd16;
                    4'd5: max_subsets <= 8'd32;
                    4'd6: max_subsets <= 8'd64;
                    4'd7: max_subsets <= 8'd128;
                    4'd8: max_subsets <= 8'd256;
                    default: max_subsets <= 8'd256;
                endcase
            end
        end
    end

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            subset_counter <= 8'd0;
            subset <= 8'd0;
            temp_subset <= 8'd0;
            current_size <= 5'd0;
            edge_idx <= 6'd0;
            min_cover <= 6'd8; // Initialize to max possible
            cycle_counter <= 3'd0;
            found_uncovered <= 1'b0;
            popcount_val <= 5'd0;
            i_counter <= 5'd0;
            bit_idx <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 3'd0;
                    if (start) begin
                        min_cover <= 6'd8; // Reset to max
                        subset_counter <= 8'd0;
                    end
                end
                
                INIT_SUBSET: begin
                    // Generate subset from subset_counter
                    subset <= subset_counter;
                    current_size <= 5'd0;
                    temp_subset <= subset_counter;
                    i_counter <= 5'd0;
                    popcount_val <= 5'd0;
                    // Start checking edges
                    edge_idx <= 6'd0;
                    found_uncovered <= 1'b0;
                    cycle_counter <= cycle_counter + 3'd1;
                end
                
                CHECK_EDGE: begin
                    // Check if edge is covered
                    if (edge_idx < edge_count) begin
                        if (!edge_covered) begin
                            found_uncovered <= 1'b1;
                        end
                        edge_idx <= edge_idx + 6'd1;
                    end
                    cycle_counter <= cycle_counter + 3'd1;
                end
                
                UPDATE_MIN: begin
                    // If found_uncovered is false, subset is a vertex cover
                    if (!found_uncovered) begin
                        // Compute popcount if not already done
                        if (current_size == 5'd0 && i_counter <= total_vertices) begin
                            // Popcount computation loop
                            if (i_counter < total_vertices) begin
                                popcount_val <= popcount_val + subset[i_counter];
                                i_counter <= i_counter + 5'd1;
                            end else begin
                                current_size <= popcount_val;
                                i_counter <= 5'd0;
                            end
                        end else if (current_size == 5'd0 && i_counter > total_vertices) begin
                            // Already computed, now check min
                            if (popcount_val < min_cover) begin
                                min_cover <= popcount_val;
                            end
                            cycle_counter <= 3'd0;
                        end
                    end
                    cycle_counter <= cycle_counter + 3'd1;
                end
                
                NEXT_SUBSET: begin
                    subset_counter <= subset_counter + 8'd1;
                    cycle_counter <= 3'd0;
                    // Reset flags
                    found_uncovered <= 1'b0;
                    popcount_val <= 5'd0;
                    current_size <= 5'd0;
                    i_counter <= 5'd0;
                end
                
                FINISHED: begin
                    result <= min_cover;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 5'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start) begin
                    if (total_vertices > 5'd0 && edge_count > 6'd0) begin
                        next_state = INIT_SUBSET;
                    end else begin
                        // No vertices or edges, answer is 0
                        next_state = FINISHED;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            INIT_SUBSET: begin
                if (subset_counter >= max_subsets) begin
                    next_state = FINISHED;
                end else begin
                    next_state = CHECK_EDGE;
                end
            end
            
            CHECK_EDGE: begin
                if (edge_idx >= edge_count) begin
                    // Finished checking all edges for this subset
                    // Check if subset is valid (all covered)
                    if (found_uncovered) begin
                        // Not a vertex cover, skip update
                        next_state = NEXT_SUBSET;
                    end else begin
                        // Is a vertex cover, update min
                        next_state = UPDATE_MIN;
                    end
                end else begin
                    // Continue checking edges
                    next_state = CHECK_EDGE;
                end
            end
            
            UPDATE_MIN: begin
                if (current_size > 5'd0 && i_counter > total_vertices) begin
                    // Popcount computation complete, check next subset
                    next_state = NEXT_SUBSET;
                end else if (current_size > 5'd0) begin
                    // Already computed popcount, check next subset
                    next_state = NEXT_SUBSET;
                end else if (i_counter >= total_vertices && i_counter > 5'd0) begin
                    // Popcount computation done in this cycle
                    next_state = NEXT_SUBSET;
                end else begin
                    // Continue popcount computation
                    next_state = UPDATE_MIN;
                end
            end
            
            NEXT_SUBSET: begin
                next_state = INIT_SUBSET;
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule