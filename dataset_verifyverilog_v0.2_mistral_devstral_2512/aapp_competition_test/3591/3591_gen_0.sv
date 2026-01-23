module photo_finder (
    input clk,
    input rst_n,
    input start,
    input [2:0] photo_index,
    input [2:0] num_people,
    input [15:0] heights [0:7],
    output reg [2:0] valid_photo_index,
    output reg valid,
    output reg done
);

    // State definitions
    localparam IDLE = 2'd0;
    localparam PROCESS = 2'd1;
    localparam FINISH = 2'd2;

    reg [1:0] state;
    reg [2:0] me_pos;
    reg [2:0] alice;
    reg [2:0] bob;
    reg temp_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 0;
            done <= 0;
            me_pos <= 0;
            alice <= 0;
            bob <= 0;
            temp_valid <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESS;
                        me_pos <= 0;
                        alice <= 0;
                        bob <= 0;
                        temp_valid <= 0;
                        done <= 0;
                    end
                end

                PROCESS: begin
                    if (temp_valid) begin
                        state <= FINISH;
                    end else if (me_pos < num_people) begin
                        // Check current alice and bob
                        if (alice < me_pos && bob > me_pos && bob < num_people) begin
                            if (heights[alice] > heights[me_pos] && heights[bob] > heights[alice]) begin
                                temp_valid <= 1;
                            end
                        end

                        // Increment counters
                        if (bob < num_people - 1) begin
                            bob <= bob + 1;
                        end else if (alice < me_pos - 1) begin
                            alice <= alice + 1;
                            bob <= me_pos + 1;
                        end else if (alice == me_pos - 1) begin
                            if (me_pos < num_people - 1) begin
                                me_pos <= me_pos + 1;
                                alice <= 0;
                                bob <= me_pos + 1;
                            end else begin
                                state <= FINISH;
                            end
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    if (temp_valid) begin
                        valid <= 1;
                        valid_photo_index <= photo_index;
                    end else begin
                        valid <= 0;
                    end
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

module top (
    input clk,
    input rst_n,
    input start,
    input [2:0] k,
    input [2:0] n [0:7],
    input [15:0] heights [0:7][0:7],
    output reg [2:0] num_valid,
    output reg [2:0] valid_indices [0:7],
    output reg done
);

    reg [2:0] photo_cnt;
    reg pf_start;
    wire pf_done;
    wire pf_valid;
    wire [2:0] pf_idx;

    reg [2:0] temp_indices [0:7];
    reg [2:0] temp_valid_cnt;

    photo_finder pf (
        .clk(clk),
        .rst_n(rst_n),
        .start(pf_start),
        .photo_index(photo_cnt),
        .num_people(n[photo_cnt]),
        .heights(heights[photo_cnt]),
        .valid_photo_index(pf_idx),
        .valid(pf_valid),
        .done(pf_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            photo_cnt <= 0;
            pf_start <= 0;
            temp_valid_cnt <= 0;
            num_valid <= 0;
            done <= 0;
        end else begin
            if (start && !done) begin
                photo_cnt <= 0;
                pf_start <= 1;
                temp_valid_cnt <= 0;
                done <= 0;
            end else if (photo_cnt < k) begin
                if (pf_start) begin
                    pf_start <= 0;
                end else if (pf_done) begin
                    if (pf_valid) begin
                        temp_indices[temp_valid_cnt] <= pf_idx;
                        temp_valid_cnt <= temp_valid_cnt + 1;
                    end
                    photo_cnt <= photo_cnt + 1;
                    if (photo_cnt < k) begin
                        pf_start <= 1;
                    end
                end
            end else if (photo_cnt == k && !done) begin
                num_valid <= temp_valid_cnt;
                done <= 1;
            end
        end
    end

    // Helper to keep indices array in sync
    integer i_idx;
    always @(posedge clk) begin
        for (i_idx = 0; i_idx < 8; i_idx = i_idx + 1) begin
            valid_indices[i_idx] <= temp_indices[i_idx];
        end
    end

endmodule