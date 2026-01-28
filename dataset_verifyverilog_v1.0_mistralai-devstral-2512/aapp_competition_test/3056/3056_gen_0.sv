module TreeWalkSum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] pattern_data,
    input wire [3:0] pattern_len,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [3:0] index;
    reg [63:0] sum;
    reg [63:0] count;
    reg [63:0] current_val;
    reg [7:0] current_char;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            sum <= 64'd0;
            count <= 64'd0;
            current_val <= 64'd0;
            current_char <= 8'd0;
            result <= 64'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        index <= 4'd0;
                        sum <= 64'd0;
                        count <= 64'd0;
                        current_val <= 64'd0;
                    end
                end

                LOAD: begin
                    if (index < pattern_len) begin
                        current_char <= pattern_data[(index * 8) +: 8];
                        state <= PROCESS;
                    end else begin
                        state <= FINISH;
                    end
                end

                PROCESS: begin
                    case (current_char)
                        8'd76: begin // 'L'
                            current_val <= current_val * 64'd2;
                        end
                        8'd82: begin // 'R'
                            current_val <= (current_val * 64'd2) + 64'd1;
                        end
                        8'd80: begin // 'P'
                            current_val <= current_val;
                        end
                        8'd42: begin // '*'
                            sum <= (sum * 64'd2) + count;
                            count <= count * 64'd3;
                        end
                        default: begin
                            current_val <= current_val;
                        end
                    endcase

                    index <= index + 4'd1;
                    state <= LOAD;
                end

                FINISH: begin
                    result <= sum;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule