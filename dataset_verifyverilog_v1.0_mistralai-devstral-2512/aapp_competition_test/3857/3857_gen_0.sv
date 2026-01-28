module minimal_pile_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [7:0] arr [0:15],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SORT      = 3'd1;
    localparam [2:0] ASSIGN    = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;
    
    // Sorted array
    reg [7:0] sorted_arr [0:15];
    
    // Sorting variables
    reg [3:0] sort_i, sort_j;
    reg [7:0] sort_key;
    
    // Assignment variables
    reg [3:0] box_idx;
    reg [3:0] pile_count;
    reg [7:0] pile_heights [0:15];
    reg [3:0] pile_idx;
    reg [7:0] current_strength;
    reg found_pile;
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all state
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            
            // Initialize sorted array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                sorted_arr[i] <= 8'd0;
            end
            
            // Initialize sorting variables
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            sort_key <= 8'd0;
            
            // Initialize assignment variables
            box_idx <= 4'd0;
            pile_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                pile_heights[i] <= 8'd0;
            end
            pile_idx <= 4'd0;
            current_strength <= 8'd0;
            found_pile <= 1'b0;
            
            // Outputs
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        // Initialize for new computation
                        sort_i <= 4'd1;
                        sort_j <= 4'd0;
                        
                        // Copy input array to sorted array
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            sorted_arr[i] <= arr[i];
                        end
                        
                        next_state <= SORT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Insertion sort
                    if (sort_i < len) begin
                        if (sort_j < sort_i) begin
                            if (sorted_arr[sort_j] > sorted_arr[sort_i]) begin
                                // Swap
                                sort_key <= sorted_arr[sort_j];
                                sorted_arr[sort_j] <= sorted_arr[sort_i];
                                sorted_arr[sort_i] <= sort_key;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end else begin
                        // Sorting complete
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        
                        // Initialize assignment variables
                        box_idx <= 4'd0;
                        pile_count <= 4'd0;
                        
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            pile_heights[i] <= 8'd0;
                        end
                        
                        next_state <= ASSIGN;
                    end
                end
                
                ASSIGN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (box_idx < len) begin
                        current_strength <= sorted_arr[box_idx];
                        
                        // Search for suitable pile
                        if (pile_idx < pile_count) begin
                            if (pile_heights[pile_idx] <= current_strength) begin
                                // Found suitable pile
                                pile_heights[pile_idx] <= pile_heights[pile_idx] + 8'd1;
                                found_pile <= 1'b1;
                            end else begin
                                pile_idx <= pile_idx + 4'd1;
                                found_pile <= 1'b0;
                            end
                        end else begin
                            // No suitable pile found, create new one
                            if (!found_pile && pile_count < 16) begin
                                pile_heights[pile_count] <= 8'd1;
                                pile_count <= pile_count + 4'd1;
                            end
                            
                            // Move to next box
                            box_idx <= box_idx + 4'd1;
                            pile_idx <= 4'd0;
                            found_pile <= 1'b0;
                        end
                    end else begin
                        // Assignment complete
                        result <= pile_count;
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Timeout protection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE && state != FINISH) begin
            if (cycle_count >= MAX_CYCLES) begin
                // Force completion on timeout
                result <= pile_count;
                done <= 1'b1;
                next_state <= IDLE;
            end
        end
    end

endmodule