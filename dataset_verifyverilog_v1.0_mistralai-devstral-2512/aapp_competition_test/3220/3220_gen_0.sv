module wizard_dance(
    input clk,
    input rst_n,
    input start,
    input [3:0] p_0,
    input [3:0] p_1,
    input [3:0] p_2,
    input [3:0] p_3,
    input [3:0] p_4,
    input [3:0] p_5,
    input [3:0] p_6,
    input [3:0] p_7,
    output reg [63:0] result_packed,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] ITERATE = 3'd1;
    localparam [2:0] DONE    = 3'd2;

    // Internal registers
    reg [2:0] state;
    reg [7:0] mask;
    reg [7:0] best_mask;
    reg [63:0] best_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Position calculation
    wire [2:0] pos_0 = (mask[0] == 1'b0) ? (3'd0 - p_0[2:0]) % 8 : (3'd0 + p_0[2:0]) % 8;
    wire [2:0] pos_1 = (mask[1] == 1'b0) ? (3'd1 - p_1[2:0]) % 8 : (3'd1 + p_1[2:0]) % 8;
    wire [2:0] pos_2 = (mask[2] == 1'b0) ? (3'd2 - p_2[2:0]) % 8 : (3'd2 + p_2[2:0]) % 8;
    wire [2:0] pos_3 = (mask[3] == 1'b0) ? (3'd3 - p_3[2:0]) % 8 : (3'd3 + p_3[2:0]) % 8;
    wire [2:0] pos_4 = (mask[4] == 1'b0) ? (3'd4 - p_4[2:0]) % 8 : (3'd4 + p_4[2:0]) % 8;
    wire [2:0] pos_5 = (mask[5] == 1'b0) ? (3'd5 - p_5[2:0]) % 8 : (3'd5 + p_5[2:0]) % 8;
    wire [2:0] pos_6 = (mask[6] == 1'b0) ? (3'd6 - p_6[2:0]) % 8 : (3'd6 + p_6[2:0]) % 8;
    wire [2:0] pos_7 = (mask[7] == 1'b0) ? (3'd7 - p_7[2:0]) % 8 : (3'd7 + p_7[2:0]) % 8;

    // Collision check
    wire collision = (pos_0 == pos_1) || (pos_0 == pos_2) || (pos_0 == pos_3) ||
                     (pos_0 == pos_4) || (pos_0 == pos_5) || (pos_0 == pos_6) || (pos_0 == pos_7) ||
                     (pos_1 == pos_2) || (pos_1 == pos_3) || (pos_1 == pos_4) || (pos_1 == pos_5) ||
                     (pos_1 == pos_6) || (pos_1 == pos_7) || (pos_2 == pos_3) || (pos_2 == pos_4) ||
                     (pos_2 == pos_5) || (pos_2 == pos_6) || (pos_2 == pos_7) || (pos_3 == pos_4) ||
                     (pos_3 == pos_5) || (pos_3 == pos_6) || (pos_3 == pos_7) || (pos_4 == pos_5) ||
                     (pos_4 == pos_6) || (pos_4 == pos_7) || (pos_5 == pos_6) || (pos_5 == pos_7) ||
                     (pos_6 == pos_7);

    // Result generation
    wire [7:0] char_0 = (mask[0] == 1'b0) ? 8'd76 : 8'd82;
    wire [7:0] char_1 = (mask[1] == 1'b0) ? 8'd76 : 8'd82;
    wire [7:0] char_2 = (mask[2] == 1'b0) ? 8'd76 : 8'd82;
    wire [7:0] char_3 = (mask[3] == 1'b0) ? 8'd76 : 8'd82;
    wire [7:0] char_4 = (mask[4] == 1'b0) ? 8'd76 : 8'd82;
    wire [7:0] char_5 = (mask[5] == 1'b0) ? 8'd76 : 8'd82;
    wire [7:0] char_6 = (mask[6] == 1'b0) ? 8'd76 : 8'd82;
    wire [7:0] char_7 = (mask[7] == 1'b0) ? 8'd76 : 8'd82;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask <= 8'd0;
            best_mask <= 8'd0;
            best_result <= 64'd0;
            result_packed <= 64'd0;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= ITERATE;
                        mask <= 8'd0;
                        best_mask <= 8'd0;
                        best_result <= 64'd0;
                        cycle_count <= 8'd0;
                    end
                end

                ITERATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (!collision) begin
                        if (best_mask == 8'd0 || mask < best_mask) begin
                            best_mask <= mask;
                            best_result <= {char_7, char_6, char_5, char_4, char_3, char_2, char_1, char_0};
                        end
                    end

                    if (mask == 8'd255 || cycle_count >= MAX_CYCLES) begin
                        if (best_mask != 8'd0) begin
                            result_packed <= best_result;
                            valid <= 1'b1;
                        end else begin
                            result_packed <= 64'd0;
                            valid <= 1'b0;
                        end
                        state <= DONE;
                    end else begin
                        mask <= mask + 8'd1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule