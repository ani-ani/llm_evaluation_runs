module longest_subsegment (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input [3:0] len,
    output reg [7:0] result,
    output reg done
);
    // State declarations
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] CAPTURE      = 4'd1;
    localparam [3:0] COMPUTE_LEFT = 4'd2;
    localparam [3:0] COMPUTE_RIGHT = 4'd3;
    localparam [3:0] COMPUTE_ANSWER = 4'd4;
    localparam [3:0] DONE_STATE   = 4'd5;
    
    // Internal registers
    reg [7:0] arr_reg [0:7];
    reg [3:0] left [0:7];
    reg [3:0] right [0:7];
    reg [7:0] ans;
    reg [3:0] state;
    reg [3:0] i;
    reg [3:0] len_reg;
    reg [2:0] phase;  // 0=capture, 1=left, 2=right, 3=answer
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            ans <= 8'd0;
            i <= 4'd0;
            len_reg <= 4'd0;
            phase <= 3'd0;
            // Initialize arrays to avoid X
            arr_reg[0] <= 8'd0; arr_reg[1] <= 8'd0; arr_reg[2] <= 8'd0; arr_reg[3] <= 8'd0;
            arr_reg[4] <= 8'd0; arr_reg[5] <= 8'd0; arr_reg[6] <= 8'd0; arr_reg[7] <= 8'd0;
            left[0] <= 4'd0; left[1] <= 4'd0; left[2] <= 4'd0; left[3] <= 4'd0;
            left[4] <= 4'd0; left[5] <= 4'd0; left[6] <= 4'd0; left[7] <= 4'd0;
            right[0] <= 4'd0; right[1] <= 4'd0; right[2] <= 4'd0; right[3] <= 4'd0;
            right[4] <= 4'd0; right[5] <= 4'd0; right[6] <= 4'd0; right[7] <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CAPTURE;
                        i <= 4'd0;
                        ans <= 8'd0;
                        len_reg <= (len > 4'd8) ? 4'd8 : len;
                        phase <= 3'd0;
                    end
                end
                
                CAPTURE: begin
                    // Capture input array (one per cycle)
                    if (i < len_reg) begin
                        case (i)
                            4'd0: arr_reg[0] <= arr_0;
                            4'd1: arr_reg[1] <= arr_1;
                            4'd2: arr_reg[2] <= arr_2;
                            4'd3: arr_reg[3] <= arr_3;
                            4'd4: arr_reg[4] <= arr_4;
                            4'd5: arr_reg[5] <= arr_5;
                            4'd6: arr_reg[6] <= arr_6;
                            4'd7: arr_reg[7] <= arr_7;
                        endcase
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        if (len_reg > 4'd0) begin
                            state <= COMPUTE_LEFT;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end
                end
                
                COMPUTE_LEFT: begin
                    if (i < len_reg) begin
                        if (i == 4'd0) begin
                            left[0] <= 4'd1;
                            if (4'd1 > ans) ans <= 8'd1;
                        end else begin
                            if (arr_reg[i] > arr_reg[i-4'd1]) begin
                                left[i] <= left[i-4'd1] + 4'd1;
                                if (left[i-4'd1] + 4'd1 > ans) ans <= left[i-4'd1] + 4'd1;
                            end else begin
                                left[i] <= 4'd1;
                                if (4'd1 > ans) ans <= 8'd1;
                            end
                        end
                        i <= i + 4'd1;
                    end else begin
                        i <= len_reg - 4'd1;
                        state <= COMPUTE_RIGHT;
                    end
                end
                
                COMPUTE_RIGHT: begin
                    if (i < len_reg) begin  // i decrements, check if >= 0
                        if (i == len_reg - 4'd1) begin
                            right[i] <= 4'd1;
                        end else begin
                            if (arr_reg[i] < arr_reg[i+4'd1]) begin
                                right[i] <= right[i+4'd1] + 4'd1;
                            end else begin
                                right[i] <= 4'd1;
                            end
                        end
                        if (i == 4'd0) begin
                            i <= len_reg;  // Signal done
                        end else begin
                            i <= i - 4'd1;
                        end
                    end else begin
                        i <= 4'd0;
                        state <= COMPUTE_ANSWER;
                    end
                end
                
                COMPUTE_ANSWER: begin
                    if (i < len_reg) begin
                        // Check left extension (change element after left segment)
                        if (i > 4'd0) begin
                            if (left[i-4'd1] + 4'd1 > ans) ans <= left[i-4'd1] + 4'd1;
                        end
                        // Check right extension (change element before right segment)
                        if (i < len_reg - 4'd1) begin
                            if (right[i+4'd1] + 4'd1 > ans) ans <= right[i+4'd1] + 4'd1;
                        end
                        // Check merge
                        if (i > 4'd0 && i < len_reg - 4'd1) begin
                            // Check if there exists a value between arr[i-1] and arr[i+1]
                            if (arr_reg[i-4'd1] + 4'd1 < arr_reg[i+4'd1]) begin
                                if (left[i-4'd1] + 4'd1 + right[i+4'd1] > ans) begin
                                    ans <= left[i-4'd1] + 4'd1 + right[i+4'd1];
                                end
                            end
                        end
                        i <= i + 4'd1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    result <= ans;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule