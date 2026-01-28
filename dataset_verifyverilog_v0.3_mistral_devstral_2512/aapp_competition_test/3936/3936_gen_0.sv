module domino_coloring (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] segment_types,
    input wire [3:0] num_segments,
    output reg [31:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE = 2'd2;
    localparam [31:0] MOD = 32'd1000000007;

    reg [1:0] state;
    reg [7:0] types_reg;
    reg [3:0] num_segs_reg;
    reg [3:0] idx;
    reg prev_type;
    reg first_seg;
    reg [31:0] temp_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            types_reg <= 8'd0;
            num_segs_reg <= 4'd0;
            idx <= 4'd0;
            prev_type <= 1'b0;
            first_seg <= 1'b1;
            temp_result <= 32'd1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        types_reg <= segment_types;
                        num_segs_reg <= num_segments;
                        idx <= 4'd0;
                        first_seg <= 1'b1;
                        temp_result <= 32'd1;
                    end
                end

                COMPUTE: begin
                    if (idx < num_segs_reg) begin
                        if (first_seg) begin
                            if (types_reg[idx] == 1'b0) begin
                                temp_result <= (temp_result * 32'd3) % MOD;
                            end else begin
                                temp_result <= (temp_result * 32'd6) % MOD;
                            end
                            first_seg <= 1'b0;
                        end else begin
                            case ({prev_type, types_reg[idx]})
                                2'b00: temp_result <= (temp_result * 32'd2) % MOD;
                                2'b01: temp_result <= (temp_result * 32'd2) % MOD;
                                2'b10: temp_result <= temp_result;
                                2'b11: temp_result <= (temp_result * 32'd3) % MOD;
                            endcase
                        end
                        prev_type <= types_reg[idx];
                        idx <= idx + 1'b1;
                    end else begin
                        result <= temp_result;
                        state <= DONE;
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule