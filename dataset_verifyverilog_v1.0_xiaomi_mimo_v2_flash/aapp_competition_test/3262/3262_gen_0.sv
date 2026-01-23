module min_trucks(
    input clk,
    input rst_n,
    input start,
    input [3:0] C,        // Number of clients (1-8)
    input [63:0] reach,   // Reachability matrix: bit i*8+j = 1 if truck can go from client i to client j
    output reg [3:0] result,
    output reg done
);

// Internal memory for DP (256 x 4 bits)
reg [3:0] dp0 [0:255];  // Current DP state
reg [3:0] dp1 [0:255];  // Next DP state

// State machine states
localparam [3:0] IDLE = 4'd0;
localparam [3:0] INIT = 4'd1;
localparam [3:0] LOOP_I = 4'd2;
localparam [3:0] COPY_DP = 4'd3;
localparam [3:0] INNER_MASK = 4'd4;
localparam [3:0] INNER_J = 4'd5;
localparam [3:0] COPY_BACK = 4'd6;
localparam [3:0] FIND_MAX = 4'd7;
localparam [3:0] DONE = 4'd8;

reg [3:0] state;
reg [2:0] i;           // Current client index (0-7)
reg [7:0] mask;        // Current mask for right nodes
reg [2:0] j;           // Current right node index
reg [3:0] max_match;   // Maximum matching found
reg [7:0] addr;        // Memory address counter
reg [3:0] temp_val;    // Temporary storage
reg temp_update;       // Flag to update dp1

// Helper: Check if bit is set in reach matrix
wire edge_ij = reach[i*8 + j];

// Helper: Check if right node j is in mask
wire mask_has_j = mask[j];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 4'd0;
        i <= 3'd0;
        mask <= 8'd0;
        j <= 3'd0;
        max_match <= 4'd0;
        addr <= 8'd0;
        temp_val <= 4'd0;
        temp_update <= 1'b0;
        // Reset DP memories
        for (addr = 0; addr < 256; addr = addr + 1) begin
            dp0[addr] <= 4'd0;
            dp1[addr] <= 4'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT;
                    i <= 3'd0;
                    addr <= 8'd0;
                end
            end

            INIT: begin
                // Initialize dp0[0] = 0, others = 0 (already reset)
                if (addr == 8'd255) begin
                    dp0[8'd0] <= 4'd0;  // Ensure first is zero
                    state <= LOOP_I;
                end else begin
                    addr <= addr + 8'd1;
                end
            end

            LOOP_I: begin
                if (i >= C) begin
                    state <= FIND_MAX;
                    addr <= 8'd0;
                    max_match <= 4'd0;
                end else begin
                    state <= COPY_DP;
                    addr <= 8'd0;
                end
            end

            COPY_DP: begin
                // Copy dp0 to dp1
                dp1[addr] <= dp0[addr];
                if (addr == 8'd255) begin
                    state <= INNER_MASK;
                    mask <= 8'd0;
                end else begin
                    addr <= addr + 8'd1;
                end
            end

            INNER_MASK: begin
                if (mask == 8'hFF) begin
                    state <= SWAP_DP;
                end else begin
                    j <= 3'd0;
                    state <= INNER_J;
                    temp_update <= 1'b0;
                end
            end

            INNER_J: begin
                if (j >= C) begin
                    mask <= mask + 8'd1;
                    state <= INNER_MASK;
                end else if (!mask_has_j && edge_ij) begin
                    // Found valid edge: try to update dp1[mask | (1<<j)]
                    // Only if dp0[mask] is valid or mask == 0
                    if (dp0[mask] != 4'd0 || mask == 8'd0) begin
                        temp_val <= dp0[mask] + 4'd1;
                        if (dp0[mask] + 4'd1 > dp1[mask | (8'd1 << j)]) begin
                            temp_update <= 1'b1;
                        end
                    end
                    j <= j + 3'd1;
                end else begin
                    j <= j + 3'd1;
                end
            end

            // Update state when we need to update dp1
            SWAP_DP: begin
                // Copy dp1 back to dp0 for next iteration
                addr <= 8'd0;
                state <= COPY_BACK;
            end

            COPY_BACK: begin
                dp0[addr] <= dp1[addr];
                if (addr == 8'd255) begin
                    i <= i + 3'd1;
                    state <= LOOP_I;
                end else begin
                    addr <= addr + 8'd1;
                end
            end

            FIND_MAX: begin
                // Find maximum value in dp0
                if (addr == 8'd255) begin
                    // Done searching
                    result <= C - max_match;
                    state <= DONE;
                end else begin
                    if (dp0[addr] > max_match)
                        max_match <= dp0[addr];
                    addr <= addr + 8'd1;
                end
            end

            DONE: begin
                done <= 1'b1;
                if (!start) begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            end

            default: state <= IDLE;
        endcase
        
        // Handle dp1 update when temp_update is set
        if (temp_update && state == INNER_J) begin
            dp1[mask | (8'd1 << j)] <= temp_val;
            temp_update <= 1'b0;
        end
    end
end

endmodule