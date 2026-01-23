module lounge_planner(
    input clk,
    input rst_n,
    input start,
    input [2:0] node_count,
    input [2:0] edge_count,
    input [4:0] edge_index,
    input [2:0] edge_a,
    input [2:0] edge_b,
    input [1:0] edge_c,
    input edge_load,
    output reg [7:0] min_lounges,
    output reg valid,
    output reg impossible,
    output reg loading_done
);

    parameter MAX_NODES = 8;
    parameter MAX_EDGES = 20;
    parameter MAX_ASSIGNMENTS = 256;

    typedef enum logic [1:0] {
        IDLE,
        LOADING,
        SOLVING,
        DONE
    } state_t;

    state_t state, next_state;

    reg [4:0] edge_ptr;
    reg [2:0] edge_a_mem [0:MAX_EDGES-1];
    reg [2:0] edge_b_mem [0:MAX_EDGES-1];
    reg [1:0] edge_c_mem [0:MAX_EDGES-1];

    reg [7:0] assignment;
    reg [7:0] min_found;
    reg [7:0] current_count;
    reg [7:0] lounge_count;

    reg [4:0] edge_idx;
    reg all_valid;
    reg [7:0] temp_min;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            edge_ptr <= 0;
            assignment <= 0;
            min_found <= 8'hFF;
            current_count <= 0;
            lounge_count <= 0;
            edge_idx <= 0;
            all_valid <= 0;
            temp_min <= 8'hFF;
            min_lounges <= 0;
            valid <= 0;
            impossible <= 0;
            loading_done <= 0;
            for (int i = 0; i < MAX_EDGES; i++) begin
                edge_a_mem[i] <= 0;
                edge_b_mem[i] <= 0;
                edge_c_mem[i] <= 0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= LOADING;
                    end
                end

                LOADING: begin
                    if (edge_load) begin
                        if (edge_index < edge_count) begin
                            edge_a_mem[edge_index] <= edge_a - 1;
                            edge_b_mem[edge_index] <= edge_b - 1;
                            edge_c_mem[edge_index] <= edge_c;
                        end
                        if (edge_index == edge_count - 1) begin
                            loading_done <= 1;
                        end
                    end else if (loading_done) begin
                        next_state <= SOLVING;
                        assignment <= 0;
                        min_found <= 8'hFF;
                        edge_idx <= 0;
                        all_valid <= 1;
                    end
                end

                SOLVING: begin
                    if (assignment == MAX_ASSIGNMENTS - 1) begin
                        next_state <= DONE;
                        if (min_found == 8'hFF) begin
                            impossible <= 1;
                            valid <= 1;
                        end else begin
                            min_lounges <= min_found;
                            valid <= 1;
                        end
                    end else begin
                        assignment <= assignment + 1;
                        edge_idx <= 0;
                        all_valid <= 1;
                        lounge_count <= $clog2(assignment);
                    end
                end

                DONE: begin
                    if (!start) begin
                        next_state <= IDLE;
                        loading_done <= 0;
                        valid <= 0;
                        impossible <= 0;
                    end
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            SOLVING: begin
                if (edge_idx < edge_count) begin
                    reg [1:0] c = edge_c_mem[edge_idx];
                    reg [2:0] a = edge_a_mem[edge_idx];
                    reg [2:0] b = edge_b_mem[edge_idx];
                    reg valid_edge = 0;

                    if (c == 0) begin
                        valid_edge = (assignment[a] == 0 && assignment[b] == 0);
                    end else if (c == 1) begin
                        valid_edge = (assignment[a] ^ assignment[b]);
                    end else if (c == 2) begin
                        valid_edge = (assignment[a] == 1 && assignment[b] == 1);
                    end

                    all_valid = all_valid && valid_edge;
                    edge_idx = edge_idx + 1;
                end else begin
                    if (all_valid) begin
                        temp_min = (lounge_count < min_found) ? lounge_count : min_found;
                    end
                end
            end
        endcase
    end

    always @(posedge clk) begin
        if (state == SOLVING && edge_idx == edge_count) begin
            if (all_valid) begin
                min_found <= temp_min;
            end
        end
    end

endmodule