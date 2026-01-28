module rotate_array (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] n,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] ROTATE  = 2'd2;
    localparam [1:0] FINISH  = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] counter;
    reg [3:0] n_reg;
    reg [7:0] temp_reg [0:7];
    integer i;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            LOAD: next_state = ROTATE;
            ROTATE: next_state = (counter >= n_reg) ? FINISH : ROTATE;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            n_reg <= 4'd0;
            done <= 1'b0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                temp_reg[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    n_reg <= (n < 4'd8) ? n : 4'd8;
                end

                LOAD: begin
                    // Store first n elements in temp buffer
                    // Also copy full array to temp buffer for rotation
                    temp_reg[0] <= arr_0;
                    temp_reg[1] <= arr_1;
                    temp_reg[2] <= arr_2;
                    temp_reg[3] <= arr_3;
                    temp_reg[4] <= arr_4;
                    temp_reg[5] <= arr_5;
                    temp_reg[6] <= arr_6;
                    temp_reg[7] <= arr_7;
                    counter <= 4'd0;
                end

                ROTATE: begin
                    // Copy elements from arr[n:] to result[0:7-n]
                    // and arr[:n] to result[7-n:7]
                    if (counter < n_reg) begin
                        // This case handles when we need to copy from temp buffer
                        // For now, we'll do the rotation directly
                        case (counter)
                            4'd0: begin
                                result_0 <= (n_reg <= 4'd7) ? temp_reg[n_reg] : temp_reg[0];
                                result_1 <= (n_reg <= 4'd6) ? temp_reg[n_reg + 4'd1] : temp_reg[1];
                                result_2 <= (n_reg <= 4'd5) ? temp_reg[n_reg + 4'd2] : temp_reg[2];
                                result_3 <= (n_reg <= 4'd4) ? temp_reg[n_reg + 4'd3] : temp_reg[3];
                            end
                            4'd1: begin
                                result_4 <= (n_reg <= 4'd3) ? temp_reg[n_reg + 4'd4] : temp_reg[4];
                                result_5 <= (n_reg <= 4'd2) ? temp_reg[n_reg + 4'd5] : temp_reg[5];
                                result_6 <= (n_reg <= 4'd1) ? temp_reg[n_reg + 4'd6] : temp_reg[6];
                                result_7 <= (n_reg == 4'd0) ? temp_reg[7] : temp_reg[n_reg - 4'd1];
                            end
                        endcase
                    end else begin
                        // Fill remaining positions with saved temp elements
                        case (counter)
                            4'd2: begin
                                result_0 <= temp_reg[0];
                                result_1 <= temp_reg[1];
                                result_2 <= temp_reg[2];
                                result_3 <= temp_reg[3];
                            end
                            4'd3: begin
                                result_4 <= temp_reg[4];
                                result_5 <= temp_reg[5];
                                result_6 <= temp_reg[6];
                                result_7 <= temp_reg[7];
                            end
                        endcase
                    end
                    counter <= counter + 4'd1;
                end

                FINISH: begin
                    done <= 1'b1;
                    counter <= 4'd0;
                end
            endcase
        end
    end

endmodule