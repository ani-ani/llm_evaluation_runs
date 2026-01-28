module bug_fix_optimizer(
    input wire clk,
    input wire rst_n,
    input wire [3:0] B,
    input wire [7:0] T,
    input wire [15:0] p_in,
    input wire [15:0] s_in,
    input wire [15:0] f_in,
    input wire load_en,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg [7:0] bug_count;
    reg [7:0] time_count;
    reg [15:0] p_reg [0:9];
    reg [15:0] s_reg [0:9];
    reg [15:0] f_reg;
    reg [31:0] total_expected;
    reg [3:0] max_idx;
    reg [31:0] max_score;
    reg [31:0] current_score;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bug_count <= 8'd0;
            time_count <= 8'd0;
            total_expected <= 32'd0;
            done <= 1'b0;
            for (i = 0; i < 10; i = i + 1) begin
                p_reg[i] <= 16'd0;
                s_reg[i] <= 16'd0;
            end
            f_reg <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (load_en) begin
                        state <= LOAD;
                        bug_count <= 8'd0;
                    end
                end

                LOAD: begin
                    if (load_en && bug_count < B) begin
                        p_reg[bug_count] <= p_in;
                        s_reg[bug_count] <= s_in;
                        bug_count <= bug_count + 8'd1;
                    end else if (bug_count == B) begin
                        f_reg <= f_in;
                        state <= COMPUTE;
                        time_count <= T;
                    end
                end

                COMPUTE: begin
                    if (time_count > 0) begin
                        max_score <= 32'd0;
                        max_idx <= 4'd0;
                        for (i = 0; i < B; i = i + 1) begin
                            current_score <= $signed(p_reg[i]) * $signed(s_reg[i]);
                            if (current_score > max_score) begin
                                max_score <= current_score;
                                max_idx <= i;
                            end
                        end
                        total_expected <= total_expected + max_score;
                        p_reg[max_idx] <= $signed(p_reg[max_idx]) * $signed(f_reg);
                        time_count <= time_count - 8'd1;
                    end else begin
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