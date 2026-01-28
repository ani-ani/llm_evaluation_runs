module digit_frequency_validator(
    input clk,
    input rst_n,
    input start,
    input [15:0] num_in,
    output reg result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] EXTRACT   = 3'd1;
    localparam [2:0] VALIDATE  = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    
    reg [2:0] state;
    reg [3:0] cycle_count;
    reg [3:0] digit_index;
    reg [3:0] freq [0:9];
    reg [15:0] current_num;
    reg [3:0] current_digit;
    reg [3:0] i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            digit_index <= 4'd0;
            current_num <= 16'd0;
            current_digit <= 4'd0;
            for (i = 0; i < 10; i = i + 1) begin
                freq[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= EXTRACT;
                        current_num <= num_in;
                        cycle_count <= 4'd0;
                        digit_index <= 4'd0;
                        for (i = 0; i < 10; i = i + 1) begin
                            freq[i] <= 4'd0;
                        end
                    end
                end
                
                EXTRACT: begin
                    if (cycle_count < 4'd16) begin
                        current_digit <= current_num[3:0];
                        if (current_digit <= 4'd9) begin
                            freq[current_digit] <= freq[current_digit] + 4'd1;
                        end
                        current_num <= current_num >> 4;
                        cycle_count <= cycle_count + 4'd1;
                    end else begin
                        state <= VALIDATE;
                        digit_index <= 4'd0;
                    end
                end
                
                VALIDATE: begin
                    if (digit_index < 4'd10) begin
                        if (freq[digit_index] > digit_index) begin
                            result <= 1'b0;
                        end
                        digit_index <= digit_index + 4'd1;
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