module debt_resolver (
    input clk,
    input rst_n,
    input start,
    input [7:0] debtor_0, debtor_1, debtor_2, debtor_3, debtor_4, debtor_5, debtor_6, debtor_7,
    input [7:0] debt_0, debt_1, debt_2, debt_3, debt_4, debt_5, debt_6, debt_7,
    output reg [15:0] total_money,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT_DATA  = 3'd1;
    localparam [2:0] RESOLVE    = 3'd2;
    localparam [2:0] COMPLETE   = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] node_idx;
    reg [7:0] visited;
    reg [15:0] total_sum;
    reg [15:0] cycle_min;
    reg cycle_found;
    reg [7:0] processed;
    reg [7:0] visited_now;
    reg [2:0] step_count;
    reg [2:0] start_node;
    reg [2:0] current_node;
    reg [2:0] next_node;
    reg [15:0] money_needed [0:7];
    
    // Wires for inputs (easier access)
    wire [7:0] debtors [0:7];
    wire [7:0] debts [0:7];
    
    assign debtors[0] = debtor_0;
    assign debtors[1] = debtor_1;
    assign debtors[2] = debtor_2;
    assign debtors[3] = debtor_3;
    assign debtors[4] = debtor_4;
    assign debtors[5] = debtor_5;
    assign debtors[6] = debtor_6;
    assign debtors[7] = debtor_7;
    
    assign debts[0] = debt_0;
    assign debts[1] = debt_1;
    assign debts[2] = debt_2;
    assign debts[3] = debt_3;
    assign debts[4] = debt_4;
    assign debts[5] = debt_5;
    assign debts[6] = debt_6;
    assign debts[7] = debt_7;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_money <= 16'd0;
            done <= 1'b0;
            node_idx <= 3'd0;
            visited <= 8'd0;
            total_sum <= 16'd0;
            cycle_min <= 16'd0;
            cycle_found <= 1'b0;
            processed <= 8'd0;
            visited_now <= 8'd0;
            step_count <= 3'd0;
            start_node <= 3'd0;
            current_node <= 3'd0;
            next_node <= 3'd0;
            money_needed[0] <= 16'd0;
            money_needed[1] <= 16'd0;
            money_needed[2] <= 16'd0;
            money_needed[3] <= 16'd0;
            money_needed[4] <= 16'd0;
            money_needed[5] <= 16'd0;
            money_needed[6] <= 16'd0;
            money_needed[7] <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    total_money <= 16'd0;
                    node_idx <= 3'd0;
                    visited <= 8'd0;
                    processed <= 8'd0;
                    if (start) begin
                        // Initialize money needed array
                        money_needed[0] <= 16'd0;
                        money_needed[1] <= 16'd0;
                        money_needed[2] <= 16'd0;
                        money_needed[3] <= 16'd0;
                        money_needed[4] <= 16'd0;
                        money_needed[5] <= 16'd0;
                        money_needed[6] <= 16'd0;
                        money_needed[7] <= 16'd0;
                    end
                end
                
                INIT_DATA: begin
                    // Just pass through to next state
                    node_idx <= 3'd0;
                    visited <= 8'd0;
                    processed <= 8'd0;
                end
                
                RESOLVE: begin
                    // Process nodes that aren't visited
                    if (node_idx < 3'd8) begin
                        if (!visited[node_idx] && !processed[node_idx]) begin
                            // Start traversal from this node
                            start_node <= node_idx;
                            current_node <= node_idx;
                            visited_now <= 8'd0;
                            step_count <= 3'd0;
                            cycle_min <= 16'hFFFF;
                            cycle_found <= 1'b0;
                        end
                        node_idx <= node_idx + 3'd1;
                    end
                end
                
                COMPLETE: begin
                    total_money <= total_sum;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = INIT_DATA;
            end
            
            INIT_DATA: begin
                next_state = RESOLVE;
            end
            
            RESOLVE: begin
                // Check if we need to process more nodes
                if (node_idx >= 3'd8) begin
                    next_state = COMPLETE;
                end
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Combinational logic for cycle detection and processing
    always @(*) begin
        integer i;
        integer temp_node;
        integer steps;
        reg [7:0] temp_visited;
        reg found_cycle;
        reg [15:0] temp_min;
        
        // Initialize outputs
        found_cycle = 1'b0;
        temp_min = 16'hFFFF;
        
        if (state == RESOLVE && !visited[start_node] && !processed[start_node]) begin
            temp_visited = 8'd0;
            temp_node = start_node;
            steps = 0;
            
            // Follow chain for at most 8 steps
            while (steps < 8) begin
                // Check if node is valid
                if (temp_node >= 8) begin
                    break;
                end
                
                // Mark visited in current traversal
                if (temp_visited[temp_node]) begin
                    // Found a cycle
                    found_cycle = 1'b1;
                    break;
                end
                
                temp_visited[temp_node] = 1'b1;
                
                // Follow to next node
                temp_node = debtors[temp_node];
                steps = steps + 1;
            end
            
            // Calculate minimum debt in the cycle
            if (found_cycle) begin
                temp_min = 16'hFFFF;
                temp_node = start_node;
                for (i = 0; i < 8; i = i + 1) begin
                    if (temp_visited[temp_node]) begin
                        if (debts[temp_node] < temp_min) begin
                            temp_min = debts[temp_node];
                        end
                        temp_node = debtors[temp_node];
                    end
                end
            end
        end
        
        // Update registers based on combinational logic
        if (state == RESOLVE && !visited[start_node] && !processed[start_node]) begin
            cycle_found = found_cycle;
            cycle_min = temp_min;
            if (found_cycle) begin
                visited[start_node] = 1'b1;
                processed[start_node] = 1'b1;
                total_sum = total_sum + temp_min;
            end
        end
    end

endmodule