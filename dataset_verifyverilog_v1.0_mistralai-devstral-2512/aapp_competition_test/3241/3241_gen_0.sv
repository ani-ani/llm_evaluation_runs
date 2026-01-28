module ham_distributor(
    input clk,
    input rst_n,
    input start,
    input [31:0] A [0:7],
    input [31:0] B [0:7],
    output reg [31:0] H_out,
    output reg found,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SEARCH  = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [7:0] i;
    reg [31:0] H;
    reg [31:0] Total [0:7];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // Compute Total[k] = A[k] + (B[k] * H)
    always @(*) begin
        integer k;
        for (k = 0; k < 8; k = k + 1) begin
            wire signed [63:0] mult_temp = $signed(B[k]) * $signed(H);
            Total[k] = mult_temp[47:16] + A[k];
        end
    end

    // Check if Total[0] > Total[1] > ... > Total[7]
    wire is_decreasing;
    assign is_decreasing = (Total[0] > Total[1]) &&
                          (Total[1] > Total[2]) &&
                          (Total[2] > Total[3]) &&
                          (Total[3] > Total[4]) &&
                          (Total[4] > Total[5]) &&
                          (Total[5] > Total[6]) &&
                          (Total[6] > Total[7]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 8'd0;
            H <= 32'd0;
            H_out <= 32'd0;
            found <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SEARCH;
                        i <= 8'd0;
                    end
                end

                SEARCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    H <= {16'd0, i};
                    if (is_decreasing) begin
                        H_out <= H;
                        found <= 1'b1;
                        state <= FINISH;
                    end else if (i == 8'd255 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        i <= i + 8'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule