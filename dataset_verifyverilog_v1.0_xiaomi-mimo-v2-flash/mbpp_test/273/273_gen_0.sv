module ElementWiseSubtractor (
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr_a [0:7],
    input signed [7:0] arr_b [0:7],
    output reg signed [7:0] arr_res [0:7],
    output reg done
);

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [3:0] counter;  // 4-bit counter for 0-15 cycles
    reg [3:0] i;  // Index for array access

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            done <= 1'b0;
            // Initialize all array elements
            arr_res[0] <= 8'sd0;
            arr_res[1] <= 8'sd0;
            arr_res[2] <= 8'sd0;
            arr_res[3] <= 8'sd0;
            arr_res[4] <= 8'sd0;
            arr_res[5] <= 8'sd0;
            arr_res[6] <= 8'sd0;
            arr_res[7] <= 8'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Process one element per cycle (8 cycles total)
                    case (counter)
                        4'd0: begin
                            arr_res[0] <= $signed(arr_a[0]) - $signed(arr_b[0]);
                            counter <= counter + 4'd1;
                        end
                        4'd1: begin
                            arr_res[1] <= $signed(arr_a[1]) - $signed(arr_b[1]);
                            counter <= counter + 4'd1;
                        end
                        4'd2: begin
                            arr_res[2] <= $signed(arr_a[2]) - $signed(arr_b[2]);
                            counter <= counter + 4'd1;
                        end
                        4'd3: begin
                            arr_res[3] <= $signed(arr_a[3]) - $signed(arr_b[3]);
                            counter <= counter + 4'd1;
                        end
                        4'd4: begin
                            arr_res[4] <= $signed(arr_a[4]) - $signed(arr_b[4]);
                            counter <= counter + 4'd1;
                        end
                        4'd5: begin
                            arr_res[5] <= $signed(arr_a[5]) - $signed(arr_b[5]);
                            counter <= counter + 4'd1;
                        end
                        4'd6: begin
                            arr_res[6] <= $signed(arr_a[6]) - $signed(arr_b[6]);
                            counter <= counter + 4'd1;
                        end
                        4'd7: begin
                            arr_res[7] <= $signed(arr_a[7]) - $signed(arr_b[7]);
                            counter <= counter + 4'd1;
                        end
                        default: begin
                            counter <= counter + 4'd1;
                        end
                    endcase
                    
                    // Complete after 8 cycles (one per element)
                    if (counter == 4'd7) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
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