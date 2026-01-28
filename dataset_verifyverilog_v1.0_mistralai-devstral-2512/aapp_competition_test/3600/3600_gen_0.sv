module IndependentSetChecker(
    input clk,
    input rst_n,
    input start,
    input [3:0] k_in,
    input [511:0] graph_packed,
    input [5:0] num_nodes,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK_COMBINATION = 3'd2;
    localparam [2:0] NEXT_COMBINATION = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state;
    reg [31:0] selection_mask;
    reg [31:0] combo_index;
    reg [5:0] node_idx;
    reg [5:0] check_idx;
    reg [5:0] current_k;
    reg [5:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            selection_mask <= 32'd0;
            combo_index <= 32'd0;
            node_idx <= 6'd0;
            check_idx <= 6'd0;
            current_k <= 6'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 10'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    current_k <= k_in;
                    selection_mask <= 32'd0;
                    combo_index <= 32'd0;
                    node_idx <= 6'd0;
                    check_idx <= 6'd0;
                    
                    // Special cases
                    if (current_k == 4'd0) begin
                        result <= 1'b1;  // Empty set always valid
                        state <= DONE_STATE;
                    end else if (current_k == 4'd1) begin
                        result <= 1'b1;  // Single node always valid
                        state <= DONE_STATE;
                    end else if (current_k > num_nodes) begin
                        result <= 1'b0;  // Impossible
                        state <= DONE_STATE;
                    end else begin
                        state <= CHECK_COMBINATION;
                    end
                end

                CHECK_COMBINATION: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Check if we've found k nodes
                    if (node_idx == current_k) begin
                        // Verify no adjacent nodes
                        reg [31:0] mask1, mask2;
                        reg valid;
                        integer i, j;
                        
                        valid = 1'b1;
                        for (i = 0; i < 32; i = i + 1) begin
                            if (selection_mask[i]) begin
                                mask1 = graph_packed[(i*16)+15:(i*16)];
                                for (j = i+1; j < 32; j = j + 1) begin
                                    if (selection_mask[j]) begin
                                        mask2 = graph_packed[(j*16)+15:(j*16)];
                                        if (mask1 & mask2) begin
                                            valid = 1'b0;
                                        end
                                    end
                                end
                            end
                        end
                        
                        if (valid) begin
                            result <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            state <= NEXT_COMBINATION;
                        end
                    end else begin
                        // Continue building combination
                        if (combo_index < num_nodes) begin
                            selection_mask[node_idx] = 1'b1;
                            node_idx <= node_idx + 6'd1;
                            combo_index <= combo_index + 32'd1;
                        end else begin
                            state <= NEXT_COMBINATION;
                        end
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 1'b0;
                        state <= DONE_STATE;
                    end
                end

                NEXT_COMBINATION: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Backtrack to find next combination
                    if (node_idx == 6'd0) begin
                        // All combinations exhausted
                        result <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        node_idx <= node_idx - 6'd1;
                        combo_index <= combo_index + 32'd1;
                        selection_mask[node_idx] = 1'b0;
                        
                        // Try next node
                        if (combo_index < num_nodes) begin
                            selection_mask[node_idx] = 1'b1;
                            node_idx <= node_idx + 6'd1;
                            combo_index <= combo_index + 32'd1;
                            state <= CHECK_COMBINATION;
                        end
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 1'b0;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule