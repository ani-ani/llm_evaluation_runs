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
localparam [1:0] IDLE = 2'd0;
localparam [1:0] RESOLVE = 2'd1;
localparam [1:0] CALCULATE = 2'd2;
localparam [1:0] COMPLETE = 2'd3;

// Internal registers
reg [1:0] state, next_state;
reg [2:0] node_index;
reg [15:0] money_needed [0:7];
reg [15:0] total_sum;
reg [15:0] cycle_min;
reg [2:0] cycle_start;
reg [2:0] cycle_current;
reg cycle_found;
reg [7:0] visited;
reg [2:0] iterations;

// Arrays for easier access
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
        total_money <= 0;
        done <= 0;
        node_index <= 0;
        visited <= 0;
        iterations <= 0;
        // Initialize money_needed
        money_needed[0] <= 0;
        money_needed[1] <= 0;
        money_needed[2] <= 0;
        money_needed[3] <= 0;
        money_needed[4] <= 0;
        money_needed[5] <= 0;
        money_needed[6] <= 0;
        money_needed[7] <= 0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    total_money <= 0;
                    done <= 0;
                    node_index <= 0;
                    visited <= 0;
                    iterations <= 0;
                    // Initialize money_needed
                    money_needed[0] <= 0;
                    money_needed[1] <= 0;
                    money_needed[2] <= 0;
                    money_needed[3] <= 0;
                    money_needed[4] <= 0;
                    money_needed[5] <= 0;
                    money_needed[6] <= 0;
                    money_needed[7] <= 0;
                end
            end
            
            RESOLVE: begin
                // Process each node to determine if it needs initial money
                if (node_index < 8 && iterations < 8) begin
                    // Check if this node is part of a cycle
                    if (!visited[node_index]) begin
                        // Start cycle detection from this node
                        cycle_start <= node_index;
                        cycle_current <= node_index;
                        cycle_min <= 16'hFFFF;
                        cycle_found <= 0;
                    end
                    node_index <= node_index + 1;
                end
            end
            
            CALCULATE: begin
                // Add cycle minimum to total
                if (cycle_found && cycle_min != 16'hFFFF) begin
                    total_money <= total_money + cycle_min;
                end
            end
            
            COMPLETE: begin
                done <= 1;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = RESOLVE;
        end
        
        RESOLVE: begin
            if (node_index >= 8 || iterations >= 8) begin
                next_state = CALCULATE;
            end else begin
                next_state = RESOLVE;
            end
        end
        
        CALCULATE: begin
            next_state = COMPLETE;
        end
        
        COMPLETE: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

// Cycle detection and minimum calculation (combinational logic)
always @(*) begin
    cycle_found = 0;
    cycle_min = 16'hFFFF;
    
    // Simple cycle detection: check if node points to itself or forms small cycle
    if (state == RESOLVE && node_index < 8) begin
        integer start_idx, current_idx, count;
        start_idx = node_index;
        current_idx = start_idx;
        count = 0;
        
        // Follow the debt chain for at most 8 steps
        while (count < 8) begin
            integer next_node;
            next_node = debtors[current_idx];
            
            // Check if valid node
            if (next_node >= 8) break;
            
            // Found cycle when we revisit a node
            if (next_node == start_idx) begin
                cycle_found = 1;
                // Calculate minimum debt in cycle
                cycle_min = debts[start_idx];
                if (debts[current_idx] < cycle_min) cycle_min = debts[current_idx];
                break;
            end
            
            // Check for simple self-loop
            if (next_node == current_idx) begin
                cycle_found = 1;
                cycle_min = debts[current_idx];
                break;
            end
            
            current_idx = next_node;
            count = count + 1;
        end
    end
end

endmodule