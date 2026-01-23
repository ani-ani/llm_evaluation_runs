module dsu_union_find (input clk, input rst_n, input start, input [2:0] op_type, input [2:0] a, input [2:0] b, output reg result, output reg done, output reg [2:0] parent [0:7]);
reg [2:0] state;
localparam IDLE = 3'b000;
localparam FIND_A_ROOT = 3'b001;
localparam FIND_B_ROOT = 3'b010;
localparam UNION_OP = 3'b011;
localparam QUERY_OP = 3'b100;
localparam DONE_STATE = 3'b101;

reg [2:0] op_type_reg;
reg [2:0] a_reg;
reg [2:0] b_reg;
reg [2:0] current_node;
reg [2:0] root_a;
reg [2:0] root_b;
reg [3:0] cycle_count;
reg [2:0] find_counter;

always @(negedge rst_n or posedge clk) begin
    if (!rst_n) begin
        parent[0] <= 3'b000;
        parent[1] <= 3'b001;
        parent[2] <= 3'b010;
        parent[3] <= 3'b011;
        parent[4] <= 3'b100;
        parent[5] <= 3'b101;
        parent[6] <= 3'b110;
        parent[7] <= 3'b111;
        op_type_reg <= 3'b000;
        a_reg <= 3'b000;
        b_reg <= 3'b000;
        state <= IDLE;
        cycle_count <= 4'd0;
        find_counter <= 3'b000;
        done <= 1'b0;
        result <= 1'b0;
        current_node <= 3'b000;
        root_a <= 3'b000;
        root_b <= 3'b000;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    op_type_reg <= op_type;
                    a_reg <= a;
                    b_reg <= b;
                    state <= FIND_A_ROOT;
                    cycle_count <= 4'd0;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            end
            FIND_A_ROOT: begin
                if (find_counter == 3'b000) begin
                    current_node <= a_reg;
                    find_counter <= 3'b111;
                end
                if (parent[current_node] != current_node) begin
                    parent[current_node] <= parent[parent[current_node]];
                    current_node <= parent[current_node];
                    find_counter <= find_counter - 1;
                end else begin
                    root_a <= current_node;
                    state <= FIND_B_ROOT;
                    find_counter <= 3'b000;
                end
            end
            FIND_B_ROOT: begin
                if (find_counter == 3'b000) begin
                    current_node <= b_reg;
                    find_counter <= 3'b111;
                end
                if (parent[current_node] != current_node) begin
                    parent[current_node] <= parent[parent[current_node]];
                    current_node <= parent[current_node];
                    find_counter <= find_counter - 1;
                end else begin
                    root_b <= current_node;
                    state <= (op_type_reg == 0) ? UNION_OP : QUERY_OP;
                    find_counter <= 3'b000;
                end
            end
            UNION_OP: begin
                parent[root_a] <= root_b;
                state <= DONE_STATE;
            end
            QUERY_OP: begin
                result <= (root_a == root_b) ? 1'b1 : 1'b0;
                state <= DONE_STATE;
            end
            DONE_STATE: begin
                done <= 1'b1;
            end
            default: state <= IDLE;
        endcase

        if (state != IDLE) begin
            cycle_count <= cycle_count + 1;
        end
    end
endmodule