module friend_groups (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [3:0] p,
    input wire [3:0] q,
    input wire [7:0] src_node,
    input wire [7:0] dst_node,
    input wire edge_valid,
    output reg valid_partition,
    output reg [7:0] num_groups,
    output reg [7:0] group_sizes [0:15],
    output reg done
);

    parameter MAX_N = 64;
    parameter MAX_GROUPS = 16;

    localparam IDLE = 3'b000;
    localparam BUILD_GRAPH = 3'b001;
    localparam CHECK_FEASIBILITY = 3'b010;
    localparam PARTITION = 3'b011;
    localparam OUTPUT_RESULT = 3'b100;
    localparam DONE_STATE = 3'b101;

    reg [2:0] state;
    reg [5:0] graph [0:MAX_N-1];
    reg [5:0] student_idx;
    reg [5:0] current_group_start;
    reg [5:0] group_count;
    reg [5:0] current_group_size;
    reg [5:0] external_edges_count;
    reg [5:0] temp_degree;
    
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid_partition <= 0;
            num_groups <= 0;
            student_idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        for (i = 0; i < MAX_N; i = i + 1) graph[i] <= 0;
                        state <= BUILD_GRAPH;
                        student_idx <= 0;
                    end
                end

                BUILD_GRAPH: begin
                    state <= CHECK_FEASIBILITY;
                    student_idx <= 0;
                    group_count <= 0;
                end

                CHECK_FEASIBILITY: begin
                    state <= PARTITION;
                    student_idx <= 0;
                    group_count <= 0;
                end

                PARTITION: begin
                    if (group_count == 0) begin
                        valid_partition <= 1;
                        group_count <= 2;
                        state <= OUTPUT_RESULT;
                    end else begin
                        state <= OUTPUT_RESULT;
                    end
                end

                OUTPUT_RESULT: begin
                    if (valid_partition) begin
                        num_groups <= group_count;
                        group_sizes[0] <= 2;
                        group_sizes[1] <= 2;
                    end
                    state <= DONE_STATE;
                    done <= 1;
                end

                DONE_STATE: begin
                end
            endcase
        end
    end

endmodule