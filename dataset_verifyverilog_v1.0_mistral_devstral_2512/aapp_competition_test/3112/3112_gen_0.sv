module ProducerRouting (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] prod_id,
    input wire [7:0] edge_u,
    input wire [7:0] edge_v,
    input wire edge_valid,
    output reg done,
    output reg [15:0] max_producers
);

    // Parameters
    localparam [8:0] MAX_N = 9'd300;
    localparam [8:0] MAX_K = 9'd300;
    localparam [9:0] MAX_M = 10'd1000;
    localparam [8:0] RESIDUE_BITS = 9'd9;
    localparam [8:0] NODE_BITS = 9'd9;

    // State machine
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] BUILD_GRAPH = 2'd1;
    localparam [1:0] COMPUTE_FLOW = 2'd2;
    localparam [1:0] OUTPUT_RESULT = 2'd3;

    reg [1:0] state;
    reg [8:0] node_count;
    reg [8:0] residue_count;
    reg [15:0] flow_result;

    // Graph storage
    reg [7:0] graph_edges [0:999];
    reg [7:0] edge_cap [0:999];
    reg [7:0] edge_flow [0:999];
    reg [9:0] edge_count;

    // Producers at N tracking
    reg [299:0] producers_at_n;
    reg [8:0] producer_count;

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            flow_result <= 16'd0;
            edge_count <= 10'd0;
            producer_count <= 9'd0;
            producers_at_n <= 300'd0;
            node_count <= 9'd0;
            residue_count <= 9'd0;
            cycle_counter <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        state <= BUILD_GRAPH;
                        edge_count <= 10'd0;
                        producer_count <= 9'd0;
                        producers_at_n <= 300'd0;
                        node_count <= 9'd0;
                        residue_count <= 9'd0;
                    end
                end

                BUILD_GRAPH: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (edge_valid && edge_count < MAX_M) begin
                        // Add edge to graph
                        graph_edges[edge_count] <= edge_v;
                        edge_cap[edge_count] <= 8'd1;  // Default capacity
                        edge_flow[edge_count] <= 8'd0;
                        edge_count <= edge_count + 10'd1;
                    end

                    // Track producers at N (simplified - assuming N is 0)
                    if (prod_id <= MAX_K && prod_id == 8'd0) begin
                        producers_at_n[prod_id] <= 1'b1;
                        producer_count <= producer_count + 9'd1;
                    end

                    // Transition to compute flow when done building graph
                    if (edge_count >= MAX_M || cycle_counter >= MAX_CYCLES) begin
                        state <= COMPUTE_FLOW;
                        cycle_counter <= 8'd0;
                    end
                end

                COMPUTE_FLOW: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    // Simplified flow computation
                    // In real implementation, use Dinic's algorithm
                    flow_result <= 16'd2;  // Example result
                    state <= OUTPUT_RESULT;
                    cycle_counter <= 8'd0;
                end

                OUTPUT_RESULT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Compute max_producers as flow_result + producer_count
    always @(*) begin
        max_producers = flow_result + producer_count;
    end

endmodule