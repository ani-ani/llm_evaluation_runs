module longest_subsegment (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input [3:0] len,
    output reg [7:0] result,
    output reg done
);
    
    // Parameters
    parameter N = 8;
    parameter IDLE = 4'd0;
    parameter CAPTURE = 4'd1;
    parameter COMPUTE_LEFT = 4'd2;
    parameter COMPUTE_RIGHT = 4'd3;
    parameter COMPUTE_ANSWER = 4'd4;
    parameter DONE = 4'd5;
    
    // Internal registers
    reg [7:0] arr_reg [0:N-1];
    reg [3:0] left [0:N-1];
    reg [3:0] right [0:N-1];
    reg [7:0] ans;
    reg [3:0] state;
    reg [3:0] i;
    reg [3:0] len_reg;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            ans <= 0;
            i <= 0;
            len_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= CAPTURE;
                        i <= 0;
                        ans <= 0;
                        len_reg <= (len > N) ? N : len; // Clamp to N
                    end
                end
                
                CAPTURE: begin
                    // Capture input array
                    if (i < len_reg) begin
                        case (i)
                            0: arr_reg[0] <= arr_0;
                            1: arr_reg[1] <= arr_1;
                            2: arr_reg[2] <= arr_2;
                            3: arr_reg[3] <= arr_3;
                            4: arr_reg[4] <= arr_4;
                            5: arr_reg[5] <= arr_5;
                            6: arr_reg[6] <= arr_6;
                            7: arr_reg[7] <= arr_7;
                        endcase
                        i <= i + 1;
                    end else begin
                        i <= 0;
                        if (len_reg > 0) begin
                            state <= COMPUTE_LEFT;
                        end else begin
                            state <= DONE;
                        end
                    end
                end
                
                COMPUTE_LEFT: begin
                    if (i < len_reg) begin
                        if (i == 0) begin
                            left[0] <= 1;
                            if (1 > ans) ans <= 1;
                        end else begin
                            if (arr_reg[i] > arr_reg[i-1]) begin
                                left[i] <= left[i-1] + 1;
                                if (left[i-1] + 1 > ans) ans <= left[i-1] + 1;
                            end else begin
                                left[i] <= 1;
                                if (1 > ans) ans <= 1;
                            end
                        end
                        i <= i + 1;
                    end else begin
                        i <= len_reg - 1;
                        state <= COMPUTE_RIGHT;
                    end
                end
                
                COMPUTE_RIGHT: begin
                    if (i >= 0 && i < len_reg) begin
                        if (i == len_reg - 1) begin
                            right[i] <= 1;
                        end else begin
                            if (arr_reg[i] < arr_reg[i+1]) begin
                                right[i] <= right[i+1] + 1;
                            end else begin
                                right[i] <= 1;
                            end
                        end
                        if (i == 0) begin
                            i <= len_reg; // Done
                        end else begin
                            i <= i - 1;
                        end
                    end else begin
                        i <= 0;
                        state <= COMPUTE_ANSWER;
                    end
                end
                
                COMPUTE_ANSWER: begin
                    if (i < len_reg) begin
                        // Check left extension (change element after left segment)
                        if (i > 0) begin
                            if (left[i-1] + 1 > ans) ans <= left[i-1] + 1;
                        end
                        // Check right extension (change element before right segment)
                        if (i < len_reg - 1) begin
                            if (right[i+1] + 1 > ans) ans <= right[i+1] + 1;
                        end
                        // Check merge
                        if (i > 0 && i < len_reg - 1) begin
                            // Check if there exists a value between arr[i-1] and arr[i+1]
                            if (arr_reg[i-1] + 1 < arr_reg[i+1]) begin
                                if (left[i-1] + 1 + right[i+1] > ans) ans <= left[i-1] + 1 + right[i+1];
                            end
                        end
                        i <= i + 1;
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    result <= ans;
                    done <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule