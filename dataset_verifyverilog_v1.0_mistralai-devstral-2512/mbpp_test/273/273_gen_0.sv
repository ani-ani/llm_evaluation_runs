module array_subtractor(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr_a [0:7],
    input signed [7:0] arr_b [0:7],
    output reg signed [7:0] arr_res [0:7],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [3:0] counter;
    localparam [3:0] MAX_CYCLES = 4'd16;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            counter <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                arr_res[i] <= 8'd0;
            end
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
                    counter <= counter + 4'd1;
                    
                    // Compute two elements per cycle
                    if (counter[0] == 1'b0) begin
                        arr_res[0] <= arr_a[0] - arr_b[0];
                        arr_res[1] <= arr_a[1] - arr_b[1];
                    end else if (counter[0] == 1'b1) begin
                        arr_res[2] <= arr_a[2] - arr_b[2];
                        arr_res[3] <= arr_a[3] - arr_b[3];
                    end
                    
                    // Exit conditions
                    if (counter >= 4'd8 || counter >= MAX_CYCLES) begin
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