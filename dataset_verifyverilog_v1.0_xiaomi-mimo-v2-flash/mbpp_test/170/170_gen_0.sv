module ArraySumModule (
    input clk,
    input rst_n,
    input start,
    input [3:0] m,
    input [3:0] n,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg [15:0] result,
    output reg done
);

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SUMMING = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] current_idx;
    reg [15:0] accumulator;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Helper array for indexed access
    wire [7:0] arr [0:7];
    assign arr[0] = arr_0;
    assign arr[1] = arr_1;
    assign arr[2] = arr_2;
    assign arr[3] = arr_3;
    assign arr[4] = arr_4;
    assign arr[5] = arr_5;
    assign arr[6] = arr_6;
    assign arr[7] = arr_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_idx <= 4'd0;
            accumulator <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    accumulator <= 16'd0;
                    if (start) begin
                        current_idx <= m;
                        state <= SUMMING;
                    end
                end

                SUMMING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Add current element to accumulator
                    accumulator <= accumulator + {8'd0, arr[current_idx]};
                    
                    // Increment index
                    current_idx <= current_idx + 4'd1;
                    
                    // Check if we've passed the end index
                    // When current_idx > n, we're done summing
                    if ((current_idx >= n) || (cycle_count >= MAX_CYCLES)) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule