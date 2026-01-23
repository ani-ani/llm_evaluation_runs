module barcode_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] row0_g1,
    input wire [1:0] row0_g2,
    input wire [1:0] row1_g1,
    input wire [1:0] row1_g2,
    input wire [1:0] col0_g1,
    input wire [1:0] col0_g2,
    input wire [1:0] col1_g1,
    input wire [1:0] col1_g2,
    output reg [2:0] row0_vbars,
    output reg [2:0] row1_vbars,
    output reg [2:0] col0_hbars,
    output reg [2:0] col1_hbars,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SEARCH  = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    reg [1:0] state;
    reg [11:0] candidate;
    reg solution_found;

    // Helper function to compute groups from a 3-bit pattern
    function [3:0] compute_groups;
        input [2:0] bits;
        begin
            case (bits)
                3'b000: compute_groups = 4'b0000;
                3'b100, 3'b010, 3'b001: compute_groups = 4'b0100;
                3'b110, 3'b011: compute_groups = 4'b1000;
                3'b101: compute_groups = 4'b0101;
                3'b111: compute_groups = 4'b1100;
                default: compute_groups = 4'b0000;
            endcase
        end
    endfunction

    // Row checks
    wire [3:0] row0_groups;
    assign row0_groups = compute_groups(candidate[2:0]);
    wire row0_check;
    assign row0_check = (row0_groups == {row0_g1, row0_g2});

    wire [3:0] row1_groups;
    assign row1_groups = compute_groups(candidate[5:3]);
    wire row1_check;
    assign row1_check = (row1_groups == {row1_g1, row1_g2});

    // Column checks
    wire [2:0] H0_vec = {candidate[8], candidate[7], candidate[6]};
    wire [2:0] H1_vec = {candidate[11], candidate[10], candidate[9]};

    wire [3:0] col0_groups;
    assign col0_groups = compute_groups(H0_vec);
    wire col0_check;
    assign col0_check = (col0_groups == {col0_g1, col0_g2});

    wire [3:0] col1_groups;
    assign col1_groups = compute_groups(H1_vec);
    wire col1_check;
    assign col1_check = (col1_groups == {col1_g1, col1_g2});

    // No-touch check
    wire V0_0 = candidate[0];
    wire V0_1 = candidate[1];
    wire V0_2 = candidate[2];
    wire V1_0 = candidate[3];
    wire V1_1 = candidate[4];
    wire V1_2 = candidate[5];
    wire H0_0 = candidate[6];
    wire H1_0 = candidate[7];
    wire H2_0 = candidate[8];
    wire H0_1 = candidate[9];
    wire H1_1 = candidate[10];
    wire H2_1 = candidate[11];

    wire [1:0] sum00 = V0_0 + H0_0;
    wire [1:0] sum10 = V0_1 + H0_0 + H0_1;
    wire [1:0] sum20 = V0_2 + H0_1;
    wire [1:0] sum01 = V0_0 + V1_0 + H1_0;
    wire [1:0] sum11 = V0_1 + V1_1 + H1_0 + H1_1;
    wire [1:0] sum21 = V0_2 + V1_2 + H1_1;
    wire [1:0] sum02 = V1_0 + H2_0;
    wire [1:0] sum12 = V1_1 + H2_0 + H2_1;
    wire [1:0] sum22 = V1_2 + H2_1;

    wire touch_valid;
    assign touch_valid = 
        (sum00 <= 2'd1) &&
        (sum10 <= 2'd1) &&
        (sum20 <= 2'd1) &&
        (sum01 <= 2'd1) &&
        (sum11 <= 2'd1) &&
        (sum21 <= 2'd1) &&
        (sum02 <= 2'd1) &&
        (sum12 <= 2'd1) &&
        (sum22 <= 2'd1);

    wire valid_candidate;
    assign valid_candidate = row0_check && row1_check && col0_check && col1_check && touch_valid;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            candidate <= 12'd0;
            done <= 1'b0;
            solution_found <= 1'b0;
            row0_vbars <= 3'd0;
            row1_vbars <= 3'd0;
            col0_hbars <= 3'd0;
            col1_hbars <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    solution_found <= 1'b0;
                    if (start) begin
                        state <= SEARCH;
                        candidate <= 12'd0;
                    end
                end

                SEARCH: begin
                    if (valid_candidate && !solution_found) begin
                        row0_vbars <= candidate[2:0];
                        row1_vbars <= candidate[5:3];
                        col0_hbars <= H0_vec;
                        col1_hbars <= H1_vec;
                        solution_found <= 1'b1;
                        done <= 1'b1;
                        state <= DONE;
                    end else if (candidate == 12'hFFF) begin
                        done <= 1'b1;
                        state <= DONE;
                    end else begin
                        candidate <= candidate + 12'd1;
                    end
                end

                DONE: begin
                    // Keep done high until reset
                    state <= DONE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule