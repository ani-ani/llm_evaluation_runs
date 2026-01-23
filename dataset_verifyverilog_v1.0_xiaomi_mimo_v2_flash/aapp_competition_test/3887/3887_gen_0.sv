module rebus_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_positive,
    input wire [3:0] num_negative,
    input wire [19:0] n,
    output reg done,
    output reg possible,
    output reg [19:0] positive_terms [0:7],
    output reg [19:0] negative_terms [0:7]
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PRECOMPUTE = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] ASSIGN_POSITIVE = 3'd3;
    localparam [2:0] ASSIGN_NEGATIVE = 3'd4;
    localparam [2:0] DONE = 3'd5;

    reg [2:0] state;
    reg signed [31:0] adjustment;
    reg [31:0] rem;
    reg [3:0] index;
    reg [31:0] limit_positive;
    reg [31:0] limit_negative;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            possible <= 1'b0;
            adjustment <= 32'sd0;
            rem <= 32'd0;
            index <= 4'd0;
            limit_positive <= 32'd0;
            limit_negative <= 32'd0;
            for (i = 0; i < 8; i = i + 1) begin
                positive_terms[i] <= 20'd1;
                negative_terms[i] <= 20'd1;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PRECOMPUTE;
                    end
                end

                PRECOMPUTE: begin
                    adjustment <= $signed(n) - $signed(num_positive) + $signed(num_negative);
                    limit_positive <= num_positive * (n - 20'd1);
                    limit_negative <= num_negative * (n - 20'd1);
                    state <= CHECK;
                end

                CHECK: begin
                    if (adjustment >= 32'sd0) begin
                        if (adjustment <= $signed(limit_positive)) begin
                            possible <= 1'b1;
                            rem <= adjustment;
                            index <= 4'd0;
                            state <= ASSIGN_POSITIVE;
                        end else begin
                            possible <= 1'b0;
                            state <= DONE;
                        end
                    end else begin
                        if (-adjustment <= $signed(limit_negative)) begin
                            possible <= 1'b1;
                            rem <= -adjustment;
                            index <= 4'd0;
                            state <= ASSIGN_NEGATIVE;
                        end else begin
                            possible <= 1'b0;
                            state <= DONE;
                        end
                    end
                end

                ASSIGN_POSITIVE: begin
                    if (index < num_positive) begin
                        if (rem > (n - 20'd1)) begin
                            positive_terms[index] <= 20'd1 + (n - 20'd1);
                            rem <= rem - (n - 20'd1);
                        end else begin
                            positive_terms[index] <= 20'd1 + rem;
                            rem <= 32'd0;
                        end
                        index <= index + 4'd1;
                    end else begin
                        state <= DONE;
                    end
                end

                ASSIGN_NEGATIVE: begin
                    if (index < num_negative) begin
                        if (rem > (n - 20'd1)) begin
                            negative_terms[index] <= 20'd1 + (n - 20'd1);
                            rem <= rem - (n - 20'd1);
                        end else begin
                            negative_terms[index] <= 20'd1 + rem;
                            rem <= 32'd0;
                        end
                        index <= index + 4'd1;
                    end else begin
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