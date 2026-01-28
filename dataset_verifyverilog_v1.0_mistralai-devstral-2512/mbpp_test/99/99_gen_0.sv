module unsigned_to_binary(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    output reg [15:0] result,
    output reg [3:0] len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH  = 3'd2;

    reg [2:0] state;
    reg [3:0] bit_pos;
    reg [15:0] temp_n;
    reg started;
    reg [3:0] temp_len;
    reg [15:0] temp_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            len <= 4'd0;
            done <= 1'b0;
            bit_pos <= 4'd0;
            temp_n <= 16'd0;
            started <= 1'b0;
            temp_len <= 4'd0;
            temp_result <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        temp_n <= n;
                        bit_pos <= 4'd15;
                        started <= 1'b0;
                        temp_len <= 4'd0;
                        temp_result <= 16'd0;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (bit_pos >= 4'd0) begin
                        if (temp_n[bit_pos] || started) begin
                            started <= 1'b1;
                            if (temp_n[bit_pos]) begin
                                temp_result[bit_pos] <= 8'h31;  // '1'
                            end else begin
                                temp_result[bit_pos] <= 8'h30;  // '0'
                            end
                            temp_len <= temp_len + 4'd1;
                        end
                        bit_pos <= bit_pos - 4'd1;
                    end else begin
                        state <= FINISH;
                    end

                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= temp_result;
                    len <= temp_len;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule