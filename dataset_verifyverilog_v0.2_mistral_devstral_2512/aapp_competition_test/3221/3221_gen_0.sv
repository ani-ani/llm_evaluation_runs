module min_energy_cycle(
    input clk,
    input rst_n,
    input start,
    input [3:0] edge_0_u, edge_0_v,
    input [31:0] edge_0_c,
    input [3:0] edge_1_u, edge_1_v,
    input [31:0] edge_1_c,
    input [3:0] edge_2_u, edge_2_v,
    input [31:0] edge_2_c,
    input [3:0] edge_3_u, edge_3_v,
    input [31:0] edge_3_c,
    input [3:0] edge_4_u, edge_4_v,
    input [31:0] edge_4_c,
    input [3:0] edge_5_u, edge_5_v,
    input [31:0] edge_5_c,
    input [2:0] valid_edges_count,
    input [4:0] alpha,
    input [2:0] node_count,
    output reg [63:0] result,
    output reg valid
);

    typedef struct {
        logic [3:0] u;
        logic [3:0] v;
        logic [31:0] c;
    } edge_t;

    edge_t edges [0:5];
    logic [5:0] subset;
    logic [3:0] degree [0:3];
    logic [63:0] min_energy;
    logic [31:0] max_c;
    logic [5:0] edge_index;
    logic [1:0] state;
    logic [5:0] subset_counter;

    parameter IDLE = 2'b00;
    parameter WAIT_START = 2'b01;
    parameter ITERATE_SUBSETS = 2'b10;
    parameter DONE = 2'b11;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            result <= 64'hFFFFFFFFFFFFFFFF;
            min_energy <= 64'hFFFFFFFFFFFFFFFF;
            subset_counter <= 0;
            edge_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= WAIT_START;
                        valid <= 0;
                        min_energy <= 64'hFFFFFFFFFFFFFFFF;
                        subset_counter <= 0;
                        edge_index <= 0;
                    end
                end
                WAIT_START: begin
                    state <= ITERATE_SUBSETS;
                    subset <= 0;
                    edge_index <= 0;
                    for (int i = 0; i < 4; i++) degree[i] <= 0;
                end
                ITERATE_SUBSETS: begin
                    if (edge_index == 0) begin
                        for (int i = 0; i < 4; i++) degree[i] <= 0;
                        max_c <= 0;
                    end
                    if (edge_index < valid_edges_count) begin
                        if (subset[edge_index]) begin
                            degree[edges[edge_index].u] <= degree[edges[edge_index].u] + 1;
                            degree[edges[edge_index].v] <= degree[edges[edge_index].v] + 1;
                            if (edges[edge_index].c > max_c) max_c <= edges[edge_index].c;
                        end
                        edge_index <= edge_index + 1;
                    end else begin
                        logic is_cycle = 1;
                        logic all_degrees_two = 1;
                        for (int i = 0; i < node_count; i++) begin
                            if (degree[i] != 2) all_degrees_two = 0;
                        end
                        if (all_degrees_two) begin
                            logic [63:0] energy = (max_c * max_c) + (alpha * valid_edges_count);
                            if (energy < min_energy) min_energy <= energy;
                        end
                        if (subset_counter == (1 << valid_edges_count) - 1) begin
                            state <= DONE;
                            result <= min_energy;
                            valid <= 1;
                        end else begin
                            subset_counter <= subset_counter + 1;
                            subset <= subset_counter;
                            edge_index <= 0;
                        end
                    end
                end
                DONE: begin
                    if (start) begin
                        state <= WAIT_START;
                        valid <= 0;
                        min_energy <= 64'hFFFFFFFFFFFFFFFF;
                        subset_counter <= 0;
                        edge_index <= 0;
                    end
                end
            endcase
        end
    end

    always @* begin
        edges[0] = '{edge_0_u, edge_0_v, edge_0_c};
        edges[1] = '{edge_1_u, edge_1_v, edge_1_c};
        edges[2] = '{edge_2_u, edge_2_v, edge_2_c};
        edges[3] = '{edge_3_u, edge_3_v, edge_3_c};
        edges[4] = '{edge_4_u, edge_4_v, edge_4_c};
        edges[5] = '{edge_5_u, edge_5_v, edge_5_c};
    end

endmodule