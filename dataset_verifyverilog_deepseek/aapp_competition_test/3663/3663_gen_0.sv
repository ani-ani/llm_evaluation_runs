module army_move_calculator(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_nations,
    input [3:0] parent_node [0:7],
    input [15:0] move_costs [0:7],
    input [15:0] init_armies [0:7],
    input [15:0] req_armies [0:7],
    output reg [31:0] total_cost,
    output reg done
);
    typedef enum {IDLE, CALCULATE, DONE_ST} state_t;
    state_t current_state, next_state;

    reg [3:0] node_counter;
    reg [3:0] cycle_counter;
    reg [15:0] adjusted_armies [0:7];
    integer i;

    wire signed [16:0] node_surplus = $signed({1'b0, adjusted_armies[node_counter]}) - $signed({1'b0, req_armies[node_counter]});
    wire [15:0] surplus_abs = node_surplus[16] ? (~node_surplus[15:0] + 1) : node_surplus[15:0];
    wire [31:0] movement_cost = move_costs[node_counter] * surplus_abs;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            node_counter <= 0;
            cycle_counter <= 0;
            total_cost <= 0;
            done <= 0;
            for (i = 0; i < 8; i = i + 1) adjusted_armies[i] <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        current_state <= CALCULATE;
                        cycle_counter <= 0;
                        node_counter <= 0;
                        total_cost <= 0;
                        for (i = 0; i < 8; i = i + 1) adjusted_armies[i] <= init_armies[i];
                    end
                end
                CALCULATE: begin
                    cycle_counter <= cycle_counter + 1;
                    if (node_counter < num_nations) begin
                        total_cost <= total_cost + movement_cost;
                        if (parent_node[node_counter] < num_nations) 
                            adjusted_armies[parent_node[node_counter]] <= adjusted_armies[parent_node[node_counter]] + $signed(node_surplus);
                        node_counter <= node_counter + 1;
                    end
                    if (cycle_counter == 15) current_state <= DONE_ST;
                end
                DONE_ST: begin
                    done <= 1;
                    current_state <= IDLE;
                end
            endcase
        end
    end
endmodule