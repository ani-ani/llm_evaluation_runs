module graph_decoration_optimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] node_count,
    input wire [3:0] edge_count,
    input wire [2:0] edge_u [0:15],
    input wire [2:0] edge_v [0:15],
    output reg [15:0] min_cost,
    output reg valid,
    output reg error
);

    reg [1:0] current_costs [0:15];
    reg [4:0] best_cost;
    reg [4:0] current_cost_sum;
    reg [15:0] candidates_tried;

    localparam IDLE = 3'b000;
    localparam VALIDATE_CONSTRAINTS = 3'b001;
    localparam CHECK_CYCLES = 3'b010;
    localparam UPDATE_BEST = 3'b011;
    localparam NEXT_CONFIG = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] edge_idx;
    reg [3:0] config_idx;
    reg [2:0] node_degree [0:7];

    reg [2:0] check_node;
    reg [3:0] check_edge_i;
    reg [3:0] check_edge_j;
    reg [1:0] cost_a, cost_b;
    reg constraint_violated;

    reg [7:0] visited_nodes;
    reg [3:0] cycle_edge_count;
    reg cycle_has_odd_length;
    reg [3:0] cycle_edge_idx;

    reg [15:0] cycle_edge_mask;
    reg [2:0] cycle_nodes [0:7];
    reg [2:0] cycle_node_count;

    integer i, j, k;

    function automatic bool check_mod_constraint(input [1:0] a, input [1:0] b);
        reg [1:0] sum;
        begin
            sum = a + b;
            if (sum >= 3) sum = sum - 3;
            check_mod_constraint = (sum != 1);
        end
    endfunction

    function automatic [4:0] calculate_sum(input [15:0] mask);
        reg [4:0] sum;
        begin
            sum = 0;
            for (i = 0; i < 16; i = i + 1) begin
                if (mask[i]) begin
                    case (current_costs[i])
                        2'b00: sum = sum + 0;
                        2'b01: sum = sum + 1;
                        2'b10: sum = sum + 2;
                        default: sum = sum + 0;
                    endcase
                end
            end
            calculate_sum = sum;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            error <= 0;
            min_cost <= 16'hFFFF;
            best_cost <= 5'h1F;
            config_idx <= 0;
            candidates_tried <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            current_costs[i] <= 2'b00;
                        end
                        best_cost <= 5'h1F;
                        config_idx <= 0;
                        candidates_tried <= 0;
                        valid <= 0;
                        error <= 0;
                        state <= (edge_count > 0) ? NEXT_CONFIG : DONE;
                    end
                end

                NEXT_CONFIG: begin
                    if (config_idx >= (3 ** edge_count) || candidates_tried[config_idx]) begin
                        if (best_cost == 5'h1F) begin
                            error <= 1;
                        end else begin
                            min_cost <= best_cost;
                            valid <= 1;
                        end
                        state <= DONE;
                    end else begin
                        decode_configuration(config_idx, current_costs, edge_count);
                        candidates_tried[config_idx] <= 1;
                        state <= VALIDATE_CONSTRAINTS;
                        check_node <= 0;
                        edge_idx <= 0;
                        current_cost_sum <= 0;
                    end
                end

                VALIDATE_CONSTRAINTS: begin
                    if (check_node < node_count) begin
                        constraint_violated <= 0;
                        check_edge_i <= 0;
                        check_edge_j <= 1;
                        state <= 2'b10;
                    end else begin
                        state <= CHECK_CYCLES;
                        cycle_edge_idx <= 0;
                        cycle_has_odd_length <= 0;
                    end
                end

                CHECK_CYCLES: begin
                    if (cycle_edge_idx < edge_count) begin
                        cycle_edge_idx <= cycle_edge_idx + 1;
                    end else begin
                        current_cost_sum <= calculate_sum(candidates_tried);
                        state <= UPDATE_BEST;
                    end
                end

                UPDATE_BEST: begin
                    if (!constraint_violated) begin
                        if (current_cost_sum[0] == 1) begin
                            if (current_cost_sum < best_cost) begin
                                best_cost <= current_cost_sum;
                            end
                        end
                    end
                    state <= NEXT_CONFIG;
                    config_idx <= config_idx + 1;
                end

                DONE: begin
                end
            endcase
        end
    end

    task automatic decode_configuration(
        input [4:0] idx,
        output reg [1:0] costs [0:15],
        input [3:0] count
    );
        integer k;
        reg [4:0] temp;
        begin
            temp = idx;
            for (k = 0; k < count; k = k + 1) begin
                costs[k] = temp % 3;
                temp = temp / 3;
            end
            for (k = count; k < 16; k = k + 1) begin
                costs[k] = 0;
            end
        end
    endtask

endmodule

module graph_decoration_optimizer_wrapper (
    input clk,
    input rst_n,
    input start,
    input [2:0] node_count,
    input [3:0] edge_count,
    input [2:0] edge_u_0, input [2:0] edge_v_0,
    input [2:0] edge_u_1, input [2:0] edge_v_1,
    input [2:0] edge_u_2, input [2:0] edge_v_2,
    input [2:0] edge_u_3, input [2:0] edge_v_3,
    input [2:0] edge_u_4, input [2:0] edge_v_4,
    input [2:0] edge_u_5, input [2:0] edge_v_5,
    input [2:0] edge_u_6, input [2:0] edge_v_6,
    input [2:0] edge_u_7, input [2:0] edge_v_7,
    output [15:0] min_cost,
    output valid,
    output error
);

    wire [2:0] edge_u [0:7];
    wire [2:0] edge_v [0:7];

    assign edge_u[0] = edge_u_0;
    assign edge_u[1] = edge_u_1;
    assign edge_u[2] = edge_u_2;
    assign edge_u[3] = edge_u_3;
    assign edge_u[4] = edge_u_4;
    assign edge_u[5] = edge_u_5;
    assign edge_u[6] = edge_u_6;
    assign edge_u[7] = edge_u_7;

    assign edge_v[0] = edge_v_0;
    assign edge_v[1] = edge_v_1;
    assign edge_v[2] = edge_v_2;
    assign edge_v[3] = edge_v_3;
    assign edge_v[4] = edge_v_4;
    assign edge_v[5] = edge_v_5;
    assign edge_v[6] = edge_v_6;
    assign edge_v[7] = edge_v_7;

    graph_decoration_optimizer u0 (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .node_count(node_count),
        .edge_count(edge_count),
        .edge_u(edge_u),
        .edge_v(edge_v),
        .min_cost(min_cost),
        .valid(valid),
        .error(error)
    );

endmodule