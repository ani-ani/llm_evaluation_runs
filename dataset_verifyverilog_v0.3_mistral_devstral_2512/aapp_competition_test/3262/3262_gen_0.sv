module min_trucks(
    input clk,
    input rst_n,
    input start,
    input [3:0] C,
    input [63:0] reach,
    output reg [3:0] result,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] LOOP_I = 3'd2;
    localparam [2:0] COPY_DP = 3'd3;
    localparam [2:0] INNER_MASK = 3'd4;
    localparam [2:0] INNER_J = 3'd5;
    localparam [2:0] SWAP_DP = 3'd6;
    localparam [2:0] FIND_MAX = 3'd7;
    localparam [2:0] DONE_STATE = 3'd8;

    reg [2:0] state;
    reg [2:0] i;
    reg [7:0] mask;
    reg [2:0] j;
    reg [3:0] max_match;
    reg [7:0] addr;
    reg [3:0] temp_val;

    // DP memory (256 x 4 bits)
    reg [3:0] dp0 [0:255];
    reg [3:0] dp1 [0:255];

    // Helper wires
    wire edge_ij = reach[i*8 + j];
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

            // Initialize DP memories
            integer k;
            for (k = 0; k < 256; k = k + 1) begin
                dp0[k] <= 4'd0;
                dp1[k] <= 4'd0;
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
                    if (addr == 8'd255) begin
                        dp0[0] <= 4'd0;
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
                        addr <= 8'd0;
                    end else begin
                        j <= 3'd0;
                        state <= INNER_J;
                    end
                end

                INNER_J: begin
                    if (j >= C) begin
                        mask <= mask + 8'd1;
                        state <= INNER_MASK;
                    end else if (!mask_has_j && edge_ij) begin
                        if (dp0[mask] != 4'd0 || mask == 8'd0) begin
                            temp_val <= dp0[mask] + 4'd1;
                            if (temp_val > dp1[mask | (1 << j)]) begin
                                dp1[mask | (1 << j)] <= temp_val;
                            end
                        end
                        j <= j + 3'd1;
                    end else begin
                        j <= j + 3'd1;
                    end
                end

                SWAP_DP: begin
                    dp0[addr] <= dp1[addr];
                    if (addr == 8'd255) begin
                        i <= i + 3'd1;
                        state <= LOOP_I;
                    end else begin
                        addr <= addr + 8'd1;
                    end
                end

                FIND_MAX: begin
                    if (dp0[addr] > max_match) begin
                        max_match <= dp0[addr];
                    end
                    if (addr == 8'd255) begin
                        result <= C - max_match;
                        state <= DONE_STATE;
                    end else begin
                        addr <= addr + 8'd1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule