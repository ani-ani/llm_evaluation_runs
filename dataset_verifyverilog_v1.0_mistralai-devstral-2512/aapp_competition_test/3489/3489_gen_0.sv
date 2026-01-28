module EdgeConnectivity(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] h,
    input [3:0] edge_a,
    input [3:0] edge_b,
    input edge_valid,
    output reg [3:0] m,
    output reg [3:0] edge_out_a,
    output reg [3:0] edge_out_b,
    output reg out_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INGEST = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] edge_count;
    reg [3:0] degree [0:15];
    reg [3:0] leaf_list [0:15];
    reg [3:0] leaf_count;
    reg [3:0] current_leaf;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    integer i;

    // Initialize degrees and leaf list
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            edge_count <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
                degree[i] <= 4'd0;
                leaf_list[i] <= 4'd0;
            end
            leaf_count <= 4'd0;
            current_leaf <= 4'd0;
            m <= 4'd0;
            edge_out_a <= 4'd0;
            edge_out_b <= 4'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INGEST;
                    edge_count = 8'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        degree[i] = 4'd0;
                        leaf_list[i] = 4'd0;
                    end
                    leaf_count = 4'd0;
                    current_leaf = 4'd0;
                    m = 4'd0;
                    edge_out_a = 4'd0;
                    edge_out_b = 4'd0;
                    out_valid = 1'b0;
                    done = 1'b0;
                    cycle_count = 8'd0;
                end
            end
            INGEST: begin
                if (edge_valid) begin
                    degree[edge_a] = degree[edge_a] + 4'd1;
                    degree[edge_b] = degree[edge_b] + 4'd1;
                    edge_count = edge_count + 8'd1;
                    if (edge_count == n - 4'd1) begin
                        next_state = PROCESS;
                    end
                end
            end
            PROCESS: begin
                leaf_count = 4'd0;
                for (i = 0; i < 16; i = i + 1) begin
                    if (degree[i] == 4'd1 && i != h) begin
                        leaf_list[leaf_count] = i;
                        leaf_count = leaf_count + 4'd1;
                    end
                end
                m = leaf_count;
                current_leaf = 4'd0;
                next_state = OUTPUT;
            end
            OUTPUT: begin
                if (current_leaf < leaf_count) begin
                    edge_out_a = leaf_list[current_leaf];
                    edge_out_b = h;
                    out_valid = 1'b1;
                    current_leaf = current_leaf + 4'd1;
                end else begin
                    out_valid = 1'b0;
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            if (state != IDLE && state != DONE_STATE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                end
            end
        end
    end

endmodule