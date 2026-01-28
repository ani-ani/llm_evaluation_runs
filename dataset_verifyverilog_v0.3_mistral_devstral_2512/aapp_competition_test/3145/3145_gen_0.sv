module multiple_counter (
    input clk,
    input rst_n,
    input start,
    input [15:0] X,
    input [15:0] A,
    input [15:0] B,
    input [9:0] allowed_mask,
    output reg [15:0] count,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] CHECK_DIGITS = 3'd2;
    localparam [2:0] EXTRACT_DIGIT = 3'd3;
    localparam [2:0] COUNT = 3'd4;
    localparam [2:0] INCREMENT = 3'd5;
    localparam [2:0] DONE = 3'd6;

    reg [2:0] state;
    reg [15:0] current;
    reg [15:0] rem;
    reg [15:0] temp_count;
    reg [15:0] temp_num;
    reg valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current <= 16'd0;
            rem <= 16'd0;
            temp_count <= 16'd0;
            temp_num <= 16'd0;
            valid <= 1'b0;
            done <= 1'b0;
            count <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current <= A;
                        rem <= A % X;
                        temp_count <= 16'd0;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    if (current > B) begin
                        count <= temp_count;
                        state <= DONE;
                    end else if (rem == 16'd0) begin
                        state <= CHECK_DIGITS;
                    end else begin
                        state <= INCREMENT;
                    end
                end
                
                CHECK_DIGITS: begin
                    valid <= 1'b1;
                    if (current == 16'd0) begin
                        if (allowed_mask[10'd0]) begin
                            state <= COUNT;
                        end else begin
                            state <= INCREMENT;
                        end
                    end else begin
                        temp_num <= current;
                        state <= EXTRACT_DIGIT;
                    end
                end
                
                EXTRACT_DIGIT: begin
                    if (allowed_mask[temp_num % 10] == 1'b0) begin
                        valid <= 1'b0;
                        state <= INCREMENT;
                    end else begin
                        temp_num <= temp_num / 10;
                        if (temp_num == 16'd0) begin
                            if (valid) begin
                                state <= COUNT;
                            end else begin
                                state <= INCREMENT;
                            end
                        end else begin
                            state <= EXTRACT_DIGIT;
                        end
                    end
                end
                
                COUNT: begin
                    temp_count <= temp_count + 16'd1;
                    state <= INCREMENT;
                end
                
                INCREMENT: begin
                    current <= current + 16'd1;
                    rem <= (rem + 16'd1 < X) ? rem + 16'd1 : 16'd0;
                    state <= CHECK;
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