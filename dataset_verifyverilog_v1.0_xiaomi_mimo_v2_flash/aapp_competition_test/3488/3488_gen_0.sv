module find_min_vertices #(
    parameter N = 8,          // Maximum number of vertices (≤ 8)
    parameter K = 8,          // Maximum number of points (≤ 8)
    parameter DATA_WIDTH = 16 // Width of coordinate values
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg done,
    output reg [3:0] min_vertices,
    // Vertex coordinates (assumed in counter‑clockwise order)
    input wire [DATA_WIDTH-1:0] vertex_x [0:N-1],
    input wire [DATA_WIDTH-1:0] vertex_y [0:N-1],
    // Point coordinates (all strictly inside the original polygon)
    input wire [DATA_WIDTH-1:0] point_x [0:K-1],
    input wire [DATA_WIDTH-1:0] point_y [0:K-1]
);

    // State encoding
    localparam [2:0] IDLE          = 3'b000;
    localparam [2:0] INIT          = 3'b001;
    localparam [2:0] START_PASS    = 3'b010;
    localparam [2:0] CHECK_VERTEX  = 3'b011;
    localparam [2:0] VALIDATE      = 3'b100;
    localparam [2:0] UPDATE_MASK   = 3'b101;
    localparam [2:0] NEXT_VERTEX   = 3'b110;
    localparam [2:0] FINISHED      = 3'b111;

    reg [2:0]  state;
    reg [7:0]  mask;            // Current set of vertices (bit i = 1 if vertex i is present)
    reg [3:0]  scan_idx;         // Current vertex being tested for removal
    reg [3:0]  best;             // Current best (minimum) number of vertices
    reg        validation_pass;  // Result of validity test for candidate mask

    // Registers for edge and point iteration
    reg [3:0]  edge_i, edge_j;   // Current edge: from vertex i to vertex j
    reg [3:0]  point_idx;        // Current point being tested
    reg        edge_valid;       // True if current edge is valid for all points so far
    reg [3:0]  first_sel;        // First selected vertex in the cyclic order
    reg [3:0]  prev_sel;         // Previously processed selected vertex
    reg        found_first;      // Flag that first selected vertex has been found
    reg [3:0]  edge_count;       // Number of edges processed for current mask
    reg [7:0]  candidate_mask;   // Temporary mask for validation

    // Cross product computation (signed)
    wire signed [2*DATA_WIDTH:0] dx = $signed(vertex_x[edge_j]) - $signed(vertex_x[edge_i]);
    wire signed [2*DATA_WIDTH:0] dy = $signed(vertex_y[edge_j]) - $signed(vertex_y[edge_i]);
    wire signed [2*DATA_WIDTH:0] px = $signed(point_x[point_idx]) - $signed(vertex_x[edge_i]);
    wire signed [2*DATA_WIDTH:0] py = $signed(point_y[point_idx]) - $signed(vertex_y[edge_i]);
    wire signed [2*DATA_WIDTH:0] cross = dx * py - dy * px;

    // Helper: population count (number of set bits)
    function automatic [3:0] popcount;
        input [7:0] val;
        integer k;
        begin
            popcount = 0;
            for (k = 0; k < N; k = k + 1)
                if (val[k]) popcount = popcount + 1;
        end
    endfunction

    // Helper: find next selected vertex after 'cur' in cyclic order
    function automatic [3:0] next_selected;
        input [7:0] m;
        input [3:0] cur;
        integer k;
        begin
            next_selected = cur; // default
            for (k = cur + 1; k < N; k = k + 1)
                if (m[k]) begin next_selected = k; end
            for (k = 0; k <= cur; k = k + 1)
                if (m[k]) begin next_selected = k; end
        end
    endfunction

    // Helper: find first selected vertex
    function automatic [3:0] first_selected;
        input [7:0] m;
        integer k;
        begin
            first_selected = 0;
            for (k = 0; k < N; k = k + 1)
                if (m[k]) begin first_selected = k; end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= IDLE;
            done             <= 1'b0;
            min_vertices     <= N;
            best             <= N;
            mask             <= 0;
            scan_idx         <= 0;
            validation_pass  <= 1'b0;
            edge_i           <= 0;
            edge_j           <= 0;
            point_idx        <= 0;
            edge_valid       <= 1'b0;
            first_sel        <= 0;
            prev_sel         <= 0;
            found_first      <= 1'b0;
            edge_count       <= 0;
            candidate_mask   <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) state <= INIT;
                end

                INIT: begin
                    // Start with all vertices present
                    mask <= 8'b11111111;
                    best <= N;
                    scan_idx <= 0;
                    state <= START_PASS;
                end

                START_PASS: begin
                    // Begin a new pass over all vertices
                    if (scan_idx >= N) begin
                        // No vertex removed in this pass -> finish
                        if (best == popcount(mask)) state <= FINISHED;
                        else begin
                            best <= popcount(mask);
                            scan_idx <= 0;
                            state <= START_PASS;
                        end
                    end else begin
                        if (mask[scan_idx]) state <= CHECK_VERTEX;
                        else state <= NEXT_VERTEX;
                    end
                end

                CHECK_VERTEX: begin
                    // Prepare candidate mask without scan_idx
                    candidate_mask <= mask & ~(1 << scan_idx);
                    // Validate candidate mask in VALIDATE state
                    state <= VALIDATE;
                    // Initialize validation state
                    found_first <= 1'b0;
                    edge_valid <= 1'b1;
                    edge_count <= 0;
                end

                VALIDATE: begin
                    // Sub‑state machine to validate candidate mask
                    if (!found_first) begin
                        first_sel <= first_selected(candidate_mask);
                        prev_sel <= first_sel;
                        found_first <= 1'b1;
                        edge_i <= first_sel;
                        edge_j <= next_selected(candidate_mask, first_sel);
                        point_idx <= 0;
                        edge_valid <= 1'b1;
                        state <= VALIDATE; // stay in this sub‑state
                    end else if (edge_count < popcount(candidate_mask)) begin
                        // Check current edge against all points
                        if (point_idx < K) begin
                            if (cross > 0) begin
                                point_idx <= point_idx + 1;
                            end else begin
                                edge_valid <= 1'b0;
                                // Early exit: this edge invalid
                                validation_pass <= 1'b0;
                                state <= UPDATE_MASK;
                            end
                        end else begin
                            // All points passed for this edge
                            if (!edge_valid) begin
                                validation_pass <= 1'b0;
                                state <= UPDATE_MASK;
                            end else begin
                                // Move to next edge
                                edge_count <= edge_count + 1;
                                prev_sel <= edge_j;
                                edge_i <= edge_j;
                                edge_j <= next_selected(candidate_mask, edge_j);
                                point_idx <= 0;
                                state <= VALIDATE;
                            end
                        end
                    end else begin
                        // All edges passed
                        validation_pass <= 1'b1;
                        state <= UPDATE_MASK;
                    end
                end

                UPDATE_MASK: begin
                    if (validation_pass) begin
                        // Remove vertex scan_idx
                        mask[scan_idx] <= 1'b0;
                        best <= popcount(mask) - 1;
                        // Restart scan from beginning
                        scan_idx <= 0;
                        state <= START_PASS;
                    end else begin
                        // Cannot remove this vertex
                        state <= NEXT_VERTEX;
                    end
                end

                NEXT_VERTEX: begin
                    scan_idx <= scan_idx + 1;
                    state <= START_PASS;
                end

                FINISHED: begin
                    min_vertices <= popcount(mask);
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule