module forest_constructor (
    input clk,
    input rst_n,
    input start,
    input [3:0] V,
    input [7:0] target_degree [0:7],
    output reg valid,
    output reg [3:0] edge_u [0:13],
    output reg [3:0] edge_v [0:13],
    output reg [4:0] edge_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] CHECK_SUM = 3'b001;
    localparam [2:0] CHECK_ROOT = 3'b010;
    localparam [2:0] BUILD_ROOT = 3'b011;
    localparam [2:0] BUILD_LOOP = 3'b100;
    localparam [2:0] COLLECT = 3'b101;
    localparam [2:0] LINK = 3'b110;
    localparam [2:0] FINISH = 3'b111;

    reg [2:0] state;
    reg [7:0] work_degree [0:7];
    reg [3:0] root_index;
    reg [3:0] list [0:7];
    reg [3:0] list_len;
    reg [3:0] i, j, k;
    reg [7:0] sum_degrees;
    reg [3:0] non_zero_count;
    reg [3:0] temp_root;
    reg [3:0] max_degree;
    reg [3:0] current_node;
    reg [3:0] edge_ptr;
    reg [3:0] link_ptr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            done <= 0;
            edge_count <= 0;
            for (i = 0; i < 14; i = i + 1) begin
                edge_u[i] <= 0;
                edge_v[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CHECK_SUM;
                        sum_degrees <= 0;
                        non_zero_count <= 0;
                        for (i = 0; i < 8; i = i + 1) begin
                            work_degree[i] <= target_degree[i];
                            if (target_degree[i] > 0) begin
                                non_zero_count <= non_zero_count + 1;
                            end
                            sum_degrees <= sum_degrees + target_degree[i];
                        end
                    end
                end
                CHECK_SUM: begin
                    if (V == 0) begin
                        valid <= 1;
                        edge_count <= 0;
                        state <= FINISH;
                    end else if (V == 1) begin
                        valid <= (target_degree[0] == 0);
                        edge_count <= 0;
                        state <= FINISH;
                    end else begin
                        if (sum_degrees % 2 == 1) begin
                            valid <= 0;
                            state <= FINISH;
                        end else if (sum_degrees == 0) begin
                            valid <= 1;
                            edge_count <= 0;
                            state <= FINISH;
                        end else if (sum_degrees > 2 * (V - 1)) begin
                            valid <= 0;
                            state <= FINISH;
                        end else begin
                            state <= CHECK_ROOT;
                        end
                    end
                end
                CHECK_ROOT: begin
                    max_degree <= 0;
                    temp_root <= 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (work_degree[i] > max_degree) begin
                            max_degree <= work_degree[i];
                            temp_root <= i;
                        end
                    end
                    if (max_degree == 0) begin
                        valid <= 1;
                        edge_count <= 0;
                        state <= FINISH;
                    end else begin
                        root_index <= temp_root;
                        state <= BUILD_ROOT;
                        i <= 0;
                        edge_ptr <= 0;
                    end
                end
                BUILD_ROOT: begin
                    if (i < 8) begin
                        if (i != root_index && work_degree[i] > 1) begin
                            state <= BUILD_LOOP;
                            current_node <= i;
                        end else begin
                            i <= i + 1;
                        end
                    end else begin
                        state <= COLLECT;
                        list_len <= 0;
                        j <= 0;
                    end
                end
                BUILD_LOOP: begin
                    if (work_degree[root_index] == 0) begin
                        valid <= 0;
                        state <= FINISH;
                    end else begin
                        edge_u[edge_ptr] <= root_index;
                        edge_v[edge_ptr] <= current_node;
                        edge_ptr <= edge_ptr + 1;
                        work_degree[root_index] <= work_degree[root_index] - 1;
                        work_degree[current_node] <= work_degree[current_node] - 1;
                        if (work_degree[current_node] > 1) begin
                            // Continue with same node
                        end else begin
                            state <= BUILD_ROOT;
                            i <= i + 1;
                        end
                    end
                end
                COLLECT: begin
                    if (j < 8) begin
                        if (work_degree[j] == 1) begin
                            list[list_len] <= j;
                            list_len <= list_len + 1;
                        end
                        j <= j + 1;
                    end else begin
                        if (list_len % 2 == 1) begin
                            valid <= 0;
                            state <= FINISH;
                        end else if (list_len == 0) begin
                            valid <= 1;
                            edge_count <= edge_ptr;
                            state <= FINISH;
                        end else begin
                            state <= LINK;
                            link_ptr <= 0;
                        end
                    end
                end
                LINK: begin
                    if (work_degree[root_index] == 1) begin
                        if (link_ptr < list_len) begin
                            if (link_ptr == 0) begin
                                edge_u[edge_ptr] <= root_index;
                                edge_v[edge_ptr] <= list[link_ptr];
                                edge_ptr <= edge_ptr + 1;
                                link_ptr <= link_ptr + 1;
                            end else begin
                                edge_u[edge_ptr] <= list[link_ptr];
                                edge_v[edge_ptr] <= list[link_ptr + 1];
                                edge_ptr <= edge_ptr + 1;
                                link_ptr <= link_ptr + 2;
                            end
                        end else begin
                            valid <= 1;
                            edge_count <= edge_ptr;
                            state <= FINISH;
                        end
                    end else begin
                        if (link_ptr < list_len) begin
                            edge_u[edge_ptr] <= list[link_ptr];
                            edge_v[edge_ptr] <= list[link_ptr + 1];
                            edge_ptr <= edge_ptr + 1;
                            link_ptr <= link_ptr + 2;
                        end else begin
                            valid <= 1;
                            edge_count <= edge_ptr;
                            state <= FINISH;
                        end
                    end
                end
                FINISH: begin
                    done <= 1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule