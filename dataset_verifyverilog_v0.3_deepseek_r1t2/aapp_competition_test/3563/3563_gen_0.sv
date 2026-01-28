module convex_line_cover (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [11:0] x0, x1, x2, x3, x4, x5, x6, x7,
    input wire signed [11:0] y0, y1, y2, y3, y4, y5, y6, y7,
    output reg [3:0] result,
    output reg done
);
    // Parameters
    parameter COORD_WIDTH = 12;
    parameter MAX_N = 8;
    parameter RESULT_WIDTH = 4;
    localparam INF = 15;

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_LINES_INIT = 4'd1;
    localparam [3:0] COMPUTE_LINES_INNER = 4'd2;
    localparam [3:0] COMPUTE_LINES_STORE = 4'd3;
    localparam [3:0] COMPUTE_LINES_NEXT = 4'd4;
    localparam [3:0] DP_INIT = 4'd5;
    localparam [3:0] DP_UPDATE_LOAD_LINE = 4'd6;
    localparam [3:0] DP_COPY = 4'd7;
    localparam [3:0] DP_UPDATE_MASKS_INIT = 4'd8;
    localparam [3:0] DP_UPDATE_MASKS = 4'd9;
    localparam [3:0] DP_TOGGLE_BUFFER = 4'd10;
    localparam [3:0] DP_DONE = 4'd11;

    // Registers
    reg [3:0] state, next_state;
    reg [3:0] n_reg;
    reg signed [11:0] x_reg [0:7];
    reg signed [11:0] y_reg [0:7];
    reg [2:0] i_reg, j_reg, k_reg;
    reg [7:0] line_mask;
    reg [4:0] line_count;
    reg [7:0] line_mem [0:27];
    reg [3:0] dp_buffer0 [0:255];
    reg [3:0] dp_buffer1 [0:255];
    reg current_buffer;
    reg [7:0] full_mask;
    reg [7:0] mask_counter;
    reg [4:0] line_idx;
    reg [3:0] i;

    // Temporary wire declarations
    wire signed [12:0] dx = x_reg[j_reg] - x_reg[i_reg];
    wire signed [12:0] dy = y_reg[j_reg] - y_reg[i_reg];
    wire signed [12:0] dxk = x_reg[k_reg] - x_reg[i_reg];
    wire signed [12:0] dyk = y_reg[k_reg] - y_reg[i_reg];
    wire signed [25:0] cross = dx * dyk - dy * dxk;

    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            line_count <= 5'd0;
            current_buffer <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                x_reg[i] <= 12'd0;
                y_reg[i] <= 12'd0;
            end
            for (i = 0; i < 256; i = i + 1) begin
                dp_buffer0[i] <= INF;
                dp_buffer1[i] <= INF;
            end
            dp_buffer0[0] <= 4'd0;
            dp_buffer1[0] <= 4'd0;
            for (i = 0; i < 28; i = i + 1)
                line_mem[i] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Capture inputs
                        n_reg <= n;
                        x_reg[0] <= x0; x_reg[1] <= x1; x_reg[2] <= x2; x_reg[3] <= x3;
                        x_reg[4] <= x4; x_reg[5] <= x5; x_reg[6] <= x6; x_reg[7] <= x7;
                        y_reg[0] <= y0; y_reg[1] <= y1; y_reg[2] <= y2; y_reg[3] <= y3;
                        y_reg[4] <= y4; y_reg[5] <= y5; y_reg[6] <= y6; y_reg[7] <= y7;
                        line_count <= 5'd0;
                        state <= COMPUTE_LINES_INIT;
                    end
                end

                COMPUTE_LINES_INIT: begin
                    i_reg <= 3'd0;
                    j_reg <= 3'd1;
                    state <= COMPUTE_LINES_INNER;
                end

                COMPUTE_LINES_INNER: begin
                    line_mask <= 8'h01 << k_reg;
                    k_reg <= 3'd0;
                    state <= COMPUTE_LINES_STORE;
                end

                COMPUTE_LINES_STORE: begin
                    if (k_reg < n_reg) begin
                        if (cross == 0) begin
                            line_mask <= line_mask | (8'h01 << k_reg);
                        end
                        k_reg <= k_reg + 3'd1;
                    end else begin
                        // Check if line_mask has at least 2 bits set
                        if ($countones(line_mask) >= 2) begin
                            // Check for duplicates
                            reg is_dup;
                            is_dup = 0;
                            for (integer l = 0; l < line_count; l = l + 1) begin
                                if (line_mem[l] == line_mask)
                                    is_dup = 1;
                            end
                            if (!is_dup) begin
                                line_mem[line_count] <= line_mask;
                                line_count <= line_count + 5'd1;
                            end
                        end
                        state <= COMPUTE_LINES_NEXT;
                    end
                end

                COMPUTE_LINES_NEXT: begin
                    if (j_reg < (n_reg - 1)) begin
                        j_reg <= j_reg + 3'd1;
                        state <= COMPUTE_LINES_INNER;
                    end else if (i_reg < (n_reg - 2)) begin
                        i_reg <= i_reg + 3'd1;
                        j_reg <= i_reg + 3'd1;
                        state <= COMPUTE_LINES_INNER;
                    end else begin
                        state <= DP_INIT;
                        mask_counter <= 8'd0;
                    end
                end

                DP_INIT: begin
                    current_buffer <= 1'b0;
                    for (mask_counter = 8'd0; mask_counter < 8'd255; mask_counter = mask_counter + 8'd1) begin
                        dp_buffer0[mask_counter] <= (mask_counter == 0) ? 4'd0 : INF;
                    end
                    mask_counter <= 8'd0;
                    line_idx <= 5'd0;
                    if (line_count > 0)
                        state <= DP_UPDATE_LOAD_LINE;
                    else
                        state <= DP_DONE; // No lines case
                end

                DP_UPDATE_LOAD_LINE: begin
                    line_mask <= line_mem[line_idx];
                    mask_counter <= 8'd0;
                    state <= DP_COPY;
                end

                DP_COPY: begin
                    if (mask_counter < 8'd255) begin
                        if (current_buffer) begin
                            dp_buffer1[mask_counter] <= dp_buffer0[mask_counter];
                        end else begin
                            dp_buffer0[mask_counter] <= dp_buffer1[mask_counter];
                        end
                        mask_counter <= mask_counter + 8'd1;
                    end else begin
                        state <= DP_UPDATE_MASKS_INIT;
                    end
                end

                DP_UPDATE_MASKS_INIT: begin
                    mask_counter <= 8'd0;
                    state <= DP_UPDATE_MASKS;
                end

                DP_UPDATE_MASKS: begin
                    if (mask_counter < 8'd255) begin
                        reg [3:0] current_val;
                        if (current_buffer)
                            current_val = dp_buffer0[mask_counter];
                        else
                            current_val = dp_buffer1[mask_counter];
                        
                        if (current_val < INF) begin
                            wire [7:0] new_mask = mask_counter | line_mask;
                            reg [3:0] new_val = current_val + 4'd1;
                            reg [3:0] old_val;
                            if (current_buffer)
                                old_val = dp_buffer1[new_mask];
                            else
                                old_val = dp_buffer0[new_mask];
                            
                            if (new_val < old_val) begin
                                if (current_buffer)
                                    dp_buffer1[new_mask] <= new_val;
                                else
                                    dp_buffer0[new_mask] <= new_val;
                            end
                        end
                        mask_counter <= mask_counter + 8'd1;
                    end else begin
                        state <= DP_TOGGLE_BUFFER;
                    end
                end

                DP_TOGGLE_BUFFER: begin
                    current_buffer <= ~current_buffer;
                    line_idx <= line_idx + 5'd1;
                    if (line_idx < (line_count - 1)) begin
                        state <= DP_UPDATE_LOAD_LINE;
                    end else begin
                        state <= DP_DONE;
                    end
                end

                DP_DONE: begin
                    full_mask = (8'd1 << n_reg) - 1;
                    if (current_buffer)
                        result <= dp_buffer1[full_mask];
                    else
                        result <= dp_buffer0[full_mask];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule