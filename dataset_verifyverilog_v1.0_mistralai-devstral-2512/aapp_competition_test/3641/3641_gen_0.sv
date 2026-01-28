module necklace_split(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [7:0] beads [0:15],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_SUM = 3'd1;
    localparam [2:0] CHECK_DIVISIBILITY = 3'd2;
    localparam [2:0] BUILD_PREFIX = 3'd3;
    localparam [2:0] CHECK_SEGMENTS = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state;
    reg [11:0] total_sum;
    reg [11:0] target;
    reg [11:0] prefix [0:15];
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] segment_count;
    reg [11:0] current_segment;
    reg segment_found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            total_sum <= 12'd0;
            target <= 12'd0;
            i <= 4'd0;
            j <= 4'd0;
            segment_count <= 4'd0;
            current_segment <= 12'd0;
            segment_found <= 1'b0;
            cycle_count <= 8'd0;
            for (j = 0; j < 16; j = j + 1) begin
                prefix[j] <= 12'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_SUM;
                    end
                end

                COMPUTE_SUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < n) begin
                        total_sum <= total_sum + beads[i];
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        state <= CHECK_DIVISIBILITY;
                    end
                end

                CHECK_DIVISIBILITY: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (total_sum % k == 12'd0) begin
                        target <= total_sum / k;
                        state <= BUILD_PREFIX;
                    end else begin
                        result <= 1'b0;
                        state <= FINISH;
                    end
                end

                BUILD_PREFIX: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < n) begin
                        if (i == 4'd0) begin
                            prefix[i] <= beads[i];
                        end else begin
                            prefix[i] <= prefix[i - 4'd1] + beads[i];
                        end
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        segment_count <= 4'd0;
                        state <= CHECK_SEGMENTS;
                    end
                end

                CHECK_SEGMENTS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (segment_count < k - 4'd1) begin
                        current_segment <= target * (segment_count + 4'd1);
                        segment_found <= 1'b0;
                        for (j = 0; j < n; j = j + 1) begin
                            if (prefix[j] == current_segment) begin
                                segment_found <= 1'b1;
                            end
                        end
                        if (segment_found) begin
                            segment_count <= segment_count + 4'd1;
                        end else begin
                            result <= 1'b0;
                            state <= FINISH;
                        end
                    end else begin
                        result <= 1'b1;
                        state <= FINISH;
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