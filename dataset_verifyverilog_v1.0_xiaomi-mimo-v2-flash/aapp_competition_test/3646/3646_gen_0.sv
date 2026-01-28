module pebble_jump (
    input clk,
    input rst_n,
    input start,
    input [7:0] nodes_spots [0:15],
    input [3:0] num_nodes,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INIT          = 3'd1;
    localparam [2:0] CHECK         = 3'd2;
    localparam [2:0] UPDATE        = 3'd3;
    localparam [2:0] CALC_RESULT   = 3'd4;
    localparam [2:0] FINISH        = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Reachable nodes bitmask (16 bits)
    reg [15:0] reachable;
    reg [15:0] next_reachable;
    
    // Counter for node iteration
    reg [3:0] u_counter;
    reg [3:0] v_counter;
    
    // Cycle counter for timeout protection
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;
    
    // Flags for iteration control
    reg nodes_updated;
    reg next_nodes_updated;
    
    // Temp registers for computation
    reg [7:0] spot_u;
    reg [7:0] spot_v;
    reg [7:0] distance;
    reg [7:0] sum_spots;
    reg jump_possible;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            INIT: begin
                next_state = CHECK;
            end
            CHECK: begin
                // Check if we need to update reachable set
                if (nodes_updated)
                    next_state = UPDATE;
                else if (u_counter >= num_nodes - 1)
                    next_state = CALC_RESULT;
                else
                    next_state = CHECK;
            end
            UPDATE: begin
                next_state = INIT;
            end
            CALC_RESULT: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Combinational logic for jump condition check
    always @(*) begin
        // Initialize defaults
        jump_possible = 1'b0;
        sum_spots = 8'd0;
        distance = 8'd0;
        spot_u = 8'd0;
        spot_v = 8'd0;
        
        if (u_counter < num_nodes && v_counter < num_nodes) begin
            spot_u = nodes_spots[u_counter];
            spot_v = nodes_spots[v_counter];
            
            // Calculate absolute difference for distance
            if (u_counter > v_counter)
                distance = u_counter - v_counter;
            else
                distance = v_counter - u_counter;
            
            // Check jump condition: spots[u] + spots[v] == |u - v|
            sum_spots = spot_u + spot_v;
            jump_possible = (sum_spots == distance);
        end
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            reachable <= 16'd0;
            u_counter <= 4'd0;
            v_counter <= 4'd0;
            cycle_count <= 10'd0;
            nodes_updated <= 1'b0;
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 4'd0;
                    cycle_count <= 10'd0;
                    reachable <= 16'd0;
                end
                
                INIT: begin
                    // Start iteration from node 0
                    // Only process if node 0 is valid (within num_nodes)
                    if (num_nodes > 4'd0) begin
                        // Initialize reachable set with node 0 if within bounds
                        if (num_nodes > 4'd0) begin
                            reachable[0] <= 1'b1;
                        end
                    end
                    u_counter <= 4'd0;
                    v_counter <= 4'd0;
                    nodes_updated <= 1'b0;
                end
                
                CHECK: begin
                    // Increment cycle count for timeout protection
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Check if current u is reachable
                    if (reachable[u_counter]) begin
                        // Check if v is valid and not already reachable
                        if (v_counter < num_nodes && !reachable[v_counter]) begin
                            // Check jump condition
                            if (jump_possible) begin
                                nodes_updated <= 1'b1;
                                reachable[v_counter] <= 1'b1;
                            end
                        end
                    end
                    
                    // Update counters
                    if (v_counter >= num_nodes - 1) begin
                        v_counter <= 4'd0;
                        if (u_counter >= num_nodes - 1) begin
                            // Done checking all pairs
                        end else begin
                            u_counter <= u_counter + 4'd1;
                        end
                    end else begin
                        v_counter <= v_counter + 4'd1;
                    end
                end
                
                UPDATE: begin
                    // Reset counters for next iteration
                    u_counter <= 4'd0;
                    v_counter <= 4'd0;
                    nodes_updated <= 1'b0;
                end
                
                CALC_RESULT: begin
                    // Find maximum reachable node index
                    result <= 4'd0; // Default if no reachable nodes
                    
                    // Check from highest index downward
                    if (reachable[15] && num_nodes > 4'd15)
                        result <= 4'd15;
                    else if (reachable[14] && num_nodes > 4'd14)
                        result <= 4'd14;
                    else if (reachable[13] && num_nodes > 4'd13)
                        result <= 4'd13;
                    else if (reachable[12] && num_nodes > 4'd12)
                        result <= 4'd12;
                    else if (reachable[11] && num_nodes > 4'd11)
                        result <= 4'd11;
                    else if (reachable[10] && num_nodes > 4'd10)
                        result <= 4'd10;
                    else if (reachable[9] && num_nodes > 4'd9)
                        result <= 4'd9;
                    else if (reachable[8] && num_nodes > 4'd8)
                        result <= 4'd8;
                    else if (reachable[7] && num_nodes > 4'd7)
                        result <= 4'd7;
                    else if (reachable[6] && num_nodes > 4'd6)
                        result <= 4'd6;
                    else if (reachable[5] && num_nodes > 4'd5)
                        result <= 4'd5;
                    else if (reachable[4] && num_nodes > 4'd4)
                        result <= 4'd4;
                    else if (reachable[3] && num_nodes > 4'd3)
                        result <= 4'd3;
                    else if (reachable[2] && num_nodes > 4'd2)
                        result <= 4'd2;
                    else if (reachable[1] && num_nodes > 4'd1)
                        result <= 4'd1;
                    else if (reachable[0] && num_nodes > 4'd0)
                        result <= 4'd0;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Timeout protection: Force finish if cycle count exceeds max
            if (cycle_count >= MAX_CYCLES && state != FINISH && state != IDLE) begin
                state <= CALC_RESULT;
            end
        end
    end

endmodule