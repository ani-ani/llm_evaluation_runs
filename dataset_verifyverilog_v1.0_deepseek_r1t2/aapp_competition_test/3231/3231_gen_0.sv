module friend_group_checker #(
    parameter MAX_N = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] p,
    input wire [3:0] q,
    input wire [7:0] adj [0:MAX_N-1],
    output reg done,
    output reg valid,
    output reg [2:0] group_id [0:MAX_N-1]
);

// State declarations
localparam [3:0] IDLE            = 4'd0;
localparam [3:0] PRE_COMPUTE     = 4'd1;
localparam [3:0] DP_INIT         = 4'd2;
localparam [3:0] DP_PROCESS_SIZE = 4'd3;
localparam [3:0] DP_PROCESS_MASK = 4'd4;
localparam [3:0] DP_PROCESS_SUBMASK = 4'd5;
localparam [3:0] DP_DONE         = 4'd6;
localparam [3:0] RECONSTRUCT     = 4'd7;
localparam [3:0] FINISH_VALID    = 4'd8;
localparam [3:0] FINISH_INVALID  = 4'd9;

reg [3:0] state, next_state;
reg [7:0] mask_index;
reg [3:0] current_size;
reg [7:0] current_mask;
reg [7:0] current_submask;
reg [7:0] full_mask;
reg [3:0] popcount;
reg [7:0] cross_edges;
reg [3:0] recon_group;
reg [2:0] node_idx;

// Precompute storage
reg [3:0] popcount_lut [0:255];
reg [7:0] cross_edges_lut [0:255];
reg valid_group [0:255];

// DP storage
reg dp [0:255];
reg [7:0] predecessor [0:255];

// Internal signals
wire [7:0] next_submask;
wire node_in_submask;
wire node_in_mask;
wire is_edge;

assign next_submask = (current_submask == 8'd0) ? 8'd0 : (current_submask - 8'd1);

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        state <= IDLE;
        done <= 1'b0;
        valid <= 1'b0;
        mask_index <= 8'd0;
        current_size <= 4'd0;
        current_mask <= 8'd0;
        current_submask <= 8'd0;
        full_mask <= 8'd0;
        popcount <= 4'd0;
        cross_edges <= 8'd0;
        recon_group <= 4'd0;
        node_idx <= 3'd0;

        // Initialize arrays
        for (i = 0; i < 256; i = i + 1) begin
            popcount_lut[i] <= 4'd0;
            cross_edges_lut[i] <= 8'd0;
            valid_group[i] <= 1'b0;
            dp[i] <= 1'b0;
            predecessor[i] <= 8'd0;
        end

        // Initialize group_id
        for (i = 0; i < MAX_N; i = i + 1) begin
            group_id[i] <= 3'd0;
        end
    end
    else begin
        state <= next_state;

        case (state)
            IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                if (start) begin
                    // Compute full_mask based on n
                    full_mask <= (8'd1 << n) - 8'd1;
                    mask_index <= 8'd0;
                    next_state <= PRE_COMPUTE;
                end
            end

            PRE_COMPUTE: begin
                // Compute popcount for current mask_index
                popcount = 4'd0;
                for (i = 0; i < MAX_N; i = i + 1) begin
                    popcount = popcount + {3'd0, mask_index[i]};
                end
                popcount_lut[mask_index] <= popcount;

                // Compute cross_edges
                cross_edges = 8'd0;
                for (i = 0; i < MAX_N; i = i + 1) begin
                    if (mask_index[i]) begin
                        for (int j = 0; j < MAX_N; j = j + 1) begin
                            if (!mask_index[j] && adj[i][j]) begin
                                cross_edges = cross_edges + 8'd1;
                            end
                        end
                    end
                end
                cross_edges_lut[mask_index] <= cross_edges;
                valid_group[mask_index] <= (popcount <= p) && (cross_edges <= q);

                if (mask_index == 8'd255) begin
                    next_state <= DP_INIT;
                end
                else begin
                    mask_index <= mask_index + 8'd1;
                end
            end

            DP_INIT: begin
                dp[0] <= 1'b1;
                current_size <= 4'd1;
                next_state <= DP_PROCESS_SIZE;
            end

            DP_PROCESS_SIZE: begin
                if (current_size > n) begin
                    next_state <= DP_DONE;
                end
                else begin
                    current_mask <= 8'd0;
                    next_state <= DP_PROCESS_MASK;
                end
            end

            DP_PROCESS_MASK: begin
                if (current_mask == 8'd255) begin
                    current_size <= current_size + 4'd1;
                    next_state <= DP_PROCESS_SIZE;
                end
                else begin
                    current_mask <= current_mask + 8'd1;
                    if (popcount_lut[current_mask] == current_size) begin
                        current_submask <= current_mask;
                        next_state <= DP_PROCESS_SUBMASK;
                    end
                end
            end

            DP_PROCESS_SUBMASK: begin
                if (current_submask == 8'd0) begin
                    next_state <= DP_PROCESS_MASK;
                end
                else begin
                    current_submask <= next_submask;

                    if ((current_submask & current_mask) == current_submask && 
                        current_submask != 8'd0 && 
                        valid_group[current_submask] &&
                        dp[current_mask & ~current_submask] &&
                        !dp[current_mask]) begin
                        dp[current_mask] <= 1'b1;
                        predecessor[current_mask] <= current_submask;
                        next_state <= DP_PROCESS_MASK;
                    end
                end
            end

            DP_DONE: begin
                if (dp[full_mask]) begin
                    recon_group <= 4'd0;
                    current_mask <= full_mask;
                    next_state <= RECONSTRUCT;
                end
                else begin
                    next_state <= FINISH_INVALID;
                end
            end

            RECONSTRUCT: begin
                if (current_mask == 8'd0) begin
                    next_state <= FINISH_VALID;
                end
                else begin
                    node_idx <= 3'd0;
                    next_state <= RECONSTRUCT;
                    // Assign group_id in one cycle via for-loop
                    for (i = 0; i < MAX_N; i = i + 1) begin
                        if (predecessor[current_mask][i]) begin
                            group_id[i] <= recon_group;
                        end
                    end
                    current_mask <= current_mask & ~predecessor[current_mask];
                    recon_group <= recon_group + 4'd1;
                end
            end

            FINISH_VALID: begin
                done <= 1'b1;
                valid <= 1'b1;
                next_state <= IDLE;
            end

            FINISH_INVALID: begin
                done <= 1'b1;
                valid <= 1'b0;
                next_state <= IDLE;
            end

            default: next_state <= IDLE;
        endcase
    end
end

endmodule