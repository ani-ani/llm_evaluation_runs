module NecklaceSplit(
    input clk,
    input rst_n,
    input start,
    input [3:0] k_i,
    input [3:0] n_i,
    input [15:0] bead_weights [0:15],
    output reg [0:0] result,
    output reg done
);

    // Parameters
    localparam MAX_N = 16;
    localparam BEAD_WIDTH = 16;
    localparam K_WIDTH = 4;
    localparam N_WIDTH = 4;
    localparam RESULT_WIDTH = 1;

    // States
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CALC_SUM = 4'd1;
    localparam [3:0] CHECK_DIV = 4'd2;
    localparam [3:0] TRY_START = 4'd3;
    localparam [3:0] CHECK_SEG = 4'd4;
    localparam [3:0] DONE = 4'd5;

    // Internal registers
    reg [3:0] state;
    reg [3:0] cycle_count;
    reg [3:0] start_pos;
    reg [3:0] seg_count;
    reg [3:0] bead_idx;
    reg [BEAD_WIDTH-1:0] total_sum;
    reg [BEAD_WIDTH-1:0] target;
    reg [BEAD_WIDTH-1:0] current_sum;
    reg [3:0] i;
    reg [3:0] j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 4'd0;
            start_pos <= 4'd0;
            seg_count <= 4'd0;
            bead_idx <= 4'd0;
            total_sum <= 16'd0;
            target <= 16'd0;
            current_sum <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALC_SUM;
                        cycle_count <= 4'd0;
                        total_sum <= 16'd0;
                        i <= 4'd0;
                    end
                end

                CALC_SUM: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (i < n_i) begin
                        total_sum <= total_sum + bead_weights[i];
                        i <= i + 4'd1;
                    end else begin
                        state <= CHECK_DIV;
                    end
                end

                CHECK_DIV: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (total_sum % k_i == 0) begin
                        target <= total_sum / k_i;
                        state <= TRY_START;
                        start_pos <= 4'd0;
                        result <= 1'b0;
                    end else begin
                        result <= 1'b0;
                        state <= DONE;
                    end
                end

                TRY_START: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (start_pos < n_i) begin
                        state <= CHECK_SEG;
                        seg_count <= 4'd0;
                        bead_idx <= start_pos;
                        current_sum <= 16'd0;
                    end else begin
                        state <= DONE;
                    end
                end

                CHECK_SEG: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (seg_count < k_i) begin
                        if (current_sum + bead_weights[bead_idx] <= target) begin
                            current_sum <= current_sum + bead_weights[bead_idx];
                            bead_idx <= (bead_idx + 4'd1) % n_i;
                            if (current_sum == target) begin
                                seg_count <= seg_count + 4'd1;
                                current_sum <= 16'd0;
                            end
                        end else begin
                            start_pos <= start_pos + 4'd1;
                            state <= TRY_START;
                        end
                    end else begin
                        result <= 1'b1;
                        state <= DONE;
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