module max_onions_protected(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] onion0_x, onion0_y,
    input wire [7:0] onion1_x, onion1_y,
    input wire [7:0] onion2_x, onion2_y,
    input wire [7:0] onion3_x, onion3_y,
    input wire [7:0] onion4_x, onion4_y,
    input wire [7:0] fence0_x, fence0_y,
    input wire [7:0] fence1_x, fence1_y,
    input wire [7:0] fence2_x, fence2_y,
    input wire [7:0] fence3_x, fence3_y,
    input wire [7:0] fence4_x, fence4_y,
    output reg [2:0] max_onions,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [2:0] max_onions_reg;
    reg [2:0] onion_idx;
    reg [2:0] inside_count;
    reg [2:0] s;
    reg [2:0] A_idx, B_idx, C_idx;
    reg [7:0] A_x, A_y, B_x, B_y, C_x, C_y;
    reg [7:0] onion_x_reg [0:4];
    reg [7:0] onion_y_reg [0:4];
    reg [7:0] fence_x_reg [0:4];
    reg [7:0] fence_y_reg [0:4];
    reg signed [15:0] AB_x, AB_y, AP_x, AP_y;
    reg signed [15:0] BC_x, BC_y, BP_x, BP_y;
    reg signed [15:0] CA_x, CA_y, CP_x, CP_y;
    reg signed [31:0] cross1, cross2, cross3;
    reg inside_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_onions_reg <= 3'd0;
            done <= 1'b0;
            onion_idx <= 3'd0;
            inside_count <= 3'd0;
            s <= 3'd0;
            A_idx <= 3'd0; B_idx <= 3'd0; C_idx <= 3'd0;
            A_x <= 8'd0; A_y <= 8'd0; B_x <= 8'd0; B_y <= 8'd0; C_x <= 8'd0; C_y <= 8'd0;
            AB_x <= 16'd0; AB_y <= 16'd0; AP_x <= 16'd0; AP_y <= 16'd0;
            BC_x <= 16'd0; BC_y <= 16'd0; BP_x <= 16'd0; BP_y <= 16'd0;
            CA_x <= 16'd0; CA_y <= 16'd0; CP_x <= 16'd0; CP_y <= 16'd0;
            cross1 <= 32'd0; cross2 <= 32'd0; cross3 <= 32'd0;
            inside_flag <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                onion_x_reg[0] = onion0_x; onion_y_reg[0] = onion0_y;
                onion_x_reg[1] = onion1_x; onion_y_reg[1] = onion1_y;
                onion_x_reg[2] = onion2_x; onion_y_reg[2] = onion2_y;
                onion_x_reg[3] = onion3_x; onion_y_reg[3] = onion3_y;
                onion_x_reg[4] = onion4_x; onion_y_reg[4] = onion4_y;
                fence_x_reg[0] = fence0_x; fence_y_reg[0] = fence0_y;
                fence_x_reg[1] = fence1_x; fence_y_reg[1] = fence1_y;
                fence_x_reg[2] = fence2_x; fence_y_reg[2] = fence2_y;
                fence_x_reg[3] = fence3_x; fence_y_reg[3] = fence3_y;
                fence_x_reg[4] = fence4_x; fence_y_reg[4] = fence4_y;
                next_state = COMPUTE;
            end
            COMPUTE: begin
                if (s == 5) begin
                    next_state = DONE_STATE;
                end else begin
                    A_idx = s;
                    case (s)
                        0: begin B_idx = 1; C_idx = 2; end
                        1: begin B_idx = 2; C_idx = 3; end
                        2: begin B_idx = 3; C_idx = 4; end
                        3: begin B_idx = 4; C_idx = 0; end
                        4: begin B_idx = 0; C_idx = 1; end
                        default: begin B_idx = 0; C_idx = 0; end
                    endcase
                    A_x = fence_x_reg[s]; A_y = fence_y_reg[s];
                    B_x = fence_x_reg[B_idx]; B_y = fence_y_reg[B_idx];
                    C_x = fence_x_reg[C_idx]; C_y = fence_y_reg[C_idx];
                    AB_x = $signed({1'b0, B_x}) - $signed({1'b0, A_x});
                    AB_y = $signed({1'b0, B_y}) - $signed({1'b0, A_y});
                    BC_x = $signed({1'b0, C_x}) - $signed({1'b0, B_x});
                    BC_y = $signed({1'b0, C_y}) - $signed({1'b0, B_y});
                    CA_x = $signed({1'b0, A_x}) - $signed({1'b0, C_x});
                    CA_y = $signed({1'b0, A_y}) - $signed({1'b0, C_y});
                    inside_count = 0;
                    onion_idx = 0;
                    next_state = COMPUTE;
                end
            end
            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (state == COMPUTE && s < 5) begin
            AP_x = $signed({1'b0, onion_x_reg[onion_idx]}) - $signed({1'b0, A_x});
            AP_y = $signed({1'b0, onion_y_reg[onion_idx]}) - $signed({1'b0, A_y});
            BP_x = $signed({1'b0, onion_x_reg[onion_idx]}) - $signed({1'b0, B_x});
            BP_y = $signed({1'b0, onion_y_reg[onion_idx]}) - $signed({1'b0, B_y});
            CP_x = $signed({1'b0, onion_x_reg[onion_idx]}) - $signed({1'b0, C_x});
            CP_y = $signed({1'b0, onion_y_reg[onion_idx]}) - $signed({1'b0, C_y});
            cross1 = $signed(AB_x) * $signed(AP_y) - $signed(AB_y) * $signed(AP_x);
            cross2 = $signed(BC_x) * $signed(BP_y) - $signed(BC_y) * $signed(BP_x);
            cross3 = $signed(CA_x) * $signed(CP_y) - $signed(CA_y) * $signed(CP_x);
            inside_flag = (cross1 < 0 && cross2 < 0 && cross3 < 0);
            if (inside_flag) begin
                inside_count = inside_count + 1;
            end
            if (onion_idx == 4) begin
                if (inside_count > max_onions_reg) begin
                    max_onions_reg = inside_count;
                end
                s = s + 1;
            else
                onion_idx = onion_idx + 1;
            end
        end
    end

    assign max_onions = max_onions_reg;

endmodule