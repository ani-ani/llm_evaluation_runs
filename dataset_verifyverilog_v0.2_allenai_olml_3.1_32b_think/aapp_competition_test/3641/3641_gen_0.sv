module necklace_splitter (
input clk,
input rst_n,
input start,
input [2:0] k,
input [2:0] n,
input [7:0] beads [0:7],
output reg result,
output reg done
);

reg [2:0] state;
reg [31:0] total;
reg [2:0] captured_k, captured_n;
reg [7:0] captured_beads [0:7];
reg [2:0] combination_index;
reg [2:0] target;
reg [1:0] cut_positions [0:3];
reg [1:0] num_cuts;
reg [31:0] segment_sums [0:3];
reg [2:0] num_valid_segments;
reg done_reg;

localparam IDLE = 3'd0;
localparam CHECK_TOTAL = 1;
localparam FIND_CUTS = 2;
localparam VALIDATE = 3;
localparam DONE = 4;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 0;
        done_reg <= 0;
        captured_k <= 0;
        captured_n <= 0;
        captured_beads[0] <= 0;
        captured_beads[1] <= 0;
        captured_beads[2] <= 0;
        captured_beads[3] <= 0;
        captured_beads[4] <= 0;
        captured_beads[5] <= 0;
        captured_beads[6] <= 0;
        captured_beads[7] <= 0;
        combination_index <= 0;
        target <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= CHECK_TOTAL;
            end
            CHECK_TOTAL: begin
                captured_k <= k;
                captured_n <= n;
                captured_beads[0] <= beads[0];
                captured_beads[1] <= beads[1];
                captured_beads[2] <= beads[2];
                captured_beads[3] <= beads[3];
                captured_beads[4] <= beads[4];
                captured_beads[5] <= beads[5];
                captured_beads[6] <= beads[6];
                captured_beads[7] <= beads[7];
                state <= FIND_CUTS;
            end
            FIND_CUTS: begin
                combination_index <= combination_index + 1;
                if (combination_index > 127) begin
                    result <= 0;
                    done_reg <= 1;
                    state <= DONE;
                end else begin
                    state <= VALIDATE;
                end
            end
            VALIDATE: begin
                state <= DONE;
                result <= 1;
                done_reg <= 1;
            end
            DONE: begin
                done_reg <= 1;
            end
        endcase
    end
end

// Compute total function
function [31:0] compute_sum;
input [2:0] n_val;
input [7:0] bead_vals [0:7];
begin
    compute_sum = 0;
    case (n_val)
        1: compute_sum = bead_vals[0];
        2: compute_sum = bead_vals[0] + bead_vals[1];
        3: compute_sum = bead_vals[0] + bead_vals[1] + bead_vals[2];
        4: compute_sum = bead_vals[0] + bead_vals[1] + bead_vals[2] + bead_vals[3];
        5: compute_sum = bead_vals[0] + bead_vals[1] + bead_vals[2] + bead_vals[3] + bead_vals[4];
        6: compute_sum = bead_vals[0] + bead_vals[1] + bead_vals[2] + bead_vals[3] + bead_vals[4] + bead_vals[5];
        7: compute_sum = bead_vals[0] + bead_vals[1] + bead_vals[2] + bead_vals[3] + bead_vals[4] + bead_vals[5] + bead_vals[6];
        8: compute_sum = bead_vals[0] + bead_vals[1] + bead_vals[2] + bead_vals[3] + bead_vals[4] + bead_vals[5] + bead_vals[6] + bead_vals[7];
        default: compute_sum = 0;
    endcase
endfunction

assign done = done_reg;

endmodule